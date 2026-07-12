import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:pixel_game/game/components/boss_component.dart';
import 'package:pixel_game/game/components/platform_component.dart';
import 'package:pixel_game/game/components/player_component.dart';
import 'package:pixel_game/game/components/projectile_component.dart';
import 'package:pixel_game/game/systems/input_controller.dart';

/// FingerJumpGame — Flame oyununun kök sınıfı.
class FingerJumpGame extends FlameGame
    with HasCollisionDetection, TapCallbacks {
  // ─── Görünüm ─────────────────────────────────────────────────────────────────

  static const Color skyTop = Color(0xFF0A0E2A);

  @override
  Color backgroundColor() => skyTop;

  // ─── Giriş ───────────────────────────────────────────────────────────────────

  final InputController inputController = InputController();

  // ─── Skor ────────────────────────────────────────────────────────────────────

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  double _startY = 0.0;

  // ─── Platform üretimi sabitleri ──────────────────────────────────────────────

  // Normal zıplama: v²/2g = 650²/1960 ≈ 215 px
  // Spacing = 100px → max jump'ın %46'sı — güvenli marj
  static const double _platformSpacing = 100.0;

  // Lookahead: boost platformu ile 860px yüksekliğe çıkılabilir.
  // size.y * 3.0 ≈ 2400px lookahead; boost sonrası boşluk olmaz.
  static const double _spawnLookahead = 3.0;
  static const double _despawnDistance = 1.5;

  // Boss spawn'a bu kadar platform kala boost üretme (5 platform = 500px)
  static const double _boostFreeZoneBeforeBoss = 500.0;

  // ─── Boss sistemi ────────────────────────────────────────────────────────────

  static const int _bossEveryMeters = 15;
  int _nextBossAt = _bossEveryMeters;
  int _bossLevel = 1;
  bool _bossActive = false;

  /// Aktif boss referansı — her frame whereType aramaktan kaçınmak için.
  BossComponent? _activeBoss;

  // ─── Performans: despawn throttle ──────────────────────────────────────────
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
  final math.Random _rng = math.Random();
  double _highestPlatformY = 0.0;
  double _cameraTopY = 0.0;

  // ─── Yükleme ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _cameraTopY = 0.0;
    _applyCameraPosition();

    // Geniş başlangıç platformu — ilk iniş garantili.
    _highestPlatformY = size.y * 0.85;
    world.add(PlatformComponent(
      position: Vector2(size.x / 2, _highestPlatformY),
      width: 160,
    ));

    _spawnPlatformsUpTo(-size.y);

    _startY = size.y * 0.75;
    _player = PlayerComponent(
      spawnPosition: Vector2(size.x / 2, _startY),
      inputController: inputController,
    );
    await world.add(_player);
  }

  // ─── Oyun döngüsü ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // dt clamp: kasma/takılma durumunda fizik patlamasını önle.
    // 30 FPS altında bile fizik tutarlı kalır.
    final safeDt = dt.clamp(0.0, 1 / 30.0);

    super.update(safeDt);
    if (isGameOver) return;

    _updateScore();
    _checkFallGameOver();
    _scrollCamera(safeDt);
    _spawnMorePlatforms();

    _despawnCounter++;
    if (_despawnCounter >= _despawnEveryFrames) {
      _despawnCounter = 0;
      _despawnOldPlatforms();
    }

    if (_bossActive) {
      _checkBossCollision();
      _checkBossBypass();
    } else {
      _checkBossSpawn();
    }
  }

  // ─── Game Over kontrolleri ───────────────────────────────────────────────────

  void _checkFallGameOver() {
    if (_player.position.y > _cameraTopY + size.y * 1.05) {
      triggerGameOver();
    }
  }

  void _checkBossCollision() {
    final boss = _activeBoss;
    if (boss == null || !boss.isMounted) return;
    final halfW = (boss.size.x + 32) / 2;
    final halfH = (boss.size.y + 44) / 2;
    final dx = (_player.position.x - boss.position.x).abs();
    final dy = (_player.position.y - boss.position.y).abs();
    if (dx < halfW && dy < halfH) {
      triggerGameOver();
    }
  }

  /// Oyuncu boost platformuyla boss'u atlattıysa arena'yı tamamla.
  void _checkBossBypass() {
    final boss = _activeBoss;
    if (boss == null || !boss.isMounted) return;
    if (_player.position.y < boss.position.y - 120) {
      boss.removeFromParent();
      _activeBoss = null;
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

  // ─── Skor ────────────────────────────────────────────────────────────────────

  void _updateScore() {
    final heightPx = _startY - _player.position.y;
    if (heightPx > 0) {
      final meters = (heightPx / 100).floor();
      if (meters > scoreNotifier.value) {
        scoreNotifier.value = meters;
      }
    }
  }

  // ─── Boss sistemi ────────────────────────────────────────────────────────────

  void _checkBossSpawn() {
    if (scoreNotifier.value >= _nextBossAt) {
      _spawnBoss();
    }
  }

  void _spawnBoss() {
    _bossActive = true;

    // Mevcut boost platformlarını kaldır — bypass engeli.
    final boostPlatforms = world.children
        .whereType<PlatformComponent>()
        .where((p) => p.type == PlatformType.boost)
        .toList();
    for (final p in boostPlatforms) {
      p.removeFromParent();
    }

    // Boss ekranın üst %20'sinde, sabit Y — sadece X ekseninde hareket eder.
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
    _activeBoss = null;
    _bossLevel++;
    _nextBossAt += _bossEveryMeters;

    // Boss sırasında duraklamış platform üretimini başlat.
    if (_highestPlatformY > _cameraTopY + size.y * 0.5) {
      _highestPlatformY = _cameraTopY + size.y * 0.5;
    }
    _spawnPlatformsUpTo(_cameraTopY - size.y * _spawnLookahead);
  }

  // ─── Kamera ─────────────────────────────────────────────────────────────────

  void _scrollCamera(double dt) {
    final desiredTop = _player.position.y - size.y * 0.4;
    if (desiredTop < _cameraTopY) {
      _cameraTopY = desiredTop;
    }
    _applyCameraPosition();
  }

  void _applyCameraPosition() {
    camera.viewfinder.position = Vector2(size.x / 2, _cameraTopY + size.y / 2);
  }

  // ─── Platform üretimi ────────────────────────────────────────────────────────

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

  /// Platform türünü rastgele seçer.
  /// Dağılım: %70 normal, %25 kırılgan, %5 güçlendirici.
  /// Boss spawn yakınında (%boostFreeZoneBeforeBoss px) boost üretilmez.
  PlatformType _randomType(double worldY) {
    // Boss spawn eşiğine yakın platformlarda boost üretme.
    final currentMeters = (_startY - worldY).clamp(0.0, double.infinity) / 100;
    final metersToNextBoss = (_nextBossAt - currentMeters).toDouble();
    if (metersToNextBoss >= 0 &&
        metersToNextBoss * 100 < _boostFreeZoneBeforeBoss) {
      // Boss yakınında → sadece normal veya kırılgan
      return _rng.nextDouble() < 0.72 ? PlatformType.normal : PlatformType.fragile;
    }

    final r = _rng.nextDouble();
    if (r < 0.70) return PlatformType.normal;
    if (r < 0.95) return PlatformType.fragile;
    return PlatformType.boost;
  }

  void _spawnOnePlatform(double worldY) {
    final w = 70.0 + _rng.nextDouble() * 50.0;
    final margin = w / 2 + 8.0;
    final maxX = size.x - margin * 2;
    // Negatif maxX olasılığını önle (çok geniş platform dar ekranda)
    if (maxX <= 0) return;
    final x = margin + _rng.nextDouble() * maxX;
    world.add(PlatformComponent(
      position: Vector2(x, worldY),
      width: w,
      type: _randomType(worldY),
    ));
  }

  // ─── Platform temizleme ──────────────────────────────────────────────────────

  void _despawnOldPlatforms() {
    final limit = _cameraTopY + size.y * (1 + _despawnDistance);
    final toRemove = world.children
        .whereType<PlatformComponent>()
        .where((p) => p.position.y > limit)
        .toList();
    for (final p in toRemove) {
      p.removeFromParent();
    }
  }
}
