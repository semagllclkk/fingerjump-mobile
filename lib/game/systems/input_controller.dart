import 'package:flutter/foundation.dart';

/// Tüm giriş kaynaklarını oyundan ayıran tek köprü.
/// normalizedX : [-1, 1]  (-1=sol, 0=merkez, 1=sağ)
/// onPunch     : boss savaşında ateş tetikleyici
class InputController {
  double normalizedX = 0.0;

  /// Kamera modunda yumruk, jiroskop modunda ekrana dokunma bunu tetikler.
  VoidCallback? onPunch;
}
