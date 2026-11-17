import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Gökyüzü arka planı — kamera "backdrop" katmanında, ekran koordinatlarında
/// çizilir. Yükseldikçe gündüz → gün batımı → alacakaranlık → gece → uzay.
///
/// Performans: gradyan shader yalnızca renk değiştiğinde (metre başına bir
/// kez) yeniden oluşturulur; bulutlar önceden çizilmiş resimlerdir; yıldızlar
/// tek bir drawRawPoints çağrısıdır.
class SkyBackdrop extends Component with HasGameReference<FingerJumpGame> {
  static const _stops = <(double, ui.Color, ui.Color)>[
    (0, ui.Color(0xFF8FD3FF), ui.Color(0xFFE2F6FF)), // gündüz
    (60, ui.Color(0xFFFF9EB0), ui.Color(0xFFFFE0B0)), // gün batımı
    (130, ui.Color(0xFF5B4A9C), ui.Color(0xFFF2A7C3)), // alacakaranlık
    (210, ui.Color(0xFF151B45), ui.Color(0xFF3A2F6B)), // gece
    (320, ui.Color(0xFF05060F), ui.Color(0xFF141A40)), // uzay
  ];

  final ui.Paint _skyPaint = ui.Paint();
  final ui.Paint _cloudPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none;
  final ui.Paint _starPaint = ui.Paint()
    ..strokeWidth = 2
    ..strokeCap = ui.StrokeCap.square;

  int _shaderMeters = -1;
  double _lastH = 0;
  double _night = 0;

  late final List<ui.Image> _cloudImgs;
  final List<_Cloud> _clouds = [];
  late final List<double> _starBase; // [x0,y0,x1,y1,...] normalize 0..1
  late final Float32List _starPts;

  @override
  Future<void> onLoad() async {
    _cloudImgs = [
      gridToImage(_cloudA, _cloudPal, scale: 3),
      gridToImage(_cloudB, _cloudPal, scale: 3),
    ];
    final rng = math.Random(7);
    for (var i = 0; i < 7; i++) {
      _clouds.add(
        _Cloud(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          img: i % 2,
          speed: 6 + rng.nextDouble() * 10,
          parallax: 0.15 + rng.nextDouble() * 0.2,
        ),
      );
    }
    _starBase = List.generate(120, (_) => rng.nextDouble());
    _starPts = Float32List(120);
  }

  @override
  void update(double dt) {
    for (final c in _clouds) {
      c.x += c.speed * dt / game.size.x;
      if (c.x > 1.2) c.x -= 1.5;
    }
  }

  (ui.Color, ui.Color) _colorsAt(double m) {
    for (var i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i], b = _stops[i + 1];
      if (m <= b.$1) {
        final t = ((m - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
        return (ui.Color.lerp(a.$2, b.$2, t)!, ui.Color.lerp(a.$3, b.$3, t)!);
      }
    }
    return (_stops.last.$2, _stops.last.$3);
  }

  @override
  void render(ui.Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    final climbed = math.max(0.0, game.startY - game.cameraTopY - h * 0.35);
    final meters = climbed / 100;

    final m = meters.floor();
    if (m != _shaderMeters || h != _lastH) {
      _shaderMeters = m;
      _lastH = h;
      final (top, bottom) = _colorsAt(m.toDouble());
      _skyPaint.shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, h), [
        top,
        bottom,
      ]);
      _night = ((m - 120) / 100).clamp(0.0, 1.0);
    }
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), _skyPaint);

    final camY = game.cameraTopY;

    // Yıldızlar (gece/uzay).
    if (_night > 0) {
      final shift = (-camY * 0.04) % h;
      for (var i = 0; i < 60; i++) {
        _starPts[i * 2] = _starBase[i * 2] * w;
        _starPts[i * 2 + 1] = (_starBase[i * 2 + 1] * h + shift) % h;
      }
      final tw = 0.75 + 0.25 * math.sin(game.elapsed * 2);
      _starPaint.color = ui.Color.fromARGB(
        (_night * tw * 230).toInt(),
        255,
        250,
        230,
      );
      canvas.drawRawPoints(ui.PointMode.points, _starPts, _starPaint);
    }

    // Bulutlar (gündüz belirgin, gece silik).
    final cloudAlpha = (1 - _night * 0.85).clamp(0.0, 1.0);
    if (cloudAlpha > 0.02) {
      _cloudPaint.color = ui.Color.fromARGB(
        (cloudAlpha * 235).toInt(),
        255,
        255,
        255,
      );
      final span = h * 1.4;
      for (final c in _clouds) {
        final img = _cloudImgs[c.img];
        var y = (c.y * span - camY * c.parallax) % span;
        y -= img.height.toDouble();
        canvas.drawImage(
          img,
          ui.Offset(c.x * w - img.width / 2, y),
          _cloudPaint,
        );
      }
    }
  }

  static const _cloudPal = {
    'o': ui.Color(0xFFC9D8EA),
    'W': ui.Color(0xFFFFFFFF),
    's': ui.Color(0xFFE4EEF8),
  };
  static const _cloudA = [
    '.....oooo.........',
    '...ooWWWWo..ooo...',
    '..oWWWWWWWooWWWo..',
    '.oWWWWWWWWWWWWWWo.',
    'oWWWWWWWWWWWWWWWWo',
    'osssssssssssssssso',
    '.oooooooooooooooo.',
  ];
  static const _cloudB = [
    '....ooo.....',
    '..ooWWWoo...',
    '.oWWWWWWWoo.',
    'oWWWWWWWWWWo',
    'osssssssssso',
    '.oooooooooo.',
  ];
}

