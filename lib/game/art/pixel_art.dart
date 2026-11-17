import 'dart:ui' as ui;

/// Piksel sanatı yardımcıları.
///
/// Tüm sprite'lar harf ızgarası olarak tanımlanır (portfolyodaki çiftlik
/// sahnesiyle aynı yöntem) ve **bir kez** `ui.Image`'a çizilip önbelleğe
/// alınır. Oyun döngüsünde yalnızca `drawImage` çağrılır — her frame yüzlerce
/// `drawRect` yerine tek bir kopyalama. Bu, eski RectangleComponent ağacına
/// göre hem daha hızlı hem de GC baskısı yaratmayan bir yoldur.

/// Piksel sanatı çizerken bulanıklaşmayı önleyen ortak paint.
final ui.Paint pixelPaint = ui.Paint()
  ..filterQuality = ui.FilterQuality.none
  ..isAntiAlias = false;

/// [draw] ile verilen çizimi [w]×[h] boyutunda bir resme dönüştürür.
ui.Image paintToImage(int w, int h, void Function(ui.Canvas c) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(w, h);
  picture.dispose();
  return image;
}

/// Harf ızgarasını [scale] katı büyüklükte bir resme çevirir.
/// `.` ve palette olmayan karakterler saydam kalır.
ui.Image gridToImage(
  List<String> rows,
  Map<String, ui.Color> palette, {
  int scale = 1,
  bool flipX = false,
}) {
  final h = rows.length;
  final w = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  return paintToImage(w * scale, h * scale, (c) {
    paintGrid(
      c,
      rows,
      palette,
      scale: scale.toDouble(),
      flipX: flipX,
      width: w,
    );
  });
}

/// Izgarayı doğrudan bir canvas'a çizer (resme dönüştürmeden).
void paintGrid(
  ui.Canvas c,
  List<String> rows,
  Map<String, ui.Color> palette, {
  double scale = 1,
  double dx = 0,
  double dy = 0,
  bool flipX = false,
  int? width,
}) {
  final w = width ?? rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  final paint = ui.Paint()..isAntiAlias = false;
  for (var y = 0; y < rows.length; y++) {
    final row = rows[y];
    for (var x = 0; x < row.length; x++) {
      final color = palette[row[x]];
      if (color == null) continue;
      paint.color = color;
      final px = flipX ? (w - 1 - x) : x;
      c.drawRect(
        ui.Rect.fromLTWH(dx + px * scale, dy + y * scale, scale, scale),
        paint,
      );
    }
  }
}

/// Bir ızgaranın satırlarını yatay aynalar.
List<String> mirrorRows(List<String> rows) =>
    rows.map((r) => String.fromCharCodes(r.codeUnits.reversed)).toList();
