import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// Ön kamera + MediaPipe Hand Landmark tespiti.
///
/// Mimari:
///   camera paketi → YUV420 frame → MethodChannel → Kotlin (arka plan thread)
///   → doğrudan YUV→ARGB (JPEG yok) → MediaPipe VIDEO modu → sonuç (cevap)
///
/// Önceki sürümdeki kasma nedenleri ve çözümleri:
///   1. Her kamera frame'i (~30 fps) kanaldan kopyalanıyordu; native taraf
///      yarısını atsa da kopyalama + kuyruk birikiyordu.
///      → Aynı anda en fazla BİR frame işlemde ([_busy]). Native cevap
///        dönmeden yeni frame gönderilmez; kuyruk asla birikmez.
///   2. Native işlem Android ana (platform) thread'inde çalışıyordu ve
///      YUV→JPEG→Bitmap→döndür zinciri + MediaPipe her frame onu kilitliyordu.
///      → Kotlin tarafı tek thread'lik executor'da, JPEG'siz dönüşümle çalışır.
///   3. MediaPipe IMAGE modunda her frame avuç tespitini baştan yapıyordu.
///      → VIDEO modu: el bir kez bulununca landmark takibi çok daha ucuz.
///   4. Sonuçlar ham ve titrekti, el bir frame kaybolunca oyuncu duruyordu.
///      → EMA yumuşatma + kısa süreli kayıp toleransı + ölü bölge.
class CameraHandService {
  static const _channel = MethodChannel('finger_jump/hand_tracking');

  final InputController _controller;

  CameraController? _cam;
  bool _isStopped = false;

  /// Native taraf hâlâ bir frame işliyor mu? (geri basınç)
  bool _busy = false;

  // ─── Yumuşatma ──────────────────────────────────────────────────────────────

  static const double _emaAlpha = 0.45;
  static const double _deadZone = 0.06;

  /// Parmağın kamera görüntüsünün ortadaki bu oranlık kısmında gezmesi,
  /// tam sol-sağ hıza ulaşmak için yeterli (kenarlara uzanmak zorunda kalma).
  static const double _gain = 1.6;

  /// El bu kadar ardışık sonuçta bulunamazsa giriş sıfırlanır.
  static const int _maxMisses = 4;

  double _smoothX = 0;
  int _misses = 0;

  // Yumruk debounce.
  bool _handWasOpen = true;
  DateTime _lastPunch = DateTime(0);
  static const _punchDebounce = Duration(milliseconds: 650);

  CameraHandService(this._controller);

  CameraController? get cameraController => _cam;

  /// Parmak pozisyonu (normalize 0–1). Overlay için. Tek notifier → tek rebuild.
  final ValueNotifier<Offset?> fingerNotifier = ValueNotifier<Offset?>(null);

  // ─── Yaşam döngüsü ──────────────────────────────────────────────────────────

  Future<bool> start() async {
    _isStopped = false;

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint('[CameraHandService] Kamera izni reddedildi.');
      return false;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return false;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // Düşük çözünürlük → düşük gecikme. MediaPipe zaten ~256px'e küçültür.
    final cam = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _cam = cam;
    await cam.initialize();
    if (_isStopped) {
      await cam.dispose();
      return false;
    }

    try {
      await _channel.invokeMethod('startTracking');
    } on PlatformException catch (e) {
      debugPrint('[CameraHandService] MediaPipe başlatılamadı: ${e.message}');
      await cam.dispose();
      _cam = null;
      return false;
    }

    await cam.startImageStream(_sendFrame);
    debugPrint('[CameraHandService] Başlatıldı.');
    return true;
  }

  Future<void> stop() async {
    if (_isStopped) return;
    _isStopped = true;
    _controller.normalizedX = 0.0;
    fingerNotifier.value = null;

    final cam = _cam;
    _cam = null;
    try {
      if (cam != null && cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}
    try {
      await _channel.invokeMethod('stopTracking');
    } catch (_) {}
    try {
      await cam?.dispose();
    } catch (_) {}
  }

  // ─── Frame gönderme ──────────────────────────────────────────────────────────

  void _sendFrame(CameraImage image) {
    if (_isStopped || _busy) return; // önceki frame bitmeden yenisini atma
    if (image.planes.length < 3) return;
    _busy = true;

    _channel
        .invokeMethod<Map<Object?, Object?>>('processFrame', {
          'y': image.planes[0].bytes,
          'u': image.planes[1].bytes,
          'v': image.planes[2].bytes,
          'yRowStride': image.planes[0].bytesPerRow,
          'uvRowStride': image.planes[1].bytesPerRow,
          'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
          'width': image.width,
          'height': image.height,
        })
        .then((result) {
          if (!_isStopped && result != null) _onHandResult(result);
        })
        .catchError((Object e) {
          debugPrint('[CameraHandService] processFrame hatası: $e');
        })
        .whenComplete(() => _busy = false);
  }

  // ─── Sonuç işleme ────────────────────────────────────────────────────────────

  void _onHandResult(Map<Object?, Object?> data) {
    final found = data['found'] as bool? ?? false;
    final isPunch = data['isPunch'] as bool? ?? false;

    if (!found) {
      if (++_misses >= _maxMisses) {
        _smoothX = 0;
        _controller.normalizedX = 0.0;
        fingerNotifier.value = null;
      }
      _detectPunch(false);
      return;
    }
    _misses = 0;

    final fx = (data['fingerX'] as num).toDouble();
    final fy = (data['fingerY'] as num).toDouble();
    fingerNotifier.value = Offset(fx, fy);

    // [0,1] → [-1,1]. Ön kamera ayna görüntüsü — X ters çevrilir.
    final raw = ((0.5 - fx) * 2.0 * _gain).clamp(-1.0, 1.0);
    _smoothX = _smoothX * (1 - _emaAlpha) + raw * _emaAlpha;

    final mag = _smoothX.abs();
    _controller.normalizedX = mag < _deadZone
        ? 0.0
        : _smoothX.sign * ((mag - _deadZone) / (1 - _deadZone));

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
