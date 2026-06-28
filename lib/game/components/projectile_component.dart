import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pixel_game/game/components/boss_component.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Oyuncunun ekrana dokunmasıyla fırlattığı turuncu mermi.
///
/// Hareket: oyuncu konumundan yukarı doğru, [_speed] hızında.
/// Çarpışma: yalnızca [BossComponent]'a tepki verir.
/// Temizleme: kamera görüş alanının 1 ekran üstüne geçince kaldırılır.
///
/// Tasarım notu:
///   Boss dışı çarpışmalar (platformlar vb.) görmezden gelinir.
///   Bu yüzden [onCollisionStart] içinde açık tip kontrolü yapılır.
class ProjectileComponent extends PositionComponent
    with HasGameReference<FingerJumpGame>, CollisionCallbacks {
  // ─── Sabitler ───────────────────────────────────────────────────────────────

  static const double _speed = 520.0; // px/s — ekranı ~1.7s'de geçer
  static const double _sideLength = 12.0;
  static const Color _color = Color(0xFFFF9800); // turuncu

  // ─── Constructor ─────────────────────────────────────────────────────────────

  ProjectileComponent({required Vector2 spawnPosition})
      : super(
          position: spawnPosition,
          size: Vector2.all(_sideLength),
          anchor: Anchor.center,
        );

  // ─── Yükleme ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(RectangleComponent(size: size, paint: Paint()..color = _color));
    add(RectangleHitbox());
  }

  // ─── Güncelleme ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Yukarı doğru hareket (Y azalır).
    position.y -= _speed * dt;

    // Kameranın görüş alanından 1 ekran fazla yukarıya çıkınca sil.
    final cameraTopY =
        game.camera.viewfinder.position.y - game.size.y / 2;
    if (position.y < cameraTopY - game.size.y) {
      removeFromParent();
    }
  }

  // ─── Çarpışma ───────────────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // Yalnızca boss'a çarparsa tepki ver.
    if (other is BossComponent) {
      other.takeDamage();
      removeFromParent();
    }
  }
}
