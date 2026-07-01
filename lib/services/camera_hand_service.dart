import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixel_game/game/systems/input_controller.dart';
import 'package:flutter/scheduler.dart';

/// Ön kamera + MediaPipe Hand Landmark tespiti.
///
/// Mimari:
///   Flutter → camera paketi → ham frame → MethodChannel → Kotlin → MediaPipe → sonuçlar
///
/// Kanaldan gelen mesaj formatı:
///   { "fingerX": 0.42, "isPunch": false }
///   fingerX : [0, 1]  (index parmak ucu X, ön kamera)
///   isPunch : tüm 4 parmak kıvrık mı (yumruk tespiti)
///
/// Landmark indeksleri (MediaPipe 21 nokta):
///   8  = INDEX_FINGER_TIP   (hareketler için X)
///   12 = MIDDLE_FINGER_TIP  ─┐
///   16 = RING_FINGER_TIP     ├ yumruk kontrolü
///   20 = PINKY_TIP          ─┘
class CameraHandService {
  static const _channel = MethodChannel('finger_jump/hand_tracking');

  final InputController _controller;

  CameraController? _cam;
  StreamSubscription<dynamic>? _eventSub;

  // Servis durduruldu mu? Frame göndermeyi durdur.
  bool _isStopped = false;

  // Frame throttle: son gönderilen frame zamanı.
  // ~15 FPS → 66ms aralık yeterli, MediaPipe'ı bunaltmaz.
  int _lastFrameMs = 0;
  static const int _frameIntervalMs = 66; // ~15 FPS

  // Yumruk debounce — aynı vuruşu birden tetiklememek için.
  bool _handWasOpen = true;
  DateTime _lastPunch = DateTime(0);
  static const _punchDebounce = Duration(milliseconds: 800);

  CameraHandService(this._controller);

  /// Önizleme widget'ı için kamera controller'ını döner.
  CameraController? get cameraController => _cam;

  /// Parmak X pozisyonu (normalized 0–1). Overlay için.
  final ValueNotifier<double?> fingerXNotifier = ValueNotifier<double?>(null);

  /// Parmak Y pozisyonu (normalized 0–1). Overlay için.
  final ValueNotifier<double?> fingerYNotifier = ValueNotifier<double?>(null);

  // ─── Yaşam döngüsü ──────────────────────────────────────────────────────────

  Future<bool> start() async {
    _isStopped = false;
    _lastFrameMs = 0;

    // Kamera izni iste.
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint('[CameraHandService] Kamera izni reddedildi.');
      return false;
    }

    // Ön kamerayı bul.
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // Düşük çözünürlük → düşük gecikme.
    _cam = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // JPEG desteklenmeyen cihazlarda YUV420 kullan
    );
    await _cam!.initialize();

    // Native MediaPipe kanalını başlat.
    try {
      await _channel.invokeMethod('startTracking');
    } on PlatformException catch (e) {
      debugPrint('[CameraHandService] MediaPipe başlatılamadı: ${e.message}');
      // Model dosyası eksik veya yanlış — kamera modu devre dışı.
      _cam?.dispose();
      _cam = null;
      return false;
    }

    // Native'den gelen sonuçları dinle.
    const events = EventChannel('finger_jump/hand_events');
    _eventSub = events.receiveBroadcastStream().listen(_onHandEvent);

    // Kamera frame'lerini native'e gönder.
    await _cam!.startImageStream(_sendFrame);

    debugPrint('[CameraHandService] Başlatıldı.');
    return true;
  }

  /// Servisi durdurur. Native tarafı temizler.
  /// Restart öncesi çağrıldığında: önce stream'i dur, sonra native'e bildir,
  /// böylece yeni startTracking geldiğinde eski oturum kapanmış olur.
  Future<void> stop() async {
    _isStopped = true;
    _controller.normalizedX = 0.0;
    fingerXNotifier.value = null;
    fingerYNotifier.value = null;

    // Önce frame akışını kes.
    try { await _cam?.stopImageStream(); } catch (_) {}
    // Event kanalını kapat.
    await _eventSub?.cancel();
    _eventSub = null;
    // Native tracking'i durdur (await ile sıraya girer).
    try { await _channel.invokeMethod('stopTracking'); } catch (_) {}
    // Kamerayı dispose et.
    try { _cam?.dispose(); } catch (_) {}
    _cam = null;
  }

  // ─── Frame gönderme ──────────────────────────────────────────────────────────

  void _sendFrame(CameraImage image) {
    if (_isStopped) return;
    if (image.planes.length < 3) return;

    // Throttle: ~15 FPS — MediaPipe yoğunluğunu azaltır, oyun kasmasını önler.
    final nowMs = SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;
    if (nowMs - _lastFrameMs < _frameIntervalMs) return;
    _lastFrameMs = nowMs;

    // YUV420: planes[0]=Y, planes[1]=U, planes[2]=V
    // Kotlin tarafı NV21 formatına çevirir → YuvImage → Bitmap → MediaPipe
    _channel.invokeMethod('processFrame', {
      'y': image.planes[0].bytes,
      'u': image.planes[1].bytes,
      'v': image.planes[2].bytes,
      'yRowStride': image.planes[0].bytesPerRow,
      'uvRowStride': image.planes[1].bytesPerRow,
      'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
      'width': image.width,
      'height': image.height,
    });
  }

  // ─── Sonuç işleme ────────────────────────────────────────────────────────────

  void _onHandEvent(dynamic data) {
    if (data is! Map) return;
    final found = data['found'] as bool? ?? false;
    final fingerX = found ? (data['fingerX'] as num?)?.toDouble() : null;
    final fingerY = found ? (data['fingerY'] as num?)?.toDouble() : null;
    final isPunch = data['isPunch'] as bool? ?? false;

    fingerXNotifier.value = fingerX;
    fingerYNotifier.value = fingerY;

    if (fingerX != null) {
      // [0,1] → [-1,1] dönüşümü. Ön kamera ayna görüntüsü — X ters çevrilir.
      _controller.normalizedX = (0.5 - fingerX) * 2.0;
    } else {
      // El kaybolduğunda x sıfırla (oyuncu durduğu yerde kalsın).
      _controller.normalizedX = 0.0;
    }

    _detectPunch(isPunch);
  }

  void _detectPunch(bool isFist) {
    final now = DateTime.now();
    if (isFist && _handWasOpen && now.difference(_lastPunch) > _punchDebounce) {
      _lastPunch = now;
      _controller.onPunch?.call();
    }
    _handWasOpen = !isFist;
  }
}
