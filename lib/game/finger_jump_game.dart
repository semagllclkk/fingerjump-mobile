import 'dart:math' as math;
import 'dart:ui' show Color, VoidCallback;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:pixel_game/game/cats.dart';
import 'package:pixel_game/game/components/boss_component.dart';
import 'package:pixel_game/game/components/coin_component.dart';
import 'package:pixel_game/game/components/platform_component.dart';
import 'package:pixel_game/game/components/player_component.dart';
import 'package:pixel_game/game/components/projectile_component.dart';
import 'package:pixel_game/game/components/sky_backdrop.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// FingerJumpGame — Flame oyununun kök sınıfı.
///
/// Performans notları:
///   * Flame'in çarpışma sistemi (HasCollisionDetection) kullanılmıyor.
///     Platform inişi oyuncunun sweep testiyle, mermi-boss ve oyuncu-boss
///     tek AABB kontrolüyle yapılıyor → her frame 30+ hitbox'lık broad-phase yok.
///   * Platform ve coin'ler oyunun kendi listelerinde tutuluyor; her frame
///     `world.children.whereType` taraması yapılmıyor.
///   * Tüm sprite'lar önbellekli `ui.Image` → render başına tek drawImage.
class FingerJumpGame extends FlameGame with TapCallbacks {
  FingerJumpGame({CatBreed breed = CatBreed.sarman}) : cat = CatInfo.of(breed);

  static const Color skyTop = Color(0xFF8FD3FF);

  @override
  Color backgroundColor() => skyTop;

  // ─── Giriş ───────────────────────────────────────────────────────────────────

  final InputController inputController = InputController();
  final CatInfo cat;

  // ─── Skor / coin / can ───────────────────────────────────────────────────────

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> coinNotifier = ValueNotifier<int>(0);
  late final ValueNotifier<int> livesNotifier = ValueNotifier<int>(
    cat.extraLives,
  );

  /// Boss savaşı sürerken HUD'da "dokun → ateş" ipucu için.
  final ValueNotifier<bool> bossNotifier = ValueNotifier<bool>(false);

  double _startY = 0.0;
  double get startY => _startY;

  double elapsed = 0;

  // ─── Platform üretimi sabitleri ──────────────────────────────────────────────

  static const double _platformSpacing = 100.0;
  static const double _spawnLookahead = 3.0;
  static const double _despawnDistance = 1.2;
  static const double _boostFreeZoneBeforeBoss = 500.0;

  // ─── Boss sistemi ────────────────────────────────────────────────────────────

  static const int _bossEveryMeters = 15;
  int _nextBossAt = _bossEveryMeters;
  int _bossLevel = 1;
  bool _bossActive = false;
  BossComponent? _activeBoss;
  BossComponent? get activeBoss => _activeBoss;

  // ─── Despawn throttle ────────────────────────────────────────────────────────

  int _despawnCounter = 0;
  static const int _despawnEveryFrames = 30;

  // ─── Game Over ───────────────────────────────────────────────────────────────

  bool isGameOver = false;
  VoidCallback? onGameOver;

  void triggerGameOver() {
    if (isGameOver) return;
    isGameOver = true;
    pauseEngine();
    onGameOver?.call();
  }

  // ─── Runtime referanslar ─────────────────────────────────────────────────────

  late PlayerComponent _player;
  PlayerComponent get player => _player;

  final List<PlatformComponent> platforms = [];
  final List<CoinComponent> coins = [];

  final math.Random _rng = math.Random();
  double _highestPlatformY = 0.0;
  double _cameraTopY = 0.0;
  double get cameraTopY => _cameraTopY;

  // ─── Yükleme ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.backdrop.add(SkyBackdrop());

    _cameraTopY = 0.0;
    _applyCameraPosition();

    // Geniş başlangıç kartı — ilk iniş garantili.
    _highestPlatformY = size.y * 0.85;
    _addPlatform(
      PlatformComponent(
        position: Vector2(size.x / 2, _highestPlatformY),
        width: 160,
      ),
    );
    world.add(
      GroundComponent(
        position: Vector2(0, _highestPlatformY + 40),
        width: size.x,
      ),
    );

    _spawnPlatformsUpTo(-size.y);

