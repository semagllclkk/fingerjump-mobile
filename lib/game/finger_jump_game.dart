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
///
/// Faz 1 : Boş dünya, arka plan.
/// Faz 2 : Oyuncu, zıplama, yerçekimi.
/// Faz 3 : Platform üretimi, kamera takibi.
/// Faz 4+7: Skor, jiroskop.
/// Faz 5+6: Platform türleri, boss sistemi, mermi, dokunma.
///
/// [TapCallbacks] — dokunma algılama. Herhangi bir yere dokunmak
/// oyuncunun pozisyonundan yukarı bir mermi fırlatır.
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

  // Maksimum zıplama yüksekliği: v²/2g = 650²/1960 ≈ 215 px
  // Güvenli aralık = %56 ≈ 120 px  (önceki 150 bazı anlarda ulaşılamıyordu)
  static const double _platformSpacing = 120.0;
  static const double _spawnLookahead = 2.0;
  static const double _despawnDistance = 1.5;

  // ─── Boss sistemi ────────────────────────────────────────────────────────────

  /// Kaç metrede bir boss çıksın.
  static const int _bossEveryMeters = 15;

  /// Sonraki boss hangi metrede çıkacak.
  int _nextBossAt = _bossEveryMeters;

  /// Kaçıncı boss — zorluk seviyesi buradan hesaplanır.
  int _bossLevel = 1;

  /// Boss aktif mi? Aktifken kamera kilitlenir, yeni platform üretilmez.
  bool _bossActive = false;

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
    super.update(dt);

    _updateScore();

    if (!_bossActive) {
      _scrollCamera(dt);
      _spawnMorePlatforms();
      _despawnOldPlatforms();
      _checkBossSpawn();
    }
  }

  // ─── Dokunma — ateş etme ─────────────────────────────────────────────────────

  /// Gyro modunda ekrana dokunma = ateş.
  /// Kamera modunda yumruk = ateş (CameraHandService → inputController.onPunch → burada).
  @override
  void onTapDown(TapDownEvent event) {
    if (!_bossActive) return;
    _fireProjectile();
  }

  /// InputController.onPunch callback'i bu metoda bağlanır.
  /// Gyro veya kamera modundan bağımsız çalışır.
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

  /// Her frame'de skor eşiğine ulaşılıp ulaşılmadığını kontrol eder.
  void _checkBossSpawn() {
    if (scoreNotifier.value >= _nextBossAt) {
      _spawnBoss();
    }
  }

  /// Boss arenasını hazırlar ve boss'u dünyaya ekler.
  void _spawnBoss() {
    _bossActive = true;

    // Oyuncu nerede? Buradan YUKARIYA doğru arena kur.
    // _cameraTopY yerine player pozisyonunu baz alıyoruz —
    // böylece kamera kilitlenme anı fark etmez.
    final arenaTop = _player.position.y - size.y * 0.55;

    // Arena: 3 platform oyuncunun üstüne ekle.
    final platformRelYs = [0.0, size.y * 0.18, size.y * 0.36];
    final platformXs = [size.x * 0.22, size.x * 0.62, size.x * 0.40];
    for (var i = 0; i < platformRelYs.length; i++) {
      world.add(PlatformComponent(
        position: Vector2(platformXs[i], arenaTop + platformRelYs[i]),
        width: 110,
        type: PlatformType.normal,
      ));
    }

    // Boss — arenasının en üstüne (oyuncunun 55% üstü).
    world.add(BossComponent(
      position: Vector2(size.x / 2, arenaTop - size.y * 0.1),
      level: _bossLevel,
    ));
  }

  /// Boss yenildiğinde çağrılır (BossComponent tarafından).
  void onBossDefeated() {
    _bossActive = false;
    _bossLevel++;
    _nextBossAt += _bossEveryMeters;
  }

  // ─── Kamera ─────────────────────────────────────────────────────────────────

  void _scrollCamera(double dt) {
    // Yukarı: oyuncu kameranın üst %40'ına yaklaşınca hemen takip et.
    final desiredTop = _player.position.y - size.y * 0.4;
    if (desiredTop < _cameraTopY) {
      _cameraTopY = desiredTop;
    }

    // Aşağı güvenlik: oyuncu kameranın alt sınırına yaklaşırsa
    // kamera da yavaşça aşağı kayar (boost sonrası kamera kopması önlenir).
    final cameraBottom = _cameraTopY + size.y;
    final playerPad = size.y * 0.15; // oyuncunun altında 15% boşluk bırak
    if (_player.position.y > cameraBottom - playerPad) {
      final drift = (_player.position.y - (cameraBottom - playerPad)) * 0.08;
      _cameraTopY += drift.clamp(0.0, size.y * 0.1);
    }

    _applyCameraPosition();
  }

  void _applyCameraPosition() {
    camera.viewfinder.position = Vector2(size.x / 2, _cameraTopY + size.y / 2);
  }

  // ─── Platform üretimi ────────────────────────────────────────────────────────

  void _spawnMorePlatforms() {
    _spawnPlatformsUpTo(_cameraTopY - size.y * _spawnLookahead);
  }

  void _spawnPlatformsUpTo(double targetY) {
    while (_highestPlatformY > targetY) {
      _highestPlatformY -= _platformSpacing;
      _spawnOnePlatform(_highestPlatformY);
    }
  }

  /// Platform türünü rastgele seçer.
  /// Dağılım: %65 normal, %25 kırılgan, %10 güçlendirici.
  PlatformType _randomType() {
    final r = _rng.nextDouble();
    if (r < 0.65) return PlatformType.normal;
    if (r < 0.90) return PlatformType.fragile;
    return PlatformType.boost;
  }

  void _spawnOnePlatform(double worldY) {
    final w = 70.0 + _rng.nextDouble() * 50.0;
    final margin = w / 2 + 8.0;
    final x = margin + _rng.nextDouble() * (size.x - margin * 2);
    world.add(PlatformComponent(
      position: Vector2(x, worldY),
      width: w,
      type: _randomType(),
    ));
  }

  // ─── Platform temizleme ──────────────────────────────────────────────────────

  void _despawnOldPlatforms() {
    final limit = _cameraTopY + size.y * (1 + _despawnDistance);
    final toRemove = world.children
        .whereType<PlatformComponent>()
        .where((p) => p.position.y > limit)
        .toList();
    for (final p in toRemove) { p.removeFromParent(); }
  }
}
