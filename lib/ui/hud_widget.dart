import 'package:flutter/material.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/ui/farm_theme.dart';

/// Oyunun üstündeki HUD: coin · metre · ekstra can + boss ipucu.
///
/// Her parça kendi ValueListenableBuilder'ı ile yalnızca ilgili değer
/// değişince yeniden çizilir; oyun canvas'ına dokunmaz.
class HudWidget extends StatelessWidget {
  final FingerJumpGame game;
  final String fireHint;

  const HudWidget({super.key, required this.game, required this.fireHint});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Chip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SpinningCoin(scale: 2),
                      const SizedBox(width: 6),
                      ValueListenableBuilder<int>(
                        valueListenable: game.coinNotifier,
                        builder: (_, v, _) => Text('$v', style: Farm.text(26)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: game.scoreNotifier,
                  builder: (_, v, _) => _Chip(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$v', style: Farm.text(34)),
                          TextSpan(
                            text: ' m',
                            style: Farm.text(20, color: Farm.ink2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (game.cat.extraLives > 0)
                  ValueListenableBuilder<int>(
                    valueListenable: game.livesNotifier,
                    builder: (_, v, _) => _Chip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < game.cat.extraLives; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _Heart(filled: i < v),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 64),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: game.bossNotifier,
              builder: (_, boss, _) => AnimatedOpacity(
                opacity: boss ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _Chip(
                  color: Farm.pink,
                  child: Text(
                    'KARGA REİS! $fireHint',
                    style: Farm.text(20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  final Color color;
  const _Chip({required this.child, this.color = Farm.parch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Farm.wood, width: 3),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Farm.woodDark, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _Heart extends StatelessWidget {
  final bool filled;
  const _Heart({required this.filled});

  static const _rows = [
    '.oo.oo.',
    'oRRoRRo',
    'oRWRRRo',
    'oRRRRRo',
    '.oRRRo.',
    '..oRo..',
    '...o...',
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(21, 21),
      painter: _HeartPainter(filled),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final bool filled;
  _HeartPainter(this.filled);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    const s = 3.0;
    for (var y = 0; y < _Heart._rows.length; y++) {
      final row = _Heart._rows[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.') continue;
        p.color = switch (ch) {
          'o' => const Color(0xFF5B1A2A),
          'W' => filled ? Colors.white : const Color(0xFFB8A8A0),
          _ => filled ? const Color(0xFFE0352B) : const Color(0xFF9A8A80),
        };
        canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.filled != filled;
}
