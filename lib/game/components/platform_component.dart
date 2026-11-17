import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:pixel_game/game/art/pixel_art.dart';
import 'package:pixel_game/game/art/vines.dart';
import 'package:pixel_game/game/finger_jump_game.dart';

/// Platform türleri.
enum PlatformType {
  /// Pembe çiçekli sarmaşıklı kart — sınırsız kullanım.
  normal,

  /// Kurumuş sarmaşık, çatlak parşömen — 1 zıplamadan sonra kaybolur.
  fragile,

  /// Altın çiçekli kart — 2× yüksekliğe fırlatır.
  boost,
}

/// Oyuncunun üstüne zıplayabileceği "beceri kartı".
///
/// Görünüm, portfolyodaki çiftlik sahnesinin Sandık · Beceriler penceresindeki
/// kartlardan (src/farm/game/vines.js) alındı: parşömen zemin, çevresinde
/// köşelerde çiçek, kenarlarda yapraklı dal ve tomurcuk olan piksel sarmaşık.
///
/// Performans:
///   * Hitbox yok — iniş, oyuncunun sweep kontrolüyle yapılır. Flame'in
///     çarpışma sistemi 30+ platformu her frame taramaz.
///   * Kart bir kez `ui.Image`'a çizilir ve (tür, genişlik) anahtarıyla
///     önbelleğe alınır. render() yalnızca tek bir `drawImage` çağrısıdır.
class PlatformComponent extends PositionComponent
    with HasGameReference<FingerJumpGame> {
  // ─── Sabitler ───────────────────────────────────────────────────────────────

  /// Piksel ölçeği (portfolyodaki gibi 2×).
  static const int pixel = 2;

  /// Kartın piksel satır sayısı: 7 üst + 1 orta + 7 alt.
  static const int _rows = 15;

  /// Üstteki çiçeklerin, basılabilir yüzeyin ne kadar üstüne taştığı.
  /// Dalın gövdesi 3. satırdadır → yüzey = kart üstü + 3 piksel.
  static const double _overhang = 3.0 * pixel;

  /// Fiziksel platform yüksekliği (çarpışma için).
  static const double platformHeight = _rows * pixel - _overhang;

  /// Oyun içinde kullanılan genişlik kademeleri (piksel sütun).
  static const List<int> widthSteps = [36, 42, 48, 54, 60];

  static const double defaultWidth = 48.0 * pixel;

  // ─── Durum ──────────────────────────────────────────────────────────────────

  final PlatformType type;

  double _removalCountdown = 0.0;
  bool _scheduledForRemoval = false;
  bool get isBreaking => _scheduledForRemoval;

  late final ui.Image _image;
  final ui.Paint _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;

  // ─── Constructor ─────────────────────────────────────────────────────────────

  PlatformComponent({
    required Vector2 position,
    double width = defaultWidth,
    this.type = PlatformType.normal,
  }) : super(
         position: position,
         size: Vector2(_snapWidth(width) * pixel.toDouble(), platformHeight),
         anchor: Anchor.center,
       ) {
    _image = VineCardArt.card(type, _snapWidth(width));
  }

  /// Genişliği en yakın kademeye yuvarlar (önbellek boyutunu sınırlı tutar).
  static int _snapWidth(double widthPx) {
    final cols = (widthPx / pixel).round();
    var best = widthSteps.first;
    for (final s in widthSteps) {
      if ((s - cols).abs() < (best - cols).abs()) best = s;
    }
    if (cols > widthSteps.last) return (cols ~/ 2) * 2;
    return best;
  }

  // ─── Güncelleme ──────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (!_scheduledForRemoval) return;
    _removalCountdown -= dt;
    final ratio = (_removalCountdown / 0.3).clamp(0.0, 1.0);
    _paint.color = ui.Color.fromARGB((ratio * 255).toInt(), 255, 255, 255);
    // Kırılırken hafif aşağı düşsün.
    position.y += 60 * dt;
    if (_removalCountdown <= 0) removeFromParent();
  }

  @override
  void onRemove() {
    game.forgetPlatform(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    canvas.drawImage(_image, const ui.Offset(0, -_overhang), _paint);
  }

  // ─── Dışarıdan çağrılan ──────────────────────────────────────────────────────

  void scheduleRemoval() {
    if (_scheduledForRemoval) return;
    _scheduledForRemoval = true;
    _removalCountdown = 0.30;
  }
}

/// Beceri kartı çizimi — portfolyodaki `vines.js` 9 dilimli çerçevesinin
/// Dart karşılığı.
class VineCardArt {
  static const int _c = vineCornerSize;

  /// Dal gövdesinin bulunduğu satır (vineEdge'de `VVVV...`).
  static const int _stemRow = 3;

