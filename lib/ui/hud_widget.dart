import 'package:flutter/material.dart';

/// Oyunun üstüne kaplanan HUD (Head-Up Display).
///
/// Şu an gösterilenler:
///   • Mesafe sayacı (metre cinsinden yükseklik)
///
/// Flutter widget'ı olduğu için Flame canvas'ına dokunmaz.
/// [main.dart]'ta [GameWidget]'ın üstüne Stack ile katmanlanır.
///
/// [scoreNotifier] değiştiğinde YALNIZCA skor metni rebuild edilir —
/// tüm widget ağacı değil. Performans için önemli.
class HudWidget extends StatelessWidget {
  final ValueNotifier<int> scoreNotifier;

  const HudWidget({super.key, required this.scoreNotifier});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScoreDisplay(scoreNotifier: scoreNotifier),
          ],
        ),
      ),
    );
  }
}

/// Skor göstergesi — yalnızca [scoreNotifier] değişince rebuild edilir.
class _ScoreDisplay extends StatelessWidget {
  final ValueNotifier<int> scoreNotifier;

  const _ScoreDisplay({required this.scoreNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: scoreNotifier,
      builder: (_, score, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _ScoreCard(score: score, key: ValueKey(score)),
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;

  const _ScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(102), // %40 şeffaf siyah
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha(51), // %20 şeffaf beyaz kenarlık
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withAlpha(30),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'm',
            style: TextStyle(
              color: Colors.white.withAlpha(179), // %70 şeffaf
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
