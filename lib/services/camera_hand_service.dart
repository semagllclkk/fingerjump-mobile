import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

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

  // Yumruk debounce — aynı vuruşu birden tetiklememek için.
  bool _handWasOpen = true;
  DateTime _lastPunch = DateTime(0);
  static const _punchDebounce = Duration(milliseconds: 800);

  CameraHandService(this._controller);

  /// Önizleme widget'ı için kamera controller'ını döner.
  CameraController? get cameraController => _cam;

  // ─── Yaşam döngüsü ──────────────────────────────────────────────────────────

  Future<bool> start() async {
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
      imageFormatGroup: ImageFormatGroup.nv21,
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

  void stop() {
    _cam?.stopImageStream();
    _cam?.dispose();
    _cam = null;
    _eventSub?.cancel();
    _channel.invokeMethod('stopTracking');
    _controller.normalizedX = 0.0;
  }

  // ─── Frame gönderme ──────────────────────────────────────────────────────────

  void _sendFrame(CameraImage image) {
    // Sadece Y düzlemini gönder (gri tonlama yeterli, daha hızlı).
    final plane = image.planes[0];
    _channel.invokeMethod('processFrame', {
      'bytes': plane.bytes,
      'width': image.width,
      'height': image.height,
      'rotation': 270, // ön kamera portre modu
    });
  }

  // ─── Sonuç işleme ────────────────────────────────────────────────────────────

  void _onHandEvent(dynamic data) {
    if (data is! Map) return;
    final fingerX = (data['fingerX'] as num?)?.toDouble();
    final isPunch = data['isPunch'] as bool? ?? false;

    if (fingerX != null) {
      // [0,1] → [-1,1] dönüşümü. Ön kamera ayna görüntüsü — X ters çevrilir.
      _controller.normalizedX = (0.5 - fingerX) * 2.0;
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
