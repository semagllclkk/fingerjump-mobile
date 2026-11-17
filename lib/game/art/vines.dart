/// Pembe çiçekli sarmaşık desenleri — portfolyodaki çiftlik sahnesinin
/// `src/farm/game/vines.js` dosyasındaki 9 dilimli çerçevenin birebir aynısı.
/// Hem oyun içi beceri kartları hem de menü kartları bu desenleri kullanır.
library;

/// Sol üst köşe (7×7): dışa bakan çiçek, dal sağa ve aşağı devam eder.
const List<String> vineCorner = [
  '.pPp...',
  'pWPPp..',
  'PPYPPV.',
  'pPPPpVV',
  '.pPpV..',
  '..VV...',
  '...V...',
];

/// Üst kenar (14×7): dalgalı dal, bir yaprak çifti ve küçük bir tomurcuk.
const List<String> vineEdge = [
  '..........pPp.',
  '..GG......PYP.',
  '..gGG.....pPp.',
  'VVVVVVV..VVVVV',
  '.......VV.....',
  '........gG....',
  '.........G....',
];

/// Köşe boyutu (piksel).
const int vineCornerSize = 7;