    _startY = size.y * 0.75;
    _player = PlayerComponent(
      spawnPosition: Vector2(size.x / 2, _startY),
      inputController: inputController,
      cat: cat,
    );
    await world.add(_player);
  }

  // ─── Oyun döngüsü ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // dt clamp: takılma sonrası fizik patlamasını önle.
    final safeDt = dt.clamp(0.0, 1 / 30.0);
    elapsed += safeDt;

    super.update(safeDt);
    if (isGameOver) return;

    _updateScore();
    _checkFallGameOver();
    _scrollCamera();
    _spawnMorePlatforms();

    if (++_despawnCounter >= _despawnEveryFrames) {
      _despawnCounter = 0;
      _despawnOld();
    }

    if (_bossActive) {
      _checkBossCollision();
      _checkBossBypass();
    } else {
      _checkBossSpawn();
    }
  }

  // ─── Game Over / ekstra can ──────────────────────────────────────────────────

  void _checkFallGameOver() {
    if (_player.position.y > _cameraTopY + size.y * 1.05) {
      if (!_tryRevive()) triggerGameOver();
    }
  }

  bool _tryRevive() {
    if (livesNotifier.value <= 0) return false;
    livesNotifier.value--;
    _player.revive(
      Vector2(size.x / 2, _cameraTopY + size.y * 0.9),
      boost: !_bossActive,
    );
    return true;
  }

  void _checkBossCollision() {
    final boss = _activeBoss;
    if (boss == null || !boss.isMounted || _player.isInvulnerable) return;
    final halfW = (boss.size.x * 0.8 + PlayerComponent.playerWidth) / 2;
    final halfH = (boss.size.y * 0.8 + PlayerComponent.playerHeight) / 2;
    final dx = (_player.position.x - boss.position.x).abs();
    final dy = (_player.position.y - boss.position.y).abs();
    if (dx < halfW && dy < halfH) {
      if (livesNotifier.value > 0) {
        livesNotifier.value--;
        _player.revive(_player.position.clone()..y += 40, boost: false);
      } else {
        triggerGameOver();
      }
    }
  }

  void _checkBossBypass() {
    final boss = _activeBoss;
    if (boss == null || !boss.isMounted) return;
    if (_player.position.y < boss.position.y - 120) {
      boss.removeFromParent();
      onBossDefeated();
    }
  }

  // ─── Dokunma — ateş etme ─────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!_bossActive) return;
    _fireProjectile();
  }

  void fireFromPunch() {
    if (!_bossActive) return;
    _fireProjectile();
  }

  void _fireProjectile() {
    world.add(ProjectileComponent(spawnPosition: _player.position.clone()));
  }

  // ─── Skor / coin ─────────────────────────────────────────────────────────────

  void _updateScore() {
    final heightPx = _startY - _player.position.y;
    if (heightPx > 0) {
      final meters = (heightPx / 100).floor();
      if (meters > scoreNotifier.value) scoreNotifier.value = meters;
    }
  }

  void collectCoin(CoinComponent coin) {
    coinNotifier.value += cat.coinValue;
    world.add(CoinSparkle(position: coin.position.clone()));
    coins.remove(coin);
    coin.removeFromParent();
  }

  // ─── Boss sistemi ────────────────────────────────────────────────────────────

  void _checkBossSpawn() {
    if (scoreNotifier.value >= _nextBossAt) _spawnBoss();
  }

  void _spawnBoss() {
    _bossActive = true;
    bossNotifier.value = true;

    // Mevcut boost kartlarını kaldır — bypass engeli.
    for (final p
        in platforms.where((p) => p.type == PlatformType.boost).toList()) {
      _removePlatform(p);
    }

    final bossY = _cameraTopY + size.y * 0.20;
    final boss = BossComponent(
      position: Vector2(size.x / 2, bossY),
      level: _bossLevel,
    );
    _activeBoss = boss;
    world.add(boss);
  }

  void onBossDefeated() {
    _bossActive = false;
    bossNotifier.value = false;
    _activeBoss = null;
    _bossLevel++;
    _nextBossAt += _bossEveryMeters;

    if (_highestPlatformY > _cameraTopY + size.y * 0.5) {
      _highestPlatformY = _cameraTopY + size.y * 0.5;
    }
    _spawnPlatformsUpTo(_cameraTopY - size.y * _spawnLookahead);
  }

  // ─── Kamera ─────────────────────────────────────────────────────────────────

  void _scrollCamera() {
    final desiredTop = _player.position.y - size.y * 0.4;
    if (desiredTop < _cameraTopY) _cameraTopY = desiredTop;
    _applyCameraPosition();
  }

  /// Yeniden kullanılan vektör: her frame yeni Vector2 oluşturmayalım.
  /// (viewfinder.position.setValues dönüşüm matrisini yenilemiyor; setter
  /// ise değeri kendi vektörüne kopyalar — ikisi birlikte tahsissiz çalışır.)
  final Vector2 _camPos = Vector2.zero();

  void _applyCameraPosition() {
    _camPos.setValues(size.x / 2, _cameraTopY + size.y / 2);
    camera.viewfinder.position = _camPos;
  }

  // ─── Platform üretimi ────────────────────────────────────────────────────────

  void _addPlatform(PlatformComponent p) {
    platforms.add(p);
    world.add(p);
  }

  void _removePlatform(PlatformComponent p) {
    platforms.remove(p);
    p.removeFromParent();
  }

  /// Kırılgan platform kaybolduğunda çağrılır.
  void forgetPlatform(PlatformComponent p) => platforms.remove(p);

  void _spawnMorePlatforms() {
    if (_bossActive) return;
    _spawnPlatformsUpTo(_cameraTopY - size.y * _spawnLookahead);
  }

  void _spawnPlatformsUpTo(double targetY) {
    while (_highestPlatformY > targetY) {
      _highestPlatformY -= _platformSpacing;
      _spawnOnePlatform(_highestPlatformY);
    }
  }

  PlatformType _randomType(double worldY) {
    final currentMeters = (_startY - worldY).clamp(0.0, double.infinity) / 100;
    final metersToNextBoss = (_nextBossAt - currentMeters).toDouble();
    if (metersToNextBoss >= 0 &&
        metersToNextBoss * 100 < _boostFreeZoneBeforeBoss) {
      return _rng.nextDouble() < 0.72
          ? PlatformType.normal
          : PlatformType.fragile;
    }

    // Yükseldikçe kırılgan kart oranı biraz artar (en fazla %35).
    final fragile = math.min(0.25 + currentMeters / 1000, 0.35);
    final r = _rng.nextDouble();
    if (r < 0.95 - fragile) return PlatformType.normal;
    if (r < 0.95) return PlatformType.fragile;
    return PlatformType.boost;
  }

  void _spawnOnePlatform(double worldY) {
    final w = 72.0 + _rng.nextDouble() * 48.0;
    final margin = w / 2 + 8.0;
    final maxX = size.x - margin * 2;
    if (maxX <= 0) return;
    final x = margin + _rng.nextDouble() * maxX;
    final type = _randomType(worldY);
    _addPlatform(
      PlatformComponent(position: Vector2(x, worldY), width: w, type: type),
    );

    // Coin'ler: kartın üstünde tek coin ya da küçük bir sıra.
    if (type == PlatformType.fragile) return;
    final r = _rng.nextDouble();
    if (r < 0.30) {
      _addCoin(Vector2(x, worldY - 40));
    } else if (r < 0.40) {
      for (var i = -1; i <= 1; i++) {
        _addCoin(Vector2((x + i * 26).clamp(14, size.x - 14), worldY - 40));
      }
    } else if (r < 0.46) {
      // Kartlar arasında dikey coin dizisi.
      for (var i = 1; i <= 3; i++) {
        _addCoin(Vector2(x, worldY - 40 - i * 34));
      }
    }
  }

  void _addCoin(Vector2 pos) {
    final c = CoinComponent(position: pos, phase: _rng.nextDouble() * 6);
    coins.add(c);
    world.add(c);
  }

  // ─── Temizleme ───────────────────────────────────────────────────────────────

  void _despawnOld() {
    final limit = _cameraTopY + size.y * (1 + _despawnDistance);
    for (var i = platforms.length - 1; i >= 0; i--) {
      final p = platforms[i];
      if (p.position.y > limit) {
        platforms.removeAt(i);
        p.removeFromParent();
      }
    }
    for (var i = coins.length - 1; i >= 0; i--) {
      final c = coins[i];
      if (c.position.y > limit) {
        coins.removeAt(i);
        c.removeFromParent();
      }
    }
  }
}
