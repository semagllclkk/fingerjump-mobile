import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pixel_game/game/components/platform_component.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// Oyuncuyu temsil eden component.
///
/// Faz 2: Otomatik zıplama, yerçekimi, yatay sarmal.
/// Faz 3: Çarpışma algılama.
/// Faz 4+7: Jiroskop hareketi (InputController).
/// Faz 5+6: Platform türlerine göre farklı tepkiler.
class PlayerComponent extends PositionComponent
    with HasGameReference<FingerJumpGame>, CollisionCallbacks {
  // ─── Fizik sabitleri ────────────────────────────────────────────────────────

  static const double gravity = 980.0;

  /// Normal zıplama hızı.
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

    _velocityY += gravity * dt;
    position.y += _velocityY * dt;
    position.x += _inputController.normalizedX * maxSpeedX * dt;
    _wrapHorizontal();
  }

  // ─── Çarpışma ───────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // Yalnızca platform çarpışmalarına bak.
    // Boss ve mermi çarpışmaları bu sınıfı ilgilendirmez.
    if (other is! PlatformComponent) return;

    // Düşerken ve üstten çarparken zıpla.
    if (_velocityY <= 0) return;
    if (position.y >= other.position.y) return;

    switch (other.type) {
      case PlatformType.normal:
        jump();

      case PlatformType.fragile:
        // Normal zıpla, sonra platform kaybolur.
        jump();
        other.scheduleRemoval();

      case PlatformType.boost:
        // 3× yükseklik — oyuncu çok daha yükseğe fırlar.
        jumpBoost();
    }
  }

  // ─── Yardımcı metodlar ──────────────────────────────────────────────────────

  /// Normal zıplama hız impulsı.
  void jump() {
    _velocityY = jumpVelocity;
  }

  /// Güçlendirici zıplama — [boostMultiplier] katı yükseklik.
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
