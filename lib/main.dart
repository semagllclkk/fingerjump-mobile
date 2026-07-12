import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/services/camera_hand_service.dart';
import 'package:pixel_game/services/gyroscope_service.dart';
import 'package:pixel_game/ui/hud_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FingerJumpApp());
}

// ─── Kontrol modu ────────────────────────────────────────────────────────────

enum ControlMode { gyroscope, camera }

// ─── Uygulama kök widget ─────────────────────────────────────────────────────

class FingerJumpApp extends StatelessWidget {
  const FingerJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finger Jump',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const StartScreen(),
    );
  }
}

// ─── BAŞLANGIÇ EKRANI ─────────────────────────────────────────────────────────

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2A),
      body: Stack(
        children: [
          const _StarField(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo ──────────────────────────────────────────────────────
                ScaleTransition(
                  scale: _pulse,
                  child: Text(
                    'FINGER\nJUMP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      height: 1.1,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                        ).createShader(
                          const Rect.fromLTWH(0, 0, 300, 80),
                        ),
                      shadows: [
                        const Shadow(
                          color: Color(0x9900E5FF),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tırman. Zıpla. Yenilmez ol.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 64),

                // ── OYNA butonu ───────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, _) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF)
                              .withAlpha(((_pulse.value - 0.96) / 0.08 * 120 + 60).toInt()),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _goToModeSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF0A0E2A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 52,
                          vertical: 18,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      child: const Text('OYNA'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goToModeSelect() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const ModeSelectionScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// ─── YILDIZ ARKA PLANI ────────────────────────────────────────────────────────

class _StarField extends StatefulWidget {
  const _StarField();

  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random(42);
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(
      60,
      (_) => _Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: _rng.nextDouble() * 1.8 + 0.4,
        phase: _rng.nextDouble() * math.pi * 2,
      ),
    );
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _StarPainter(_stars, _ctrl.value),
      ),
    );
  }
}

class _Star {
  final double x, y, r, phase;
  const _Star({required this.x, required this.y, required this.r, required this.phase});
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final alpha = (math.sin(t * math.pi * 2 + s.phase) * 0.4 + 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        Paint()..color = Colors.white.withAlpha((alpha * 200).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => true;
}

// ─── MOD SEÇİM EKRANI ────────────────────────────────────────────────────────

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white60),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nasıl oynamak\nistersin?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white.withAlpha(230),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 48),
            _ModeCard(
              icon: Icons.screen_rotation_alt,
              title: 'JİROSKOP',
              subtitle: 'Telefonu eğerek oyna',
              color: const Color(0xFF4CAF50),
              onTap: () => _startGame(context, ControlMode.gyroscope),
            ),
            const SizedBox(height: 20),
            _ModeCard(
              icon: Icons.back_hand_outlined,
              title: 'KAMERA',
              subtitle: 'Parmağınla yönlendir\nYumruk yap → ateş et',
              color: const Color(0xFF00E5FF),
              onTap: () => _startGame(context, ControlMode.camera),
            ),
          ],
        ),
      ),
    );
  }

  void _startGame(BuildContext context, ControlMode mode) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => GameScreen(mode: mode),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withAlpha(120), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withAlpha(25), color.withAlpha(10)],
          ),
          boxShadow: [
            BoxShadow(color: color.withAlpha(40), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 13,
                        height: 1.4,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withAlpha(160)),
          ],
        ),
      ),
    );
  }
}

// ─── OYUN EKRANI ─────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  final ControlMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late FingerJumpGame _game;
  GyroscopeService? _gyro;
  CameraHandService? _camera;

  bool _isGameOver = false;
  int _finalScore = 0;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _game = FingerJumpGame();
    _loadHighScore();
    _initServices();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _highScore = prefs.getInt('highScore') ?? 0);
  }

  Future<void> _saveHighScore(int score) async {
    if (score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', score);
      if (mounted) setState(() => _highScore = score);
    }
  }

  Future<void> _initServices() async {
    // Game over → Flutter katmanına bildir
    _game.onGameOver = () {
      if (!mounted) return;
      final score = _game.scoreNotifier.value;
      _saveHighScore(score);
      setState(() {
        _isGameOver = true;
        _finalScore = score;
      });
    };

    if (widget.mode == ControlMode.gyroscope) {
      _gyro = GyroscopeService(_game.inputController);
      _gyro!.start();
    } else {
      _camera = CameraHandService(_game.inputController);
      final ok = await _camera!.start();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera izni gerekli!')),
        );
      } else if (mounted) {
        setState(() {});
      }
    }

    _game.inputController.onPunch = _game.fireFromPunch;
  }

  Future<void> _restart() async {
    _gyro?.stop();
    // Kamera modunda: native kanalı tamamen kapat, sonra navigate et.
    // Böylece yeni GameScreen'in startTracking'i eski oturumun üstüne binmez.
    await _camera?.stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(mode: widget.mode)),
    );
  }

  @override
  void dispose() {
    _gyro?.stop();
    _camera?.stop(); // async ama dispose'da await yapamıyoruz; _isStopped flag hemen set eder
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camCtrl = _camera?.cameraController;
    final camReady = camCtrl != null && camCtrl.value.isInitialized;

    return Scaffold(
      backgroundColor: FingerJumpGame.skyTop,
      body: Stack(
        children: [
          // RepaintBoundary: GameWidget kendi render döngüsünde çalışır.
          // Flutter widget rebuild'larından izole edilmesi oyunu kasımadan çalıştırır.
          RepaintBoundary(
            child: GameWidget<FingerJumpGame>(game: _game),
          ),

          // HUD da izole — sadece skor değişince rebuild olur.
          RepaintBoundary(
            child: HudWidget(scoreNotifier: _game.scoreNotifier),
          ),

          // ── Kamera önizleme (sağ alt) ──
          // Ayrı widget olarak izole edildi: rebuild'lar sadece overlay'i etkiler,
          // GameWidget/HUD'u etkilemez.
          if (camReady)
            Positioned(
              bottom: 32,
              right: 16,
              child: RepaintBoundary(
                child: _CameraOverlay(camera: _camera!),
              ),
            ),

          // ── Game Over ekranı ──
          if (_isGameOver)
            _GameOverOverlay(
              score: _finalScore,
              highScore: _highScore,
              onRestart: _restart,
              onMenu: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
        ],
      ),
    );
  }
}

