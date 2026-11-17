import 'dart:ui' as ui;

import 'package:pixel_game/game/art/pixel_art.dart';

/// Oynanabilir kedi türleri.
///
/// Her tür aynı 16×16 piksel iskeleti farklı bir paletle boyar ve oyuna
/// küçük bir yetenek (perk) getirir.
enum CatBreed { sarman, tekir, siyah, van, calico }

/// Bir kedi türünün görünümü + oynanış özellikleri.
class CatInfo {
  final CatBreed breed;
  final String name;
  final String perkTitle;
  final String perkText;
  final Map<String, ui.Color> palette;

  /// Yatay hız çarpanı.
  final double speedMult;

  /// Zıplama hızı çarpanı.
  final double jumpMult;

  /// Her coin'in değeri.
  final int coinValue;

  /// Coin'leri kendine çekme yarıçapı (px). 0 → mıknatıs yok.
  final double magnetRadius;

  /// Düşüşten / boss çarpmasından bir kez kurtulma hakkı.
  final int extraLives;

  const CatInfo({
    required this.breed,
    required this.name,
    required this.perkTitle,
    required this.perkText,
    required this.palette,
    this.speedMult = 1.0,
    this.jumpMult = 1.0,
    this.coinValue = 1,
    this.magnetRadius = 0.0,
    this.extraLives = 0,
  });

  static CatInfo of(CatBreed b) => all[b.index];

  static CatBreed fromName(String? name) => CatBreed.values.firstWhere(
    (b) => b.name == name,
    orElse: () => CatBreed.sarman,
  );

  static const List<CatInfo> all = [
    CatInfo(
      breed: CatBreed.sarman,
      name: 'Sarman',
      perkTitle: 'Çevik Pati',
      perkText: '%15 daha hızlı sağa-sola koşar.',
      speedMult: 1.15,
      palette: {
        'o': ui.Color(0xFF5A2E16),
        'B': ui.Color(0xFFF0A04B),
        'b': ui.Color(0xFFC8742E),
        'S': ui.Color(0xFFC06A24),
        'C': ui.Color(0xFFFDE8C4),
        'I': ui.Color(0xFFF5A3B5),
        'N': ui.Color(0xFFF07A90),
        'W': ui.Color(0xFFFFFFFF),
        'E': ui.Color(0xFF3F8F3A),
        'e': ui.Color(0xFF3F8F3A),
      },
    ),
    CatInfo(
      breed: CatBreed.tekir,
      name: 'Tekir',
      perkTitle: 'Mıknatıs Bıyık',
      perkText: 'Yakındaki coin\'ler bıyıklarına doğru uçar.',
      magnetRadius: 110,
      palette: {
        'o': ui.Color(0xFF2C2A2E),
        'B': ui.Color(0xFFA29E94),
        'b': ui.Color(0xFF77736B),
        'S': ui.Color(0xFF4A4744),
        'C': ui.Color(0xFFEBE6DA),
        'I': ui.Color(0xFFE8A0AE),
        'N': ui.Color(0xFFD9788C),
        'W': ui.Color(0xFFFFFFFF),
        'E': ui.Color(0xFFB9A52C),
        'e': ui.Color(0xFFB9A52C),
      },
    ),
    CatInfo(
      breed: CatBreed.siyah,
      name: 'Kara',
      perkTitle: 'Dokuzuncu Can',
      perkText: 'Bir kez düşüşten ya da boss\'tan kurtulur.',
      extraLives: 1,
      palette: {
        'o': ui.Color(0xFF0B0A10),
        'B': ui.Color(0xFF2E2C38),
        'b': ui.Color(0xFF1F1D27),
        'S': ui.Color(0xFF3C3A48),
        'C': ui.Color(0xFF3C3A48),
        'I': ui.Color(0xFF7A4658),
        'N': ui.Color(0xFFC86A86),
        'W': ui.Color(0xFFFFFFFF),
        'E': ui.Color(0xFFF2CF3A),
        'e': ui.Color(0xFFF2CF3A),
      },
    ),
    CatInfo(
      breed: CatBreed.van,
      name: 'Pamuk',
      perkTitle: 'Van Zıplayışı',
      perkText: 'Bembeyaz Van kedisi: %8 daha yükseğe zıplar.',
      jumpMult: 1.08,
      palette: {
        'o': ui.Color(0xFF6A6470),
        'B': ui.Color(0xFFF8F6F0),
        'b': ui.Color(0xFFD9D4C8),
        'S': ui.Color(0xFFECE6D8),
        'C': ui.Color(0xFFFFFFFF),
        'I': ui.Color(0xFFF3A6B8),
        'N': ui.Color(0xFFF08AA0),
        'W': ui.Color(0xFFFFFFFF),
        'E': ui.Color(0xFF3D8CE0), // bir göz mavi
        'e': ui.Color(0xFFE0AA2A), // diğeri kehribar
      },
    ),
    CatInfo(
      breed: CatBreed.calico,
      name: 'Üç Renkli',
      perkTitle: 'Uğurlu Pati',
      perkText: 'Her coin 2 sayılır.',
      coinValue: 2,
      palette: {
        'o': ui.Color(0xFF3A2A24),
        'B': ui.Color(0xFFFBF6EC),
        'b': ui.Color(0xFF2E2A30),
        'S': ui.Color(0xFFE8903A),
        'C': ui.Color(0xFFFFFFFF),
        'I': ui.Color(0xFFF3A6B8),
        'N': ui.Color(0xFFF08AA0),
        'W': ui.Color(0xFFFFFFFF),
        'E': ui.Color(0xFF4B9A48),
        'e': ui.Color(0xFF4B9A48),
      },
    ),
  ];
}

