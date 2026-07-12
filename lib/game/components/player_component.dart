import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pixel_game/game/components/platform_component.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// Oyuncuyu temsil eden component.
///
/// Fizik: yerçekimi + zıplama + yatay hareket (InputController).
/// Collision: Flame broad-phase + manuel alt-kenar sweep kontrolü.
class PlayerComponent extends PositionComponent
    with HasGameReference<FingerJumpGame>, CollisionCallbacks {
  // ─── Fizik sabitleri ────────────────────────────────────────────────────────

  static const double gravity = 980.0;
  static const double jumpVelocity = -650.0;

  /// Güçlendirici platform çarpanı.
  static const double boostMultiplier = 2.0;

  /// Tam ±1 girişte ulaşılan maksimum yatay hız (piksel/sn).
  static const double maxSpeedX = 300.0;

  // ─── Boyut ──────────────────────────────────────────────────────────────────

  static const double playerWidth = 44.0;
  static const double playerHeight = 44.0;

  // ─── Runtime durum ──────────────────────────────────────────────────────────

  double _velocityY = 0.0;

  /// Bir önceki frame'deki alt kenar Y (sweep collision için).
  double _prevBottomY = 0.0;

  // ─── Bağımlılıklar ──────────────────────────────────────────────────────────

  final InputController _inputController;

  // ─── Constructor ────────────────────────────────────────────────────────────

  PlayerComponent({
    required Vector2 spawnPosition,
    required this._inputController,
  }) : super(
          position: spawnPosition,
          size: Vector2(playerWidth, playerHeight),
          anchor: Anchor.center,
        );

  // ─── Yükleme ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF4FC3F7),
    ));

    add(RectangleHitbox());
    jump();
  }

  // ─── Oyun döngüsü ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Önceki alt kenar — sweep collision için.
    _prevBottomY = position.y + playerHeight / 2;

    _velocityY += gravity * dt;
    position.y += _velocityY * dt;
    position.x += _inputController.normalizedX * maxSpeedX * dt;
    _wrapHorizontal();

    // Manuel sweep: Flame collision'ın büyük dt'de kaçırdığı platformları yakala.
    // Düşerken (_velocityY > 0) platformların üst kenarını geçip geçmediğimizi kontrol et.
    if (_velocityY > 0) {
      _sweepCheckPlatforms();
    }
  }

  // ─── Sweep collision ─────────────────────────────────────────────────────────

  /// Flame'in broad-phase collision'ının büyük dt'de kaçırabileceği
  /// platform çarpışmalarını manuel sweep ile yakalar.
  ///
  /// Yalnızca düşerken aktif — bu performanslı, yukarı giderken çalışmaz.
  void _sweepCheckPlatforms() {
    final currentBottomY = position.y + playerHeight / 2;
    final playerLeft = position.x - playerWidth / 2;
    final playerRight = position.x + playerWidth / 2;

    for (final component in game.world.children) {
      if (component is! PlatformComponent) continue;
      if (component.isRemoving) continue;

      final platformTopY = component.position.y - PlatformComponent.platformHeight / 2;
      final platformLeft = component.position.x - component.size.x / 2;
      final platformRight = component.position.x + component.size.x / 2;

      // X ekseni örtüşüyor mu?
      if (playerRight <= platformLeft || playerLeft >= platformRight) continue;

      // Bu frame platformun üst kenarını geçtik mi? (sweep)
      if (_prevBottomY <= platformTopY && currentBottomY >= platformTopY) {
        _landOnPlatform(component);
        break; // Bir frame'de tek platform çarpışması yeterli
      }
    }
  }

  void _landOnPlatform(PlatformComponent platform) {
    // Oyuncuyu platform üstüne oturtur — içine gömülmeyi önler.
    position.y = platform.position.y
        - PlatformComponent.platformHeight / 2
        - playerHeight / 2;

    switch (platform.type) {
      case PlatformType.normal:
        jump();
      case PlatformType.fragile:
        jump();
        platform.scheduleRemoval();
      case PlatformType.boost:
        jumpBoost();
    }
  }

  // ─── Çarpışma (Flame broad-phase) ───────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! PlatformComponent) return;

    // Düşmüyorsa zıplama.
    if (_velocityY <= 0) return;

    // Oyuncunun alt merkezi platform merkezinin üstündeyse üstten çarpmış sayılır.
    // (Anchor.center kullanıldığı için merkez koordinatı doğrudan kullanılabilir)
    final playerBottom = position.y + playerHeight / 2;
    final platformTop = other.position.y - PlatformComponent.platformHeight / 2;

    // Platformun üstünden mi geldi? Zaten sweep'te halledilmiş olabilir.
    if (playerBottom > platformTop + PlatformComponent.platformHeight) return;

    _landOnPlatform(other);
  }

  // ─── Yardımcı metodlar ──────────────────────────────────────────────────────

  void jump() {
    _velocityY = jumpVelocity;
  }

  void jumpBoost() {
    _velocityY = jumpVelocity * boostMultiplier;
  }

  void _wrapHorizontal() {
    final w = game.size.x;
    if (position.x < -playerWidth / 2) {
      position.x = w + playerWidth / 2;
    } else if (position.x > w + playerWidth / 2) {
      position.x = -playerWidth / 2;
    }
  }
}
