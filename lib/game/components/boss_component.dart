import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Boss — "Karga Reis". Her 15 metrede bir belirir, her seferinde daha
/// büyük, daha hızlı ve daha dayanıklıdır. Yalnızca X ekseninde hareket eder.
class BossComponent extends PositionComponent
    with HasGameReference<FingerJumpGame> {
  // ─── Sprite ─────────────────────────────────────────────────────────────────

  static const List<String> _body = [
    '.......oo.......',
    '......oKKo......',
    '....ooKKKKoo....',
    '...oKKKKKKKKo...',
    '..oKAKKKKKKAKo..',
    '..oKWAKKKKAWKo..',
    '..oKWRKKKKRWKo..',
    '..oKKKYYYYKKKo..',
    '..oKKKyYYyKKKo..',
    '..oKKKKyyKKKKo..',
    '..oKKGGGGGGKKo..',
    '...oKGGGGGGKo...',
    '....ooKKKKoo....',
    '.....YY..YY.....',
  ];

  // Sol kanat (4 sütun), satır ofsetiyle birlikte.
  static const List<String> _wingUp = [
    'o...',
    'oK..',
    'oKK.',
    'oKKo',
    '.oKK',
    '..oK',
  ];
  static const int _wingUpRow = 1;
  static const List<String> _wingDown = [
    '...K',
    '..oK',
    '.oKK',
    'oKKo',
    'oKo.',
    'o...',
  ];
  static const int _wingDownRow = 6;

  static const _pal = {
    'o': ui.Color(0xFF1A1424),
    'K': ui.Color(0xFF3A3150),
    'A': ui.Color(0xFF0E0A16),
    'W': ui.Color(0xFFFFFFFF),
    'R': ui.Color(0xFFE0352B),
    'Y': ui.Color(0xFFFFB63A),
    'y': ui.Color(0xFFD9822A),
    'G': ui.Color(0xFF6A6080),
  };

  static List<ui.Image>? _frames;
  static List<ui.Image> get frames => _frames ??= [
    gridToImage(_compose(_wingUp, _wingUpRow), _pal),
    gridToImage(_compose(_wingDown, _wingDownRow), _pal),
  ];

  static List<String> _compose(List<String> wing, int row) {
    final out = [for (final r in _body) '..$r..'];
    for (var i = 0; i < wing.length; i++) {
      final y = row + i;
      final chars = out[y].split('');
      final w = wing[i];
      for (var x = 0; x < 4; x++) {
        if (w[x] == '.') continue;
        if (chars[x] == '.') chars[x] = w[x];
        final mx = chars.length - 1 - x;
        if (chars[mx] == '.') chars[mx] = w[x];
      }
      out[y] = chars.join();
    }
    return out;
  }

  static const int _gw = 20, _gh = 14;

  // ─── HP bar ─────────────────────────────────────────────────────────────────

  static final ui.Paint _barBg = ui.Paint()..color = const ui.Color(0xFF3A2416);
  static final ui.Paint _barFg = ui.Paint()..color = const ui.Color(0xFFE0352B);
  static final ui.Paint _barHi = ui.Paint()..color = const ui.Color(0xFFFF8A7A);
  static final ui.Paint _flash = ui.Paint()
    ..colorFilter = const ui.ColorFilter.mode(
      ui.Color(0xFFFFFFFF),
      ui.BlendMode.srcATop,
    )
    ..filterQuality = ui.FilterQuality.none;

  // ─── Durum ──────────────────────────────────────────────────────────────────

  final int level;
  late int _hp;
  double _dirX = 1.0;
  double _t = 0;
  double _hitFlash = 0;
  double _entry = 0; // giriş animasyonu (0→1)
  final double _targetY;

  int get _maxHp => level;
  double get _speed => 60.0 + level * 25.0;

  BossComponent({required Vector2 position, required this.level})
    : _targetY = position.y,
      super(
        position: Vector2(position.x, position.y - 160),
        size: Vector2(_gw * _scaleFor(level), _gh * _scaleFor(level)),
        anchor: Anchor.center,
      ) {
    _hp = _maxHp;
  }

  static double _scaleFor(int level) => math.min(3.0 + level * 0.35, 5.0);

  @override
  void update(double dt) {
    _t += dt;
    if (_hitFlash > 0) _hitFlash -= dt;

    // Yumuşak giriş: yukarıdan süzülerek yerine oturur.
    if (_entry < 1) {
      _entry = math.min(1, _entry + dt * 1.6);
      final e = 1 - math.pow(1 - _entry, 3);
      position.y = _targetY - 160 * (1 - e);
    } else {
      position.y = _targetY + math.sin(_t * 4) * 4;
    }

    position.x += _dirX * _speed * dt;
    final halfW = size.x / 2;
    final screenW = game.size.x;
    if (position.x >= screenW - halfW) {
      position.x = screenW - halfW;
      _dirX = -1;
    } else if (position.x <= halfW) {
      position.x = halfW;
      _dirX = 1;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final img = frames[(_t * 6).floor() % 2];
    final dst = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final src = const ui.Rect.fromLTWH(0, 0, _gw * 1.0, _gh * 1.0);
    if (_dirX < 0) {
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(img, src, dst, _hitFlash > 0 ? _flash : pixelPaint);
    if (_dirX < 0) canvas.restore();

    // HP bar (piksel çerçeveli).
    const h = 8.0;
    final y = -h - 8;
    canvas.drawRect(ui.Rect.fromLTWH(-2, y - 2, size.x + 4, h + 4), _barBg);
    final w = size.x * _hp / _maxHp;
    canvas.drawRect(ui.Rect.fromLTWH(0, y, w, h), _barFg);
    canvas.drawRect(ui.Rect.fromLTWH(0, y, w, 2), _barHi);
  }

  void takeDamage() {
    if (_hp <= 0) return;
    _hp--;
    _hitFlash = 0.08;
    if (_hp == 0) {
      game.onBossDefeated();
      removeFromParent();
    }
  }
}
