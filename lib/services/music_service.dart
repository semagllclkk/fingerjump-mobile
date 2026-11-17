import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:pixel_game/services/save_data.dart';

/// Arka plan müziği — "cozy loop" (tool/make_music.py ile üretildi).
///
/// Tek bir AudioPlayer döngüde çalar; uygulama arka plana geçince duraklar,
/// öne gelince (müzik açıksa) devam eder. Açık/kapalı ayarı kalıcıdır.
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  static const double _volume = 0.45;

  final AudioPlayer _player = AudioPlayer(playerId: 'bgm');
  bool _prepared = false;
  bool _inForeground = true;

  bool get enabled => SaveData.current.value.music;

  Future<void> _prepare() async {
    if (_prepared) return;
    _prepared = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume);
    await _player.setSource(AssetSource('audio/cozy_loop.ogg'));
  }

  /// Ayara göre çalmayı başlatır / durdurur.
  Future<void> sync() async {
    try {
      if (enabled && _inForeground) {
        await _prepare();
        if (_player.state != PlayerState.playing) await _player.resume();
      } else if (_player.state == PlayerState.playing) {
        await _player.pause();
      }
    } catch (e) {
      // Web'de kullanıcı etkileşimi olmadan otomatik oynatma engellenebilir.
      debugPrint('[MusicService] $e');
    }
  }

  Future<void> toggle() async {
    await SaveData.setMusic(!enabled);
    await sync();
  }

  void setForeground(bool fg) {
    _inForeground = fg;
    sync();
  }
}
