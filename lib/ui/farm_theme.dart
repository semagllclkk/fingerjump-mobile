import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/art/vines.dart';
import 'package:pixel_game/game/cats.dart';
import 'package:pixel_game/game/components/coin_component.dart';

/// Portfolyodaki çiftlik sahnesinin renkleri.
class Farm {
  static const font = 'Jersey10';

  static const parch = Color(0xFFFFF8E4);
  static const parch2 = Color(0xFFF6DBA6);
  static const parch3 = Color(0xFFE2B97A);
  static const wood = Color(0xFF8A5A2B);
  static const woodDark = Color(0xFF5B3A1E);
  static const ink = Color(0xFF3B2414);
  static const ink2 = Color(0xFF7A5A3A);
  static const pink = Color(0xFFC94A7E);
  static const pinkLight = Color(0xFFF27AA4);
  static const green = Color(0xFF4F8A3A);
  static const gold = Color(0xFFF8C630);
  static const skyTop = Color(0xFF8FD3FF);
  static const skyBottom = Color(0xFFE2F6FF);

  static TextStyle text(double size, {Color color = ink, double? height}) =>
      TextStyle(fontFamily: font, fontSize: size, color: color, height: height);
}

/// Pembe çiçekli sarmaşık çerçeve (portfolyo: src/farm/game/vines.js).
/// 28×28 piksellik 9 dilimli çerçeve; kenarlar gerilmez, tekrarlanır
/// (CSS'teki `border-image: ... round` karşılığı).
class VineFrame {
  static const int n = 28, c = vineCornerSize;

  static const _pal = {
    'P': ui.Color(0xFFF27AA4),
    'p': ui.Color(0xFFC94A7E),
    'Y': ui.Color(0xFFFFD35A),
    'W': ui.Color(0xFFFFE3EE),
    'V': ui.Color(0xFF4F8A3A),
    'G': ui.Color(0xFF86C45E),
    'g': ui.Color(0xFF4C8A3C),
  };

  static ui.Image? _img;

  static ui.Image get image => _img ??= _build();

  static ui.Image _build() {
    final grid = List.generate(n, (_) => List.filled(n, '.'));
    void put(int x, int y, String ch) {
      if (ch != '.') grid[y][x] = ch;
    }

    for (var y = 0; y < c; y++) {
      for (var x = 0; x < c; x++) {
        final ch = vineCorner[y][x];
        put(x, y, ch);
        put(n - 1 - x, y, ch);
        put(x, n - 1 - y, ch);
        put(n - 1 - x, n - 1 - y, ch);
      }
      for (var x = 0; x < n - 2 * c; x++) {
        final ch = vineEdge[y][x];
        put(c + x, y, ch);
        put(c + x, n - 1 - y, ch);
        put(y, c + x, ch);
        put(n - 1 - y, c + x, ch);
      }
    }
    return gridToImage([for (final r in grid) r.join()], _pal);
  }
}

/// [VineFrame]'i verilen alana, [pixel] ölçeğinde döşer.
class VineFramePainter extends CustomPainter {
  final double pixel;
  final Color fill;
  const VineFramePainter({this.pixel = 2, this.fill = Farm.parch2});

  @override
  void paint(Canvas canvas, Size size) {
    final img = VineFrame.image;
    const n = VineFrame.n * 1.0, c = VineFrame.c * 1.0;
    final s = pixel;
    final cs = c * s; // köşe boyutu (ekranda)

    // Zemin: dalın gövdesinin (3. piksel) altından başlar.
    final inset = 3 * s;
    canvas.drawRect(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Paint()..color = fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(inset, size.height - inset - s, size.width - inset * 2, s),
      Paint()..color = Farm.parch3,
    );

    void blit(Rect src, Rect dst) =>
        canvas.drawImageRect(img, src, dst, pixelPaint);

    // Köşeler
    blit(const Rect.fromLTWH(0, 0, c, c), Rect.fromLTWH(0, 0, cs, cs));
    blit(
      Rect.fromLTWH(n - c, 0, c, c),
      Rect.fromLTWH(size.width - cs, 0, cs, cs),
    );
    blit(
      Rect.fromLTWH(0, n - c, c, c),
      Rect.fromLTWH(0, size.height - cs, cs, cs),
    );
    blit(
      Rect.fromLTWH(n - c, n - c, c, c),
      Rect.fromLTWH(size.width - cs, size.height - cs, cs, cs),
    );

    // Kenarlar — tekrarla, son parçayı kırp.
    const e = n - 2 * c; // 14 piksel
    final es = e * s;
    for (var x = cs; x < size.width - cs; x += es) {
      final w = (size.width - cs - x).clamp(0.0, es);
      final sw = w / s;
      blit(Rect.fromLTWH(c, 0, sw, c), Rect.fromLTWH(x, 0, w, cs));
      blit(
        Rect.fromLTWH(c, n - c, sw, c),
        Rect.fromLTWH(x, size.height - cs, w, cs),
      );
    }
    for (var y = cs; y < size.height - cs; y += es) {
      final h = (size.height - cs - y).clamp(0.0, es);
      final sh = h / s;
      blit(Rect.fromLTWH(0, c, c, sh), Rect.fromLTWH(0, y, cs, h));
      blit(
        Rect.fromLTWH(n - c, c, c, sh),
        Rect.fromLTWH(size.width - cs, y, cs, h),
      );
    }
  }

