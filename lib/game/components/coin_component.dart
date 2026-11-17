import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Klasik 2D piksel oyun coin'i — kendi ekseninde dönen altın para.
///
/// Kareler bir kez prosedürel olarak 12×12 ızgaraya çizilir (kontur, açık
/// sol-üst kenar, koyu sağ-alt kenar, ortada kabartma çizgi, parıltı) ve
/// tüm coin'ler aynı resimleri paylaşır.
class CoinComponent extends PositionComponent
    with HasGameReference<FingerJumpGame> {
  static const int _px = 12;
  static const double pixelScale = 2.0;
  static const double drawSize = _px * pixelScale;
  static const double _pickupRadius = 30.0;
  static const double _fps = 10.0;

  final double phase;
  double _t = 0;
  final double _baseY;
  bool _collected = false;
  bool _magnetized = false;

  CoinComponent({required Vector2 position, this.phase = 0})
    : _baseY = position.y,
      super(
        position: position,
        size: Vector2.all(drawSize),
        anchor: Anchor.center,
      );

  @override
  void update(double dt) {
    _t += dt;
    if (_collected) return;

    final player = game.player;
    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final d2 = dx * dx + dy * dy;

    final magnet = game.cat.magnetRadius;
    if (_magnetized || (magnet > 0 && d2 < magnet * magnet)) {
      _magnetized = true;
      final d = math.sqrt(d2) + 0.001;
      final speed = 520.0 * dt;
      position.x += dx / d * math.min(speed, d);
      position.y += dy / d * math.min(speed, d);
    } else {
      // Hafif yukarı-aşağı süzülme.
      position.y = _baseY + math.sin(_t * 3 + phase) * 3;
    }

    if (d2 < _pickupRadius * _pickupRadius) {
      _collected = true;
      game.collectCoin(this);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final frames = CoinArt.frames;
    final i = ((_t + phase) * _fps).floor() % frames.length;
    final img = frames[i];
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, drawSize, drawSize),
      pixelPaint,
    );
  }
}

/// Coin toplanınca çıkan kısa ışıltı + "+1" yazısı.
class CoinSparkle extends PositionComponent {
  static final ui.Paint _paint = ui.Paint()..isAntiAlias = false;
  final int value;
  double _t = 0;
  static const double _life = 0.45;

  CoinSparkle({required Vector2 position, this.value = 1})
    : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    _t += dt;
    position.y -= 40 * dt;
    if (_t >= _life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final k = (_t / _life).clamp(0.0, 1.0);
    final a = ((1 - k) * 255).toInt();
    final r = 6 + k * 14;
    _paint.color = ui.Color.fromARGB(a, 255, 236, 140);
    for (var j = 0; j < 4; j++) {
      final ang = j * math.pi / 2 + math.pi / 4;
      canvas.drawRect(
        ui.Rect.fromCenter(
          center: ui.Offset(math.cos(ang) * r, math.sin(ang) * r),
          width: 4,
          height: 4,
        ),
        _paint,
      );
    }
    _paint.color = ui.Color.fromARGB(a, 255, 255, 255);
    canvas.drawRect(
      ui.Rect.fromCenter(center: ui.Offset.zero, width: 4, height: 4),
      _paint,
    );
  }
}

class CoinArt {
  static List<ui.Image>? _frames;

  static List<ui.Image> get frames => _frames ??= _build();

  static const _pal = {
    'o': ui.Color(0xFF7A3E0C), // kontur
    'D': ui.Color(0xFFD98A16), // koyu kenar
    'G': ui.Color(0xFFF8C630), // altın
    'L': ui.Color(0xFFFFE68A), // açık kenar
    'W': ui.Color(0xFFFFFFFF), // parıltı
  };

  static List<ui.Image> _build() {
    // Yarı genişlikler: tam yüz → kenar → tekrar yüz (dönme hissi).
    const rxs = [6.0, 4.6, 2.6, 1.0, 2.6, 4.6];
    return [for (final rx in rxs) gridToImage(_frame(rx), _pal)];
  }

  static List<String> _frame(double rx) {
    const n = CoinComponent._px;
    const cx = n / 2, cy = n / 2, ry = n / 2;
    bool inside(int x, int y) {
      if (x < 0 || y < 0 || x >= n || y >= n) return false;
      final dx = (x + 0.5 - cx) / rx;
      final dy = (y + 0.5 - cy) / ry;
      return dx * dx + dy * dy <= 1.0;
    }

    final rows = <String>[];
    for (var y = 0; y < n; y++) {
      final sb = StringBuffer();
      for (var x = 0; x < n; x++) {
        if (!inside(x, y)) {
          sb.write('.');
          continue;
        }
        if (rx <= 1.5) {
          // Tam yandan görünüm: ince altın şerit, uçlarda kontur.
          final tip = !inside(x, y - 1) || !inside(x, y + 1);
          sb.write(tip ? 'o' : (x + 0.5 < cx ? 'L' : 'D'));
          continue;
        }
        final edge =
            !inside(x - 1, y) ||
            !inside(x + 1, y) ||
            !inside(x, y - 1) ||
            !inside(x, y + 1);
        if (edge) {
          sb.write('o');
          continue;
        }
        final nearLeftTop = !inside(x - 2, y) || !inside(x, y - 2);
        final nearRightBottom = !inside(x + 2, y) || !inside(x, y + 2);
        if (nearLeftTop) {
          sb.write('L');
        } else if (nearRightBottom) {
          sb.write('D');
        } else if (rx > 3 &&
            (x + 0.5 - cx).abs() < rx * 0.22 &&
            y >= 3 &&
            y <= 8) {
          // Ortadaki kabartma çizgi (klasik coin "yuvası").
          sb.write((x + 0.5 < cx) ? 'L' : 'D');
        } else {
          sb.write('G');
        }
      }
      rows.add(sb.toString());
    }
    // Parıltı pikseli.
    if (rx > 4) {
      final r = rows[3].split('');
      final sx = (cx - rx * 0.45).floor();
      if (r[sx] != '.' && r[sx] != 'o') r[sx] = 'W';
      rows[3] = r.join();
    }
    return rows;
  }
}
