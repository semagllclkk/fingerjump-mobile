import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/services/camera_hand_service.dart';
import 'package:pixel_game/services/gyroscope_service.dart';
import 'package:pixel_game/ui/hud_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _game = FingerJumpGame();
    _initServices();
  }

  Future<void> _initServices() async {
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
        // Kamera hazır — önizlemeyi tetikle.
        setState(() {});
      }
    }

    // Her iki modda da onPunch → ateş bağlantısı.
    _game.inputController.onPunch = _game.fireFromPunch;
  }

  @override
  void dispose() {
    _gyro?.stop();
    _camera?.stop();
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
          GameWidget<FingerJumpGame>(game: _game),
          HudWidget(scoreNotifier: _game.scoreNotifier),

          // ── Kamera önizleme (sağ alt, yuvarlak köşe) ──
          if (camReady)
            Positioned(
              bottom: 32,
              right: 16,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 90,
                      height: 120,
                      child: CameraPreview(camCtrl),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📷 Parmak',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
