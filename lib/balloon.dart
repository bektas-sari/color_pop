import 'dart:math';
import 'package:flutter/material.dart';

class Balloon extends StatefulWidget {
  final Color color;
  final double startXFraction; // 0..1
  final double travelSeconds;
  final Size screenSize;
  final bool isPaused;
  final VoidCallback onPop;
  final VoidCallback onMiss;

  const Balloon({
    super.key,
    required this.color,
    required this.startXFraction,
    required this.travelSeconds,
    required this.screenSize,
    required this.isPaused,
    required this.onPop,
    required this.onMiss,
  });

  @override
  State<Balloon> createState() => _BalloonState();
}

class _BalloonState extends State<Balloon> with TickerProviderStateMixin {
  late final AnimationController _move;
  late final AnimationController _pop;
  bool _popped = false;
  final Random _rng = Random();
  late final double _balloonSize;
  late final double _drift; // px

  @override
  void initState() {
    super.initState();
    _balloonSize = 70 + _rng.nextDouble() * 40; // 70..110
    _drift = (_rng.nextDouble() * 160 - 80);    // -80..+80

    _move = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.travelSeconds * 1000).toInt()),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_popped) {
          widget.onMiss(); // tepeye ulaştı → oyun biter
        }
      })
      ..forward();

    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant Balloon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _move.stop(canceled: false);
      } else if (!_popped) {
        _move.forward();
      }
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_popped) return;
    setState(() => _popped = true);
    _move.stop();
    _pop.forward().whenComplete(() {
      widget.onPop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.screenSize;

    return AnimatedBuilder(
      animation: Listenable.merge([_move, _pop]),
      builder: (context, _) {
        final t = Curves.easeOut.transform(_move.value);
        final y = size.height - t * (size.height + _balloonSize);
        final x = widget.startXFraction * size.width + _drift * t;

        final popScale =
        Tween<double>(begin: 1.0, end: 1.35).transform(_pop.value);
        final popOpacity =
        Tween<double>(begin: 1.0, end: 0.0).transform(_pop.value);

        return Positioned(
          left: x - _balloonSize / 2,
          top: y,
          child: Opacity(
            opacity: popOpacity,
            child: Transform.scale(
              scale: popScale,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: _BalloonBody(
                  color: widget.color,
                  size: _balloonSize,
                  burstProgress: _pop.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BalloonBody extends StatelessWidget {
  final Color color;
  final double size;
  final double burstProgress; // 0..1

  const _BalloonBody({
    required this.color,
    required this.size,
    required this.burstProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.35,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // İp
          Positioned(
            bottom: -size * 0.1,
            child: CustomPaint(
              size: Size(size * 0.12, size * 0.5),
              painter: _StringPainter(),
            ),
          ),
          // Parlak balon
          _ShinyBalloon(color: color, size: size),
          // Patlama konfeti/ışınlar
          IgnorePointer(
            child: CustomPaint(
              size: Size.square(size * 1.4),
              painter: _BurstPainter(progress: burstProgress, baseColor: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShinyBalloon extends StatelessWidget {
  final Color color;
  final double size;
  const _ShinyBalloon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.9,
      colors: [
        Colors.white.withOpacity(0.95),
        color.withOpacity(0.9),
        color,
      ],
      stops: const [0.0, 0.15, 1.0],
    );

    return Container(
      width: size,
      height: size * 1.25,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(0, 0.9),
        child: Container(
          width: size * 0.36,
          height: size * 0.14,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _StringPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.cubicTo(
      size.width / 2 - 6, size.height * 0.25,
      size.width / 2 + 6, size.height * 0.55,
      size.width / 2 - 6, size.height * 0.85,
    );
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BurstPainter extends CustomPainter {
  final double progress; // 0..1
  final Color baseColor;
  _BurstPainter({required this.progress, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2.2);
    final numRays = 10;
    final maxLen = size.width * 0.45;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = baseColor.withOpacity(1 - progress);

    for (int i = 0; i < numRays; i++) {
      final angle = (i / numRays) * pi * 2;
      final len = maxLen * Curves.easeOut.transform(progress);
      final start = center + Offset.fromDirection(angle, len * 0.35);
      final end = center + Offset.fromDirection(angle, len);
      canvas.drawLine(start, end, linePaint);
    }

    // Konfeti noktaları
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final r = 3.0 + 3.0 * progress;
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * pi * 2 + progress * 2;
      final len = maxLen * progress;
      final pos = center + Offset.fromDirection(angle, len);
      dotPaint.color = baseColor.withOpacity(1 - progress);
      canvas.drawCircle(pos, r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.baseColor != baseColor;
}