  @override
  bool shouldRepaint(VineFramePainter old) =>
      old.pixel != pixel || old.fill != fill;
}

/// Sarmaşık çerçeveli parşömen kart.
class VineCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color fill;
  final double pixel;

  const VineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 18),
    this.fill = Farm.parch2,
    this.pixel = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: VineFramePainter(pixel: pixel, fill: fill),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Ahşap piksel buton.
class WoodButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;

  const WoodButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Farm.pink,
    this.fontSize = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    final light = Color.lerp(color, Colors.white, 0.3)!;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: dark, width: 3),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: dark, offset: const Offset(0, 4))],
        ),
        foregroundDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: light, width: 3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Farm.text(fontSize, color: Colors.white, height: 1.1).copyWith(
            shadows: [Shadow(color: dark, offset: const Offset(2, 2))],
          ),
        ),
      ),
    );
  }
}

/// Piksel sanatı resmi (bulanıklaştırmadan büyütür).
class PixelImage extends StatelessWidget {
  final ui.Image image;
  final double scale;
  const PixelImage(this.image, {super.key, this.scale = 3});

  @override
  Widget build(BuildContext context) {
    return RawImage(
      image: image,
      width: image.width * scale,
      height: image.height * scale,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }
}

/// Zıplayan / göz kırpan kedi animasyonu (menüler için).
class AnimatedCat extends StatefulWidget {
  final CatBreed breed;
  final double scale;
  final bool bounce;
  const AnimatedCat({
    super.key,
    required this.breed,
    this.scale = 5,
    this.bounce = true,
  });

  @override
  State<AnimatedCat> createState() => _AnimatedCatState();
}

class _AnimatedCatState extends State<AnimatedCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = CatSprites.framesFor(widget.breed);
    final size = CatSprites.size * widget.scale;
    return SizedBox(
      width: size,
      height: size + (widget.bounce ? 14 : 0),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          final up = widget.bounce ? (t < 0.5 ? t * 2 : 2 - t * 2) : 0.0;
          final eased = Curves.easeOut.transform(up);
          final frame = t > 0.86 && t < 0.92 ? 2 : (t < 0.5 ? 0 : 1);
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: widget.bounce ? 14 - eased * 14 : 0,
                child: PixelImage(frames[frame], scale: widget.scale),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dönen piksel coin (HUD ve menüler için).
class SpinningCoin extends StatefulWidget {
  final double scale;
  const SpinningCoin({super.key, this.scale = 2});

  @override
  State<SpinningCoin> createState() => _SpinningCoinState();
}

class _SpinningCoinState extends State<SpinningCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = CoinArt.frames;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => PixelImage(
        frames[(_c.value * frames.length).floor() % frames.length],
        scale: widget.scale,
      ),
    );
  }
}

/// Menülerdeki gökyüzü + bulut + çim arka planı.
class FarmSkyBackground extends StatelessWidget {
  final Widget child;
  const FarmSkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Farm.skyTop, Farm.skyBottom],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GrassPainter())),
          child,
        ],
      ),
    );
  }
}

class _GrassPainter extends CustomPainter {
  const _GrassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const s = 4.0;
    final top = size.height - 64;
    final p = Paint();
    p.color = const Color(0xFF94603A);
    canvas.drawRect(Rect.fromLTWH(0, top + 20, size.width, 64), p);
    p.color = const Color(0xFF6DB04A);
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, 20), p);
    p.color = const Color(0xFF9BD46A);
    for (var x = 0.0; x < size.width; x += s) {
      final h = ((x / s).floor() % 5 == 0) ? s * 2 : s;
      canvas.drawRect(Rect.fromLTWH(x, top - h + s, s, h), p);
    }
    p.color = const Color(0xFF5B3A1E);
    canvas.drawRect(Rect.fromLTWH(0, top + 20, size.width, s), p);
  }

  @override
  bool shouldRepaint(_GrassPainter old) => false;
}
