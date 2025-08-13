import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop için
import 'balloon.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Pop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Random _rng = Random();
  final List<_BalloonData> _balloons = [];
  late Timer _spawnTicker;
  late Stopwatch _clock;

  bool _running = false;
  bool _paused = false;
  int _score = 0;
  int _lives = 3; // görselde dursun, oyun tepeye ulaşınca direkt biter
  int _level = 1;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    if (_running) {
      _spawnTicker.cancel();
    }
    super.dispose();
  }

  void _startGame() {
    if (_running) {
      _spawnTicker.cancel();
    }
    _clock = Stopwatch()..start();
    _score = 0;
    _lives = 3;
    _level = 1;
    _balloons.clear();
    _running = true;
    _paused = false;

    _spawnTicker = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (_paused) return;

      // Zaman ilerledikçe hız artsın: her 25 sn'de ~2x
      final elapsed = _clock.elapsed.inSeconds;
      final speedFactor = 1.0 + (elapsed / 25.0); // 0s:1.0, 25s:2.0, 50s:3.0...
      double travelSeconds = 8.0 / speedFactor;   // daha kısa süre => daha hızlı
      if (travelSeconds < 2.0) travelSeconds = 2.0; // alt sınır
      travelSeconds += _rng.nextDouble() * 0.7;     // hafif rastgelelik

      final x = _rng.nextDouble(); // 0..1
      final color = _randomBalloonColor();
      final id = UniqueKey();

      setState(() {
        _balloons.add(
          _BalloonData(
            id: id,
            color: color,
            startXFraction: x,
            travelSeconds: travelSeconds,
          ),
        );
        _level = 1 + elapsed ~/ 10; // sadece gösterim
      });
    });
  }

  void _onPop(Key id) {
    setState(() {
      _score += 1;
      _balloons.removeWhere((b) => b.id == id);
    });
  }

  void _onMiss(Key id) {
    // Balon tepeye ulaştı → Oyun hemen biter
    _balloons.removeWhere((b) => b.id == id);
    _endGame();
  }

  void _endGame() {
    if (_running) {
      _spawnTicker.cancel();
    }
    _running = false;
    _paused = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Score: $_score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(_startGame);
            },
            child: const Text('Play Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              SystemNavigator.pop(); // uygulamadan çık
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _clock.stop();
      } else {
        _clock.start();
      }
    });
  }

  void _reset() {
    if (_running) {
      _spawnTicker.cancel();
    }
    _startGame();
  }

  Color _randomBalloonColor() {
    const palette = [
      Color(0xFF6C63FF),
      Color(0xFFFF6584),
      Color(0xFFFFC107),
      Color(0xFF00C2A8),
      Color(0xFF4CAF50),
      Color(0xFF00B0FF),
      Color(0xFFFF8A65),
    ];
    return palette[_rng.nextInt(palette.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            children: [
              // Arka plan
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0F2F1)],
                  ),
                ),
              ),
              // Yumuşak bulutlar
              Positioned.fill(child: _SoftCloudsLayer()),
              // Balonlar
              ..._balloons.map(
                    (b) => Balloon(
                  key: b.id,
                  color: b.color,
                  startXFraction: b.startXFraction,
                  travelSeconds: b.travelSeconds,
                  screenSize: size,
                  isPaused: _paused,
                  onPop: () => _onPop(b.id),
                  onMiss: () => _onMiss(b.id),
                ),
              ),
              // HUD altta
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      _GlassCard(
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Score: $_score',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.speed_rounded, size: 20),
                            const SizedBox(width: 4),
                            Text('Lv $_level',
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _GlassCard(
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              '$_lives',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassButton(
                        icon: _paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        onTap: _togglePause,
                        tooltip: _paused ? 'Resume' : 'Pause',
                      ),
                      const SizedBox(width: 8),
                      _GlassButton(
                        icon: Icons.restart_alt_rounded,
                        onTap: _reset,
                        tooltip: 'Restart',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
      ),
      child: child,
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _GlassButton(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class _SoftCloudsLayer extends StatefulWidget {
  @override
  State<_SoftCloudsLayer> createState() => _SoftCloudsLayerState();
}

class _SoftCloudsLayerState extends State<_SoftCloudsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final offset = (t * 200) % 200;
        return CustomPaint(painter: _CloudsPainter(offset: offset));
      },
    );
  }
}

class _CloudsPainter extends CustomPainter {
  final double offset;
  _CloudsPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.12);
    for (int i = 0; i < 4; i++) {
      final dx = (i * 160.0 + offset) % (size.width + 200) - 100;
      final dy = size.height * (0.15 + i * 0.18);
      final rect =
      Rect.fromCenter(center: Offset(dx, dy), width: 200, height: 80);
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudsPainter oldDelegate) =>
      oldDelegate.offset != offset;
}

class _BalloonData {
  final Key id;
  final Color color;
  final double startXFraction;
  final double travelSeconds;

  _BalloonData({
    required this.id,
    required this.color,
    required this.startXFraction,
    required this.travelSeconds,
  });
}