class _Cloud {
  double x, y, speed, parallax;
  int img;
  _Cloud({
    required this.x,
    required this.y,
    required this.img,
    required this.speed,
    required this.parallax,
  });
}

/// Başlangıçtaki çiftlik zemini: çim + toprak + çit. Bir kez resme çizilir.
class GroundComponent extends PositionComponent {
  ui.Image? _img;
  static const int _s = 3;

  GroundComponent({required Vector2 position, required double width})
    : super(position: position, size: Vector2(width, 120));

  @override
  Future<void> onLoad() async {
    final cols = (size.x / _s).ceil();
    const rows = 40;
    _img = paintToImage(cols * _s, rows * _s, (c) {
      final p = ui.Paint()..isAntiAlias = false;
      void px(int x, int y, int color) {
        p.color = ui.Color(color);
        c.drawRect(
          ui.Rect.fromLTWH(x * _s * 1.0, y * _s * 1.0, _s * 1.0, _s * 1.0),
          p,
        );
      }

      final rng = math.Random(3);
      for (var x = 0; x < cols; x++) {
        // Çit (her 10 sütunda bir direk, arada iki kalas).
        if (x % 10 == 0) {
          for (var y = 0; y < 8; y++) {
            px(x, y, 0xFF8A5A2B);
            px(x + 1, y, 0xFF6B3F20);
          }
          px(x, 0, 0xFFB98A52);
        }
        px(x, 2, 0xFFB98A52);
        px(x, 5, 0xFFB98A52);
        px(x, 3, 0xFF8A5A2B);
        px(x, 6, 0xFF8A5A2B);

        // Çim üst kenar (dalgalı).
        final top = 8 + (rng.nextDouble() < 0.3 ? 0 : 1);
        for (var y = top; y < 13; y++) {
          px(x, y, y == top ? 0xFF9BD46A : 0xFF6DB04A);
        }
        if (rng.nextDouble() < 0.15) px(x, top - 1, 0xFF9BD46A);
        // Toprak.
        for (var y = 13; y < rows; y++) {
          final dark = rng.nextDouble() < 0.12;
          px(x, y, dark ? 0xFF7A4A28 : (y == 13 ? 0xFF5B3A1E : 0xFF94603A));
        }
        // Ara ara çiçek.
        if (rng.nextDouble() < 0.06) {
          px(x, top - 1, 0xFFF27AA4);
          px(x, top - 2, 0xFFFFD35A);
        }
      }
    });
  }

  @override
  void render(ui.Canvas canvas) {
    final img = _img;
    if (img != null) canvas.drawImage(img, ui.Offset.zero, pixelPaint);
  }
}