// ─── KAMERA OVERLAY ──────────────────────────────────────────────────────────

/// Kamera önizleme + parmak overlay widget'ı.
/// GameScreen'den bağımsız bir widget — rebuild'lar burada kalır, oyunu etkilemez.
class _CameraOverlay extends StatelessWidget {
  final CameraHandService camera;
  const _CameraOverlay({required this.camera});

  @override
  Widget build(BuildContext context) {
    final ctrl = camera.cameraController!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tek ListenableBuilder ile hem X hem Y notifier'ı dinle.
        ListenableBuilder(
          listenable: Listenable.merge([
            camera.fingerXNotifier,
            camera.fingerYNotifier,
          ]),
          builder: (context, _) {
            final fingerX = camera.fingerXNotifier.value;
            final fingerY = camera.fingerYNotifier.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: fingerX != null ? Colors.red : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 150,
                          child: CameraPreview(ctrl),
                        ),
                        SizedBox(
                          width: 110,
                          height: 150,
                          child: CustomPaint(
                            painter: _FingerOverlayPainter(
                              fingerX: fingerX,
                              fingerY: fingerY,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fingerX != null
                        ? Colors.red.withAlpha(200)
                        : Colors.black.withAlpha(140),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fingerX != null ? '🖐 ALGILANDI' : '✋ Bekleniyor...',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── GAME OVER EKRANI ───────────────────────────────────────────────────────────────


class _GameOverOverlay extends StatefulWidget {
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  const _GameOverOverlay({
    required this.score,
    required this.highScore,
    required this.onRestart,
    required this.onMenu,
  });
  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 60, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.score > 0 && widget.score >= widget.highScore;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: Container(
        color: Colors.black.withAlpha(200),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1F4E), Color(0xFF0A0E2A)],
              ),
              border: Border.all(color: const Color(0xFF7C4DFF).withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withAlpha(60),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFFF9800)],
                  ).createShader(r),
                  child: const Text(
                    'GAME OVER',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Skor kutusu
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${widget.score} m',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E5FF),
                          letterSpacing: 2,
                        ),
                      ),
                      const Text(
                        'skor',
                        style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Yüksek skor
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isNew ? Icons.emoji_events : Icons.leaderboard,
                      color: isNew ? Colors.amber : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isNew
                          ? 'YENİ REKOR! 🎉'
                          : 'En iyi: ${widget.highScore} m',
                      style: TextStyle(
                        color: isNew ? Colors.amber : Colors.white54,
                        fontSize: 14,
                        fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Tekrar oyna
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF7C4DFF).withAlpha(120),
                    ),
                    child: const Text(
                      'TEKRAR OYNA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Ana menü
                TextButton(
                  onPressed: widget.onMenu,
                  child: const Text(
                    'Ana Menü',
                    style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PARMAK TESPİTİ OVERLAY ──────────────────────────────────────────────────

/// Kamera önizlemesi üzerinde parmak konumunu gösteren painter.
/// [fingerX] ve [fingerY] null ise "algulama yok" göstergesi çizer.
class _FingerOverlayPainter extends CustomPainter {
  final double? fingerX;
  final double? fingerY;
  const _FingerOverlayPainter({this.fingerX, this.fingerY});

  @override
  void paint(Canvas canvas, Size size) {
    if (fingerX == null) {
      // Algılama yok: orta kısmına soluñuk gösterge
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withAlpha(20),
      );
      final textPainter = TextPainter(
        text: const TextSpan(
          text: '\u270b\nbekleniyor',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white54,
            height: 1.4,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width / 2 - textPainter.width / 2, size.height / 2 - textPainter.height / 2),
      );
      return;
    }

    // Ön kamera ayna düşeltmesi: X ters
    final x = (1.0 - fingerX!) * size.width;
    final y = fingerY != null ? fingerY! * size.height : size.height * 0.5;

    // Dikey kılavuz çizgisi
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.red.withAlpha(180)
        ..strokeWidth = 2.0,
    );

    // Yatay kısa çizgi (crosshair)
    canvas.drawLine(
      Offset((x - 20).clamp(0.0, size.width), y),
      Offset((x + 20).clamp(0.0, size.width), y),
      Paint()
        ..color = Colors.red.withAlpha(180)
        ..strokeWidth = 2.0,
    );

    // Dış halka
    canvas.drawCircle(
      Offset(x, y),
      16,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // İç dolu kırmızı daire
    canvas.drawCircle(
      Offset(x, y),
      7,
      Paint()..color = Colors.red,
    );

    // Sol üste kırmızı rozet
    const badgeText = '✓';
    final badge = TextPainter(
      text: const TextSpan(
        text: badgeText,
        style: TextStyle(
            fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, badge.width + 6, badge.height + 2),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.red.withAlpha(230),
    );
    badge.paint(canvas, const Offset(5, 3));
  }

  @override
  bool shouldRepaint(_FingerOverlayPainter old) =>
      old.fingerX != fingerX || old.fingerY != fingerY;
}
