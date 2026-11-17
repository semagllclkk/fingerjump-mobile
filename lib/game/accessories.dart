import 'dart:ui' as ui;

import 'package:pixel_game/game/art/pixel_art.dart';

/// Dükkândan coin ile alınan, kedinin kafasına takılan aksesuarlar.
enum Accessory { bow, crown, glasses, propeller, witch, wizard }

class AccessoryInfo {
  final Accessory id;
  final String name;
  final String text;
  final int price;

  /// Izgaranın kedi sprite'ına göre dikey konumu (kedi pikseli). Negatif →
  /// kafanın üstüne taşar. Tüm ızgaralar 16 sütun genişliğinde, x = 0.
  final int dy;

  /// Kareler (pervane için 2, diğerleri 1).
  final List<List<String>> frames;
  final Map<String, ui.Color> palette;

  const AccessoryInfo({
    required this.id,
    required this.name,
    required this.text,
    required this.price,
    required this.dy,
    required this.frames,
    required this.palette,
  });

  static AccessoryInfo of(Accessory a) => all[a.index];

  static Accessory? fromName(String? name) {
    for (final a in Accessory.values) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// Bir aksesuarın kafanın ne kadar üstüne taştığı (en fazla).
  static const int maxRise = 8;

  static const List<AccessoryInfo> all = [
    AccessoryInfo(
      id: Accessory.bow,
      name: 'Pembe Fiyonk',
      text: 'Kulağın yanında kocaman bir fiyonk.',
      price: 15,
      dy: -1,
      frames: [
        [
          '..........oo.oo.',
          '.........oPPoPPo',
          '.........oPpKpPo',
          '.........oPPoPPo',
          '..........oo.oo.',
        ],
      ],
      palette: {
        'o': ui.Color(0xFF9A2A5A),
        'P': ui.Color(0xFFF27AA4),
        'p': ui.Color(0xFFFFC2D8),
        'K': ui.Color(0xFFC94A7E),
      },
    ),
    AccessoryInfo(
      id: Accessory.crown,
      name: 'Çiçekli Taç',
      text: 'Çiftlikten toplanmış papatyalar, menekşeler.',
      price: 25,
      dy: 1,
      frames: [
        ['..pP.yY..lL.pP..', '..PpGYyGGLlGPp..', '..gGgGgGgGgGgG..'],
      ],
      palette: {
        'P': ui.Color(0xFFF27AA4),
        'p': ui.Color(0xFFFFC2D8),
        'Y': ui.Color(0xFFFFD35A),
        'y': ui.Color(0xFFFFF2B0),
        'L': ui.Color(0xFFB48AE8),
        'l': ui.Color(0xFFE2CCFF),
        'G': ui.Color(0xFF6DB04A),
        'g': ui.Color(0xFF4C8A3C),
      },
    ),
    AccessoryInfo(
      id: Accessory.glasses,
      name: 'Şaka Gözlüğü',
      text: 'Kalın çerçeve, koca burun, bıyık. Kimse tanımaz!',
      price: 30,
      dy: 3,
      frames: [
        [
          '..ooo......ooo..',
          '...oooo..oooo...',
          '...o..oooo..o...',
          '...o..onno..o...',
          '...ooonnnnooo...',
          '....mmnNNnmm....',
          '..mmmm....mmmm..',
        ],
      ],
      palette: {
        'o': ui.Color(0xFF1A1A1A),
        'n': ui.Color(0xFFF2A0A0),
        'N': ui.Color(0xFFD9707A),
        'm': ui.Color(0xFF3A2418),
      },
    ),
    AccessoryInfo(
      id: Accessory.propeller,
      name: 'Pervaneli Şapka',
      text: 'Rengârenk, pervanesi zıpladıkça döner.',
      price: 40,
      dy: -4,
      frames: [
        [
          '..PPPPPhhQQQQQ..',
          '.......kk.......',
          '....oooooooo....',
          '...oRRYYGGBBo...',
          '..oRRRYYGGBBBo..',
          '.oWWWWWWWWWWWWo.',
          '..oooooooooooo..',
        ],
        [
          '.....PPhhQQ.....',
          '.......kk.......',
          '....oooooooo....',
          '...oRRYYGGBBo...',
          '..oRRRYYGGBBBo..',
          '.oWWWWWWWWWWWWo.',
          '..oooooooooooo..',
        ],
      ],
      palette: {
        'P': ui.Color(0xFFE0352B),
        'Q': ui.Color(0xFF3D8CE0),
        'h': ui.Color(0xFFFFD35A),
        'k': ui.Color(0xFF4A3A2A),
        'o': ui.Color(0xFF3A2A3A),
        'R': ui.Color(0xFFE0352B),
        'Y': ui.Color(0xFFFFD35A),
        'G': ui.Color(0xFF6DB04A),
        'B': ui.Color(0xFF3D8CE0),
        'W': ui.Color(0xFFFFF8E4),
      },
    ),
    AccessoryInfo(
      id: Accessory.witch,
      name: 'Cadı Şapkası',
      text: 'Eğri uçlu, mor kurdeleli, altın tokalı.',
      price: 60,
      dy: -8,
      frames: [
        [
          '..oo............',
          '..oKKo..........',
          '...oKKo.........',
          '....oKKo........',
          '.....oKKo.......',
          '.....oKKKo......',
          '....oKKKKKo.....',
          '....oKKKKKKo....',
          '...oPPPGGPPo....',
          '...oKKKKKKKKo...',
          'oKKKKKKKKKKKKKKo',
          '.oooooooooooooo.',
        ],
      ],
      palette: {
        'o': ui.Color(0xFF120C1C),
        'K': ui.Color(0xFF2E2440),
        'P': ui.Color(0xFF8A4AD0),
        'G': ui.Color(0xFFFFD35A),
      },
    ),
    AccessoryInfo(
      id: Accessory.wizard,
      name: 'Büyücü Şapkası',
      text: 'Yıldızlı, sivri, gizemli. Biraz da büyük.',
      price: 75,
      dy: -8,
      frames: [
        [
          '.........oo.....',
          '........oBBo....',
          '.......oBBo.....',
          '.......oBSBo....',
          '......oBBBBo....',
          '......oBBBSBo...',
          '.....oBSBBBBo...',
          '.....oBBBBBBBo..',
          '....oBBBSBBBBo..',
          '.oyyyyyyyyyyyyo.',
          'obbbbbbbbbbbbbbo',
          '.oooooooooooooo.',
        ],
      ],
      palette: {
        'o': ui.Color(0xFF1A1F4A),
        'B': ui.Color(0xFF3B4BB8),
        'b': ui.Color(0xFF2C3790),
        'S': ui.Color(0xFFFFD35A),
        'y': ui.Color(0xFFFFD35A),
      },
    ),
  ];
}

/// Aksesuar resimleri — (aksesuar, kare, ayna) başına bir kez çizilir.
class AccessoryArt {
  static final Map<int, ui.Image> _cache = {};

  static int frameCount(Accessory a) => AccessoryInfo.of(a).frames.length;

  static ui.Image image(Accessory a, {int frame = 0, bool flipX = false}) {
    final info = AccessoryInfo.of(a);
    final f = frame % info.frames.length;
    final key = a.index * 10 + f * 2 + (flipX ? 1 : 0);
    return _cache.putIfAbsent(
      key,
      () => gridToImage(info.frames[f], info.palette, flipX: flipX),
    );
  }

  /// Kedinin [catRect] içine çizildiği yere aksesuarı oturtur.
  static void draw(
    ui.Canvas canvas,
    Accessory a,
    ui.Rect catRect, {
    int frame = 0,
    bool flipX = false,
    ui.Paint? paint,
  }) {
    final img = image(a, frame: frame, flipX: flipX);
    final ux = catRect.width / 16, uy = catRect.height / 16;
    final dy = AccessoryInfo.of(a).dy;
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(
        catRect.left,
        catRect.top + dy * uy,
        img.width * ux,
        img.height * uy,
      ),
      paint ?? pixelPaint,
    );
  }
}
