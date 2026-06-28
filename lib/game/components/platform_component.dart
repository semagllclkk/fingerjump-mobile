import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Platform türleri.
enum PlatformType {
  /// Normal yeşil platform — sınırsız kullanım.
  normal,

  /// Kırılgan turuncu platform — 1 zıplamadan sonra kaybolur.
  fragile,

  /// Güçlendirici altın platform — 3× yüksekliğe zıplatır.
  boost,
}

/// Oyuncunun üstüne zıplayabileceği platform.
///
/// Faz 3: Normal platform, hitbox.
/// Faz 5: Kırılgan ve güçlendirici türler eklendi.
///
/// Tasarım notu:
///   [PlatformComponent] tepkiyi kendisi vermiyor.
///   [PlayerComponent.onCollisionStart] type'ı okuyup ne yapacağına karar veriyor.
///   Platform sadece kırılgan ise [scheduleRemoval()] çağrılır.
class PlatformComponent extends PositionComponent {
  // ─── Sabitler ───────────────────────────────────────────────────────────────

  static const double defaultWidth = 90.0;
  static const double platformHeight = 14.0;

  static const _colors = {
    PlatformType.normal:  Color(0xFF66BB6A), // materyal yeşil
    PlatformType.fragile: Color(0xFFFF7043), // derin turuncu — tehlike
    PlatformType.boost:   Color(0xFFFFD600), // parlak altın — güç
  };

  // ─── Durum ──────────────────────────────────────────────────────────────────

  final PlatformType type;

  /// Kırılma geri sayımı. > 0 → kaybolma animasyonu sürüyor.
  double _removalCountdown = 0.0;
  bool _scheduledForRemoval = false;

  /// Görsel gövde — kırılma sırasında alfa azaltılır.
  late RectangleComponent _body;

  // ─── Constructor ─────────────────────────────────────────────────────────────

  PlatformComponent({
    required Vector2 position,
    double width = defaultWidth,
    this.type = PlatformType.normal,
  }) : super(
          position: position,
          size: Vector2(width, platformHeight),
          anchor: Anchor.center,
        );

  // ─── Yükleme ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _body = RectangleComponent(
      size: size,
      paint: Paint()..color = _colors[type]!,
    );
    add(_body);
    add(RectangleHitbox());
  }

  // ─── Güncelleme ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    if (_scheduledForRemoval) {
      _removalCountdown -= dt;

      // Alfa fade efekti — kırılıyor hissi verir.
      final ratio = (_removalCountdown / 0.3).clamp(0.0, 1.0);
      _body.paint.color = _colors[type]!.withAlpha((ratio * 255).toInt());

      if (_removalCountdown <= 0) removeFromParent();
    }
  }

  // ─── Dışarıdan çağrılan ──────────────────────────────────────────────────────

  /// Kırılgan platform bu metotla "kırılma" sürecini başlatır.
  /// Yalnızca [PlatformType.fragile] için anlamlıdır.
  void scheduleRemoval() {
    if (_scheduledForRemoval) return;
    _scheduledForRemoval = true;
    _removalCountdown = 0.30; // 300ms fade + kaybolma
  }
}
