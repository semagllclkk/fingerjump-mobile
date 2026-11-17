import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/cats.dart';
import 'package:pixel_game/game/components/platform_component.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// Oyuncu — seçilen kedi.
///
/// Fizik: yerçekimi + otomatik zıplama + yatay hareket (InputController).
/// Çarpışma: yalnızca düşerken, alt kenar sweep testi (Flame collision yok).
class PlayerComponent extends PositionComponent
    with HasGameReference<FingerJumpGame> {
  // ─── Fizik sabitleri ────────────────────────────────────────────────────────

  static const double gravity = 980.0;
  static const double jumpVelocity = -650.0;
  static const double boostMultiplier = 2.0;
  static const double maxSpeedX = 300.0;

  /// Yatay hızın hedefe yaklaşma katsayısı (1/sn). Kamera modundaki seyrek ve
  /// titrek girişleri yumuşatır; jiroskopta da hissedilir bir gecikme yaratmaz.
  static const double _steerResponse = 12.0;

  // ─── Boyut ──────────────────────────────────────────────────────────────────

  static const double playerWidth = 40.0;
  static const double playerHeight = 44.0;
  static const double _spriteScale = 3.0;
  static const double _spriteSize = CatSprites.size * _spriteScale; // 48

  // ─── Durum ──────────────────────────────────────────────────────────────────

  double _velocityY = 0.0;
  double _velocityX = 0.0;
  double _prevBottomY = 0.0;
  bool _facingLeft = false;

  double _squash = 0.0; // iniş ezilmesi (0..1)
  double _blinkTimer = 2.5;
  double _invulnerable = 0.0;
  double _t = 0;

  bool get isInvulnerable => _invulnerable > 0;

  final InputController _inputController;
  final CatInfo cat;
  late final List<ui.Image> _frames;
  final ui.Paint _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;

  PlayerComponent({
    required Vector2 spawnPosition,
    required this._inputController,
    required this.cat,
  }) : super(
         position: spawnPosition,
         size: Vector2(playerWidth, playerHeight),
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _frames = CatSprites.framesFor(cat.breed);
    jump();
  }

  // ─── Oyun döngüsü ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    _t += dt;
    if (_squash > 0) _squash = math.max(0, _squash - dt * 7);
    if (_invulnerable > 0) _invulnerable -= dt;
    _blinkTimer -= dt;
    if (_blinkTimer < -0.12) _blinkTimer = 2 + (_t * 7919 % 3);

    _prevBottomY = position.y + playerHeight / 2;

    _velocityY += gravity * dt;
    position.y += _velocityY * dt;

    final targetVx = _inputController.normalizedX * maxSpeedX * cat.speedMult;
    _velocityX += (targetVx - _velocityX) * math.min(1.0, dt * _steerResponse);
    position.x += _velocityX * dt;
    if (_velocityX.abs() > 12) _facingLeft = _velocityX < 0;
    _wrapHorizontal();

    if (_velocityY > 0) _sweepCheckPlatforms();
  }

  @override
  void render(ui.Canvas canvas) {
    // Dokunulmazlık sırasında yanıp sönme.
    if (_invulnerable > 0 && (_t * 12).floor().isEven) return;

    final rising = _velocityY < 0;
    var frame = rising ? 0 : 1;
    if (_blinkTimer < 0 && rising) frame = 2;
    if (_facingLeft) frame += 3;
    final img = _frames[frame];

    // Ezilme/uzama: inişte yassılaş, hızla yükselirken uza.
    final stretch = rising ? math.min(0.12, -_velocityY / 650 * 0.08) : 0.0;
    final sx = 1 + _squash * 0.22 - stretch * 0.5;
    final sy = 1 - _squash * 0.22 + stretch;
    final w = _spriteSize * sx;
    final h = _spriteSize * sy;
    // Ayaklar hitbox'ın altına otursun.
    final left = (size.x - w) / 2;
    final top = size.y - h + 2;

    canvas.drawImageRect(
      img,
      const ui.Rect.fromLTWH(
        0,
        0,
        CatSprites.size * 1.0,
        CatSprites.size * 1.0,
      ),
      ui.Rect.fromLTWH(left, top, w, h),
      _paint,
    );
  }

  // ─── Sweep collision ─────────────────────────────────────────────────────────

  void _sweepCheckPlatforms() {
    final currentBottomY = position.y + playerHeight / 2;
    final playerLeft = position.x - playerWidth / 2;
    final playerRight = position.x + playerWidth / 2;

    final platforms = game.platforms;
    for (var i = 0; i < platforms.length; i++) {
      final p = platforms[i];
      if (p.isBreaking) continue;
      final top = p.position.y - PlatformComponent.platformHeight / 2;
      if (_prevBottomY > top || currentBottomY < top) continue;
      final halfW = p.size.x / 2;
      if (playerRight <= p.position.x - halfW ||
          playerLeft >= p.position.x + halfW) {
        continue;
      }
      _landOnPlatform(p);
      return;
    }
  }

  void _landOnPlatform(PlatformComponent platform) {
    position.y =
        platform.position.y -
        PlatformComponent.platformHeight / 2 -
        playerHeight / 2;
    _squash = 1.0;

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

  // ─── Yardımcı metodlar ──────────────────────────────────────────────────────

  void jump() => _velocityY = jumpVelocity * cat.jumpMult;

  void jumpBoost() =>
      _velocityY = jumpVelocity * cat.jumpMult * boostMultiplier;

  /// Ekstra can kullanıldığında: verilen noktaya ışınla, yukarı fırlat.
  void revive(Vector2 at, {required bool boost}) {
    position.setFrom(at);
    _velocityX = 0;
    _invulnerable = 2.0;
    boost ? jumpBoost() : jump();
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
