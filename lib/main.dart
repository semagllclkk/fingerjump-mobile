import 'package:camera/camera.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_game/game/cats.dart';
import 'package:pixel_game/game/finger_jump_game.dart';
import 'package:pixel_game/services/camera_hand_service.dart';
import 'package:pixel_game/services/gyroscope_service.dart';
import 'package:pixel_game/services/save_data.dart';
import 'package:pixel_game/ui/farm_theme.dart';
import 'package:pixel_game/ui/hud_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FingerJumpApp());
}

enum ControlMode { gyroscope, camera }

class FingerJumpApp extends StatelessWidget {
  const FingerJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finger Jump',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: Farm.font,
        scaffoldBackgroundColor: Farm.skyTop,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Farm.woodDark,
          contentTextStyle: Farm.text(20, color: Colors.white),
        ),
      ),
      home: const StartScreen(),
    );
  }
}

Route<T> _fade<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) =>
      FadeTransition(opacity: anim, child: child),
  transitionDuration: const Duration(milliseconds: 300),
);

// ─── BAŞLANGIÇ EKRANI ─────────────────────────────────────────────────────────

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  SaveData? _save;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await SaveData.load();
    if (mounted) setState(() => _save = s);
  }

  @override
  Widget build(BuildContext context) {
    final save = _save;
    final cat = CatInfo.of(save?.cat ?? CatBreed.sarman);
    return Scaffold(
      body: FarmSkyBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FINGER\nJUMP',
                    textAlign: TextAlign.center,
                    style: Farm.text(84, color: Farm.pinkLight, height: 0.85)
                        .copyWith(
                          shadows: const [
                            Shadow(color: Farm.woodDark, offset: Offset(4, 4)),
                            Shadow(color: Farm.pink, offset: Offset(2, 2)),
                          ],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kedini seç, çiçekli kartlara zıpla!',
                    style: Farm.text(22, color: Farm.woodDark),
                  ),
                  const SizedBox(height: 24),
                  AnimatedCat(breed: cat.breed, scale: 7),
                  const SizedBox(height: 8),
                  VineCard(
                    padding: const EdgeInsets.fromLTRB(26, 16, 26, 16),
                    child: Column(
                      children: [
                        Text(cat.name, style: Farm.text(30)),
                        Text(
                          cat.perkTitle,
                          style: Farm.text(20, color: Farm.pink),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SpinningCoin(scale: 2),
                            const SizedBox(width: 6),
                            Text('${save?.coins ?? 0}', style: Farm.text(24)),
                            const SizedBox(width: 18),
                            Text(
                              'En iyi: ${save?.highScore ?? 0} m',
                              style: Farm.text(24, color: Farm.ink2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  WoodButton(
                    label: 'OYNA',
                    fontSize: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 6,
                    ),
                    onPressed: () => _go(const CatSelectScreen()),
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(_fade(page));
    _reload(); // geri dönünce coin / rekor / kedi güncellensin
  }
}

// ─── KEDİ SEÇİMİ ─────────────────────────────────────────────────────────────

class CatSelectScreen extends StatefulWidget {
  const CatSelectScreen({super.key});

  @override
  State<CatSelectScreen> createState() => _CatSelectScreenState();
}

class _CatSelectScreenState extends State<CatSelectScreen> {
  CatBreed _selected = CatBreed.sarman;

  @override
  void initState() {
    super.initState();
    SaveData.load().then((s) {
      if (mounted) setState(() => _selected = s.cat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = CatInfo.of(_selected);
    return Scaffold(
      body: FarmSkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(title: 'Kedini Seç'),
              const SizedBox(height: 4),
              AnimatedCat(key: ValueKey(_selected), breed: _selected, scale: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: VineCard(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Text(info.name, style: Farm.text(32, height: 1)),
                        Text(
                          info.perkTitle,
                          style: Farm.text(22, color: Farm.pink, height: 1.1),
                        ),
                        Text(
                          info.perkText,
                          textAlign: TextAlign.center,
                          style: Farm.text(20, color: Farm.ink2, height: 1.05),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in CatInfo.all)
                        SizedBox(
                          width: 104,
                          height: 124,
                          child: _CatTile(
                            info: c,
                            selected: c.breed == _selected,
                            onTap: () => setState(() => _selected = c.breed),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 80, top: 6),
                child: WoodButton(
                  label: 'DEVAM',
                  onPressed: () async {
                    await SaveData.setCat(_selected);
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).push(_fade(ModeSelectionScreen(breed: _selected)));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final CatInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _CatTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final frames = CatSprites.framesFor(info.breed);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? Farm.parch : Farm.parch2,
          border: Border.all(
            color: selected ? Farm.pink : Farm.parch3,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: selected ? Farm.pink : Farm.parch3,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PixelImage(frames[0], scale: 4),
            const SizedBox(height: 2),
            Text(info.name, style: Farm.text(20, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Farm.woodDark),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: Farm.text(40, color: Farm.woodDark).copyWith(
              shadows: const [
                Shadow(color: Colors.white, offset: Offset(2, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MOD SEÇİMİ ──────────────────────────────────────────────────────────────

class ModeSelectionScreen extends StatelessWidget {
  final CatBreed breed;
  const ModeSelectionScreen({super.key, required this.breed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FarmSkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(title: 'Nasıl oynayalım?'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                    child: Column(
                      children: [
                        AnimatedCat(breed: breed, scale: 5),
                        const SizedBox(height: 12),
                        _ModeCard(
                          icon: Icons.screen_rotation_alt,
                          title: 'JİROSKOP',
                          subtitle:
                              'Telefonu sağa-sola eğ.\nDokun → yün yumağı at.',
                          onTap: () =>
                              _startGame(context, ControlMode.gyroscope),
                        ),
                        const SizedBox(height: 14),
                        _ModeCard(
                          icon: Icons.back_hand_outlined,
                          title: 'KAMERA',
                          subtitle:
                              'İşaret parmağınla yönlendir.\nYumruk yap → yün yumağı at.',
                          onTap: () => _startGame(context, ControlMode.camera),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, ControlMode mode) {
    Navigator.of(context).push(_fade(GameScreen(mode: mode, breed: breed)));
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: VineCard(
        padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Farm.parch,
                border: Border.all(color: Farm.wood, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: Farm.pink, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Farm.text(30, height: 1)),
                  Text(
                    subtitle,
                    style: Farm.text(19, color: Farm.ink2, height: 1.05),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Farm.wood, size: 30),
          ],
        ),
      ),
    );
  }
}

// ─── OYUN EKRANI ─────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  final ControlMode mode;
  final CatBreed breed;
  const GameScreen({super.key, required this.mode, required this.breed});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final FingerJumpGame _game = FingerJumpGame(breed: widget.breed);
  GyroscopeService? _gyro;
  CameraHandService? _camera;

  /// Kamera hazır olunca yalnızca overlay katmanı yeniden çizilir —
  /// GameScreen.setState ile tüm ağacı (GameWidget dahil) rebuild etmeyiz.
  final ValueNotifier<bool> _cameraReady = ValueNotifier(false);

  bool _isGameOver = false;
  int _finalScore = 0;
  int _runCoins = 0;
  SaveData? _save;
  bool _newRecord = false;

  @override
  void initState() {
    super.initState();
    _game.inputController.onPunch = _game.fireFromPunch;
    _game.onGameOver = _onGameOver;
    _initServices();
  }

  Future<void> _onGameOver() async {
    _gyro?.stop();
    // Kamera akışını hemen kes — game over ekranında boşuna işlem yapılmasın.
    _camera?.stop();
    _cameraReady.value = false;

    final score = _game.scoreNotifier.value;
    final coins = _game.coinNotifier.value;
    final before = await SaveData.load();
    final save = await SaveData.recordRun(score: score, coins: coins);
    if (!mounted) return;
    setState(() {
      _isGameOver = true;
      _finalScore = score;
      _runCoins = coins;
      _save = save;
      _newRecord = score > 0 && score > before.highScore;
    });
  }

  Future<void> _initServices() async {
    if (widget.mode == ControlMode.gyroscope) {
      _gyro = GyroscopeService(_game.inputController)..start();
      return;
    }
    final camera = CameraHandService(_game.inputController);
    _camera = camera;
    final ok = await camera.start();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera başlatılamadı (izin / model dosyası).'),
        ),
      );
    } else {
      _cameraReady.value = true;
    }
  }

  Future<void> _restart() async {
    _gyro?.stop();
    await _camera?.stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      _fade(GameScreen(mode: widget.mode, breed: widget.breed)),
    );
  }

  @override
  void dispose() {
    _gyro?.stop();
    _camera?.stop();
    _cameraReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FingerJumpGame.skyTop,
      body: Stack(
        children: [
          RepaintBoundary(child: GameWidget<FingerJumpGame>(game: _game)),
          RepaintBoundary(
            child: HudWidget(
              game: _game,
              fireHint: widget.mode == ControlMode.camera
                  ? 'Yumruk yap!'
                  : 'Ekrana dokun!',
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _cameraReady,
            builder: (_, ready, _) {
              final camera = _camera;
              if (!ready || camera?.cameraController == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 24,
                right: 12,
                child: RepaintBoundary(child: _CameraOverlay(camera: camera!)),
              );
            },
          ),
          if (_isGameOver)
            _GameOverOverlay(
              breed: widget.breed,
              score: _finalScore,
              coins: _runCoins,
              save: _save!,
              newRecord: _newRecord,
              onRestart: _restart,
              onChangeCat: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                Navigator.of(context).push(_fade(const CatSelectScreen()));
              },
              onMenu: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
        ],
      ),
    );
  }
}

// ─── KAMERA OVERLAY ──────────────────────────────────────────────────────────

/// Kamera önizleme + parmak göstergesi.
///
/// Optimizasyon: CameraPreview (Texture) yalnızca bir kez kurulur; parmak
/// sonucu her geldiğinde sadece üstteki CustomPaint yeniden çizilir.
/// (Eskiden her sonuçta CameraPreview dahil tüm kutu rebuild ediliyordu.)
class _CameraOverlay extends StatelessWidget {
  final CameraHandService camera;
  const _CameraOverlay({required this.camera});

  @override
  Widget build(BuildContext context) {
    final ctrl = camera.cameraController!;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Farm.wood, width: 3),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Farm.woodDark, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRect(
        child: SizedBox(
          width: 96,
          height: 128,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(ctrl),
              ValueListenableBuilder<Offset?>(
                valueListenable: camera.fingerNotifier,
                builder: (_, finger, _) =>
                    CustomPaint(painter: _FingerOverlayPainter(finger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FingerOverlayPainter extends CustomPainter {
  final Offset? finger;
  const _FingerOverlayPainter(this.finger);

  static final Paint _dim = Paint()..color = const Color(0x55000000);
  static final Paint _ring = Paint()
    ..color = Farm.pinkLight
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final Paint _dot = Paint()..color = Farm.pinkLight;

  @override
  void paint(Canvas canvas, Size size) {
    final f = finger;
    if (f == null) {
      canvas.drawRect(Offset.zero & size, _dim);
      return;
    }
    // Ön kamera ayna düzeltmesi: X ters.
    final p = Offset((1.0 - f.dx) * size.width, f.dy * size.height);
    canvas.drawCircle(p, 11, _ring);
    canvas.drawCircle(p, 4, _dot);
  }

  @override
  bool shouldRepaint(_FingerOverlayPainter old) => old.finger != finger;
}

// ─── GAME OVER ───────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatefulWidget {
  final CatBreed breed;
  final int score;
  final int coins;
  final SaveData save;
  final bool newRecord;
  final VoidCallback onRestart;
  final VoidCallback onChangeCat;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.breed,
    required this.score,
    required this.coins,
    required this.save,
    required this.newRecord,
    required this.onRestart,
    required this.onChangeCat,
    required this.onMenu,
  });

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = CatInfo.of(widget.breed);
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        color: const Color(0xAA2A1A10),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
            child: VineCard(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OYUN BİTTİ',
                    style: Farm.text(48, color: Farm.pink, height: 1),
                  ),
                  Text(
                    '${cat.name} biraz dinlensin…',
                    style: Farm.text(20, color: Farm.ink2),
                  ),
                  const SizedBox(height: 8),
                  AnimatedCat(breed: widget.breed, scale: 5, bounce: false),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(value: '${widget.score} m', label: 'yükseklik'),
                      _Stat(
                        value: '+${widget.coins}',
                        label: 'coin',
                        leading: const SpinningCoin(scale: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.newRecord
                        ? 'YENİ REKOR!'
                        : 'En iyi: ${widget.save.highScore} m',
                    style: Farm.text(
                      24,
                      color: widget.newRecord ? Farm.pink : Farm.ink2,
                    ),
                  ),
                  Text(
                    'Toplam coin: ${widget.save.coins}',
                    style: Farm.text(20, color: Farm.ink2),
                  ),
                  const SizedBox(height: 16),
                  WoodButton(label: 'TEKRAR OYNA', onPressed: widget.onRestart),
                  const SizedBox(height: 12),
                  WoodButton(
                    label: 'KEDİ DEĞİŞTİR',
                    color: Farm.green,
                    fontSize: 22,
                    onPressed: widget.onChangeCat,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: widget.onMenu,
                    child: Text(
                      'Ana Menü',
                      style: Farm.text(22, color: Farm.woodDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Widget? leading;
  const _Stat({required this.value, required this.label, this.leading});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(value, style: Farm.text(40, height: 1)),
          ],
        ),
        Text(label, style: Farm.text(18, color: Farm.ink2)),
      ],
    );
  }
}
