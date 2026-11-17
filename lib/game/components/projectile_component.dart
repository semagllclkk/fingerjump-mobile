import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Kedinin boss'a fırlattığı yün yumağı.
///
/// Flame çarpışma sistemi yerine boss ile tek bir AABB kontrolü yapılır:
/// sahnede en fazla birkaç mermi ve tek bir boss olduğu için bu en ucuz yol.
class ProjectileComponent extends PositionComponent
    with HasGameReference<FingerJumpGame> {
  static const double _speed = 560.0;
  static const double _scale = 2.0;

  static const List<String> _rows = [
    '..oooo..',
    '.oPpPPo.',
    'oPPpPPPo',
    'oPpPPpPo',
    'oPPpPpPo',
    'oPpPPpPo',
    '.oPPpPo.',
    '..oooo..',
  ];
  static const _pal = {
    'o': ui.Color(0xFF8A2A56),
    'P': ui.Color(0xFFF27AA4),
    'p': ui.Color(0xFFC94A7E),
  };
  static ui.Image? _img;

  ProjectileComponent({required Vector2 spawnPosition})
    : super(
        position: spawnPosition,
        size: Vector2.all(8 * _scale),
        anchor: Anchor.center,
      );

  @override
  void update(double dt) {
    position.y -= _speed * dt;
    angle += 12 * dt;

    final boss = game.activeBoss;
    if (boss != null && boss.isMounted) {
      final dx = (position.x - boss.position.x).abs();
      final dy = (position.y - boss.position.y).abs();
      if (dx < (boss.size.x + size.x) / 2 && dy < (boss.size.y + size.y) / 2) {
        boss.takeDamage();
        removeFromParent();
        return;
      }
    }

    if (position.y < game.cameraTopY - game.size.y * 0.2) {
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final img = _img ??= gridToImage(_rows, _pal);
    canvas.drawImageRect(
      img,
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      ui.Rect.fromLTWH(0, 0, size.x, size.y),
      pixelPaint,
    );
  }
}