// ─── Sprite ızgaraları ────────────────────────────────────────────────────────
//
// o: kontur   B: kürk   b: gölge/leke   S: çizgi/leke   C: göğüs/ağız
// I: kulak içi   N: burun   W: göz parıltısı   E/e: sol/sağ göz

const List<String> _head = [
  '...o........o...',
  '..oIo......oIo..',
  '..oBIooooooIBo..',
  '..oBBBBSSBBBBo..',
  '.oBBBBBSSBBBBBo.',
  '.oBBWEBBBBWeBBo.',
  '.oBBEEBBBBeeBBo.',
  '.oBBBBCNNCBBBBo.',
  '.oBBBCoCCoCBBBo.',
  'oSobbBBBBBBbbo..',
  'oBooooBCCBooo...',
  'oBoBBBCCCCBBBo..',
  '.oBBBSCCCCSBBo..',
];

/// Yükselirken: patiler aşağı uzanmış.
const List<String> _legsRise = [
  '..oBBBCCCCBBBo..',
  '..oBCCobboCCBo..',
  '...oooo..oooo...',
];

/// Düşerken: patiler yana açılmış (paraşüt kedi).
const List<String> _legsFall = [
  '.ooBBBCCCCBBBoo.',
  '.oCCoBBBBBBoCCo.',
  '..oo.oooooo.oo..',
];

/// Göz kırpma: göz satırları kapalı.
List<String> _blink(List<String> rows) {
  final out = List<String>.of(rows);
  out[5] = '.oBBBBBBBBBBBBo.';
  out[6] = '.oBBooBBBBooBBo.';
  return out;
}

/// Kedi sprite kareleri: [0] yükselme, [1] düşme, [2] göz kırpma.
/// Sağa bakan + sola bakan (aynalı) versiyonlar ayrı önbelleklenir.
class CatSprites {
  static const int size = 16;
  static final Map<CatBreed, List<ui.Image>> _cache = {};

  static List<ui.Image> framesFor(CatBreed breed) {
    return _cache.putIfAbsent(breed, () {
      final pal = CatInfo.of(breed).palette;
      final rise = [..._head, ..._legsRise];
      final fall = [..._head, ..._legsFall];
      final blink = _blink(rise);
      return [
        gridToImage(rise, pal),
        gridToImage(fall, pal),
        gridToImage(blink, pal),
        gridToImage(rise, pal, flipX: true),
        gridToImage(fall, pal, flipX: true),
        gridToImage(blink, pal, flipX: true),
      ];
    });
  }
}
