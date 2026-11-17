import 'package:flutter/foundation.dart';
import 'package:pixel_game/game/accessories.dart';
import 'package:pixel_game/game/cats.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı oyuncu verisi: rekor, toplam coin, seçili kedi, dükkân eşyaları,
/// müzik ayarı.
///
/// [current] uygulama genelinde paylaşılan güncel kopyadır; menülerdeki kedi
/// görselleri takılı aksesuarı buradan dinler.
class SaveData {
  static const _kHigh = 'highScore';
  static const _kCoins = 'coins';
  static const _kCat = 'selectedCat';
  static const _kOwned = 'ownedAccessories';
  static const _kEquipped = 'equippedAccessory';
  static const _kMusic = 'music';

  final int highScore;
  final int coins;
  final CatBreed cat;
  final Set<Accessory> owned;
  final Accessory? equipped;
  final bool music;

  const SaveData({
    required this.highScore,
    required this.coins,
    required this.cat,
    this.owned = const {},
    this.equipped,
    this.music = true,
  });

  static final ValueNotifier<SaveData> current = ValueNotifier(
    const SaveData(highScore: 0, coins: 0, cat: CatBreed.sarman),
  );

  static Future<SaveData> load() async {
    final p = await SharedPreferences.getInstance();
    final owned = <Accessory>{
      for (final n in p.getStringList(_kOwned) ?? const <String>[])
        ?AccessoryInfo.fromName(n),
    };
    var equipped = AccessoryInfo.fromName(p.getString(_kEquipped));
    if (equipped != null && !owned.contains(equipped)) equipped = null;
    final data = SaveData(
      highScore: p.getInt(_kHigh) ?? 0,
      coins: p.getInt(_kCoins) ?? 0,
      cat: CatInfo.fromName(p.getString(_kCat)),
      owned: owned,
      equipped: equipped,
      music: p.getBool(_kMusic) ?? true,
    );
    current.value = data;
    return data;
  }

  static Future<void> setCat(CatBreed cat) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCat, cat.name);
    await load();
  }

  static Future<void> setMusic(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMusic, on);
    await load();
  }

  /// Coin yetiyorsa aksesuarı satın alır ve hemen takar.
  static Future<bool> buy(Accessory a) async {
    final p = await SharedPreferences.getInstance();
    final coins = p.getInt(_kCoins) ?? 0;
    final price = AccessoryInfo.of(a).price;
    final owned = p.getStringList(_kOwned) ?? <String>[];
    if (owned.contains(a.name)) return true;
    if (coins < price) return false;
    await p.setInt(_kCoins, coins - price);
    await p.setStringList(_kOwned, [...owned, a.name]);
    await p.setString(_kEquipped, a.name);
    await load();
    return true;
  }

  /// Aksesuarı takar; null → çıkarır.
  static Future<void> equip(Accessory? a) async {
    final p = await SharedPreferences.getInstance();
    if (a == null) {
      await p.remove(_kEquipped);
    } else {
      await p.setString(_kEquipped, a.name);
    }
    await load();
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
