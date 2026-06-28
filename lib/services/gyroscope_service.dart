import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// Cihazın ivmeölçerini okuyarak yatay eğimi normalize X değerine dönüştürür.
///
/// Neden ivmeölçer, jiroskop değil?
///   Jiroskop → dönüş hızını verir, sürekli integrasyon gerekir, kayar.
///   İvmeölçer → yerçekimini verir, eğim doğrudan hesaplanır, stabil.
///
/// Fizik:
///   Telefon dik tutulduğunda ivmeölçer X ≈ 0.
///   Sağa eğilince X pozitif, sola eğilince X negatif olur.
///   [_sensitivityMs2] değerinde eğim tam ±1 değerine karşılık gelir.
///
/// Smoothing (EMA — Üstel Hareketli Ortalama):
///   Gürültüyü azaltır, gecikmeyi düşük tutar.
///   [_emaAlpha] yüksek = daha duyarlı, daha gürültülü.
///   [_emaAlpha] düşük  = daha yumuşak, biraz daha geç tepki.
///
/// Dead zone:
///   Çok küçük eğimler sıfır sayılır. Durağan telefon drift yapmaz.
class GyroscopeService {
  final InputController _controller;

  // ─── Ayarlanabilir parametreler ─────────────────────────────────────────────

  /// Bu kadar m/s² ivme tam ±1 değerine karşılık gelir.
  /// sin(25°) × 9.8 ≈ 4.1 → 25° eğimde tam hız.
  static const double _sensitivityMs2 = 4.1;

  /// EMA katsayısı: 0.18 ≈ iyi denge noktası.
  static const double _emaAlpha = 0.18;

  /// Bu aralıkta kalan değerler 0 sayılır. Küçük titreşimleri önler.
  static const double _deadZone = 0.04;

  // ─── Internal durum ─────────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _subscription;
  double _smoothed = 0.0;

  // ─── Constructor ─────────────────────────────────────────────────────────────

  GyroscopeService(this._controller);

  // ─── Yaşam döngüsü ──────────────────────────────────────────────────────────

  /// İvmeölçer akışını başlatır.
  /// Platforma sahip olmayan cihazlarda (web, masaüstü) sessizce devam eder.
  void start() {
    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval, // ~20ms, oyun için ideal
      ).listen(_onAccelerometer, onError: _onError);

      debugPrint('[GyroscopeService] İvmeölçer başlatıldı.');
    } catch (e) {
      debugPrint('[GyroscopeService] Sensör desteklenmiyor: $e');
    }
  }

  /// İvmeölçer akışını durdurur ve kaynağı serbest bırakır.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _controller.normalizedX = 0.0;
    debugPrint('[GyroscopeService] Durduruldu.');
  }

  // ─── İç işlem ───────────────────────────────────────────────────────────────

  void _onAccelerometer(AccelerometerEvent event) {
    // 1. Ham değeri normalize et.
    //    event.x: sağa eğilince pozitif, sola eğilince negatif.
    //    Not: bazı cihazlarda işaret tersine gelebilir — yorum satırından düzeltin.
    final raw = (-event.x / _sensitivityMs2).clamp(-1.0, 1.0);

    // 2. EMA smoothing uygula.
    _smoothed = _smoothed * (1 - _emaAlpha) + raw * _emaAlpha;

    // 3. Dead zone uygula + rescale (dead zone dışı tam aralığı doldursun).
    final value = _applyDeadZone(_smoothed, _deadZone);

    _controller.normalizedX = value;
  }

  void _onError(Object error) {
    debugPrint('[GyroscopeService] Sensör hatası: $error');
  }

  /// Dead zone uygular ve kalan aralığı [-1, 1]'e rescale eder.
  ///
  /// Örnek: deadZone=0.04, raw=0.06 → rescaled = (0.06-0.04)/(1-0.04) ≈ 0.02
  double _applyDeadZone(double value, double deadZone) {
    if (value.abs() < deadZone) return 0.0;
    final sign = value.sign;
    final rescaled = (value.abs() - deadZone) / (1.0 - deadZone);
    return sign * math.min(rescaled, 1.0);
  }
}
