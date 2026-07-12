import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Boss — her 15 metrede bir belirir, her seferinde biraz daha güçlü.
/// Yalnızca X ekseninde hareket eder (sol/sağ salınım).
/// Y pozisyonu sabittir — ışınlanma ya da dikey hareket yoktur.
class BossComponent extends PositionComponent
    with HasGameReference<FingerJumpGame>, CollisionCallbacks {
  // ─── Sabitler ───────────────────────────────────────────────────────────────

  static const Color _bossColor   = Color(0xFFEF5350); // kırmızı
  static const Color _barBgColor  = Color(0xFF37474F); // koyu gri arka plan
  static const Color _barHpColor  = Color(0xFF69F0AE); // neon yeşil HP

  static const double _barHeight = 6.0;
  static const double _barTopOffset = 10.0; // platformun kaç px üstünde

  // ─── Durum ──────────────────────────────────────────────────────────────────

  final int level;
  late int _hp;
  double _dirX = 1.0; // hareket yönü: +1 sağ, -1 sol

  late RectangleComponent _hpBar;

  // ─── Türetilen değerler ──────────────────────────────────────────────────────

  int get _maxHp => level;
  double get _speed => 60.0 + level * 25.0; // px/s

  // ─── Constructor ─────────────────────────────────────────────────────────────

  BossComponent({required Vector2 position, required this.level})
      : super(
          position: position, // Sabit Y — dikey hareket yok
          size: Vector2(50.0 + level * 10.0, 40.0 + level * 5.0),
          anchor: Anchor.center,
        ) {
    _hp = _maxHp;
  }

  // ─── Yükleme ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Kırmızı gövde.
    add(RectangleComponent(size: size, paint: Paint()..color = _bossColor));

    // HP bar arka planı — boss'un üstünde.
    add(
      RectangleComponent(
        position: Vector2(0, -_barTopOffset - _barHeight),
        size: Vector2(size.x, _barHeight),
        paint: Paint()..color = _barBgColor,
      ),
    );

    // HP bar (dolu).
    _hpBar = RectangleComponent(
      position: Vector2(0, -_barTopOffset - _barHeight),
      size: Vector2(size.x, _barHeight),
      paint: Paint()..color = _barHpColor,
    );
    add(_hpBar);

    add(RectangleHitbox());
  }

  // ─── Güncelleme ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Yalnızca X ekseninde sol/sağ salınım — Y sabittir.
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

  // ─── Hasar ──────────────────────────────────────────────────────────────────

  /// Mermi çarptığında çağrılır.
  void takeDamage() {
    if (_hp <= 0) return;
    _hp--;
    _hpBar.size = Vector2(size.x * _hp / _maxHp, _barHeight);

    if (_hp == 0) {
      game.onBossDefeated();
      removeFromParent();
    }
  }
}