  static const Map<PlatformType, Map<String, ui.Color>> _palettes = {
    PlatformType.normal: {
      'P': ui.Color(0xFFF27AA4),
      'p': ui.Color(0xFFC94A7E),
      'Y': ui.Color(0xFFFFD35A),
      'W': ui.Color(0xFFFFE3EE),
      'V': ui.Color(0xFF4F8A3A),
      'G': ui.Color(0xFF86C45E),
      'g': ui.Color(0xFF4C8A3C),
      // zemin
      'paper': ui.Color(0xFFF6DBA6),
      'shade': ui.Color(0xFFE2B97A),
      'line': ui.Color(0xFFB98A52),
    },
    PlatformType.fragile: {
      'P': ui.Color(0xFFD9A066),
      'p': ui.Color(0xFF9C6232),
      'Y': ui.Color(0xFFC9A04A),
      'W': ui.Color(0xFFF0D2A8),
      'V': ui.Color(0xFF8A6A3A),
      'G': ui.Color(0xFFB39250),
      'g': ui.Color(0xFF7D5F32),
      'paper': ui.Color(0xFFE6CC9A),
      'shade': ui.Color(0xFFCDA770),
      'line': ui.Color(0xFF9C7444),
    },
    PlatformType.boost: {
      'P': ui.Color(0xFFFFD35A),
      'p': ui.Color(0xFFE09A1A),
      'Y': ui.Color(0xFFFFFFFF),
      'W': ui.Color(0xFFFFF6C8),
      'V': ui.Color(0xFF3F8A4A),
      'G': ui.Color(0xFF8BD06A),
      'g': ui.Color(0xFF3E8A44),
      'paper': ui.Color(0xFFFFF1B8),
      'shade': ui.Color(0xFFF2CF6A),
      'line': ui.Color(0xFFD9A030),
    },
  };

  static final Map<int, ui.Image> _cache = {};

  static ui.Image card(PlatformType type, int cols) {
    final key = type.index * 1000 + cols;
    return _cache.putIfAbsent(key, () => _draw(type, cols));
  }

  /// Kenar deseni; dal gövdesi satırındaki boşluk (gövde aslında bir alt
  /// satıra kıvrılır, o satırı çizmiyoruz) kapatılır.
  static String _edgeAt(int y, int i) {
    final ch = vineEdge[y][i % vineEdge[0].length];
    return (y == _stemRow && ch == '.') ? 'V' : ch;
  }

  static ui.Image _draw(PlatformType type, int cols) {
    const s = PlatformComponent.pixel;
    const rows = PlatformComponent._rows;
    final pal = _palettes[type]!;

    // 1) Sarmaşık ızgarası
    final grid = List.generate(rows, (_) => List.filled(cols, '.'));
    void put(int x, int y, String ch) {
      if (ch == '.' || x < 0 || y < 0 || x >= cols || y >= rows) return;
      grid[y][x] = ch;
    }

    for (var y = 0; y < _c; y++) {
      for (var x = 0; x < _c; x++) {
        final ch = vineCorner[y][x];
        put(x, y, ch);
        put(cols - 1 - x, y, ch);
        put(x, rows - 1 - y, ch);
        put(cols - 1 - x, rows - 1 - y, ch);
      }
      // Kenarların yalnızca dışa bakan yarısı (dal gövdesi + dışarı taşan
      // yaprak/tomurcuk) çizilir. Kart platform olarak ince olduğundan içe
      // sarkan yapraklar beceri adının üstüne binerdi.
      if (y > _stemRow) continue;

      // üst + alt kenar ("round" tekrarı yerine düz tekrar)
      for (var x = _c; x < cols - _c; x++) {
        final ch = _edgeAt(y, x - _c);
        put(x, y, ch);
        put(x, rows - 1 - y, ch); // alt kenar (ayna)
      }
      // sol + sağ kenar (devrik)
      for (var yy = _c; yy < rows - _c; yy++) {
        final ch = _edgeAt(y, yy - _c);
        put(y, yy, ch);
        put(cols - 1 - y, yy, ch);
      }
    }

    return paintToImage(cols * s, rows * s, (c) {
      final p = ui.Paint()..isAntiAlias = false;

      // 2) Parşömen zemin: dalın gövdesinin altında kalacak şekilde.
      final paper = ui.Rect.fromLTWH(
        3.0 * s,
        3.0 * s,
        (cols - 6.0) * s,
        (rows - 6.0) * s,
      );
      p.color = pal['line']!;
      c.drawRect(paper.inflate(1.0 * s), p);
      p.color = pal['paper']!;
      c.drawRect(paper, p);
      // alt iç gölge (portfolyodaki inset box-shadow)
      p.color = pal['shade']!;
      c.drawRect(
        ui.Rect.fromLTWH(paper.left, paper.bottom - s, paper.width, 1.0 * s),
        p,
      );

      if (type == PlatformType.fragile) {
        // Çatlak: zikzak piksel çizgi.
        p.color = pal['line']!;
        final mid = (cols / 4).floor() + 1; // yazıdan uzak, sol tarafta
        const crack = [
          [0, 4],
          [1, 5],
          [1, 6],
          [0, 7],
          [-1, 8],
          [0, 9],
          [1, 10],
        ];
        for (final pt in crack) {
          c.drawRect(
            ui.Rect.fromLTWH(
              (mid + pt[0]) * s * 1.0,
              pt[1] * s * 1.0,
              s.toDouble(),
              s.toDouble(),
            ),
            p,
          );
        }
      }

      // 3) Sarmaşık pikselleri (zeminin üstünde).
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          final col = pal[grid[y][x]];
          if (col == null) continue;
          p.color = col;
          c.drawRect(
            ui.Rect.fromLTWH(x * s * 1.0, y * s * 1.0, s * 1.0, s * 1.0),
            p,
          );
        }
      }
    });
  }
}
