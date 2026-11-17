import 'package:pixel_game/game/cats.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı oyuncu verisi: rekor, toplam coin, seçili kedi.
class SaveData {
  static const _kHigh = 'highScore';
  static const _kCoins = 'coins';
  static const _kCat = 'selectedCat';

  final int highScore;
  final int coins;
  final CatBreed cat;

  const SaveData({
    required this.highScore,
    required this.coins,
    required this.cat,
  });

  static Future<SaveData> load() async {
    final p = await SharedPreferences.getInstance();
    return SaveData(
      highScore: p.getInt(_kHigh) ?? 0,
      coins: p.getInt(_kCoins) ?? 0,
      cat: CatInfo.fromName(p.getString(_kCat)),
    );
  }

  static Future<void> setCat(CatBreed cat) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCat, cat.name);
  }

  /// Bir oyunun sonucunu kaydeder, güncel veriyi döner.
  static Future<SaveData> recordRun({
    required int score,
    required int coins,
  }) async {
    final p = await SharedPreferences.getInstance();
    final high = p.getInt(_kHigh) ?? 0;
    if (score > high) await p.setInt(_kHigh, score);
    final total = (p.getInt(_kCoins) ?? 0) + coins;
    await p.setInt(_kCoins, total);
    return load();
  }
}
