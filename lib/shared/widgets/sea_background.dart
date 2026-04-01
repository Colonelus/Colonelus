import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DenizArkaPlani extends StatefulWidget {
  const DenizArkaPlani({super.key});
  @override
  State<DenizArkaPlani> createState() => _DenizArkaPlaniState();
}

class _DenizArkaPlaniState extends State<DenizArkaPlani>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _startMs = 0;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker((_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sec = (now - _startMs) / 1000.0;
      setState(() => _t = sec);
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t1 = _t * 2 * math.pi * 0.18;
    final t2 = _t * 2 * math.pi * 0.11;
    final t3 = _t * 2 * math.pi * 0.24;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF001B2E), Color(0xFF01497C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        RepaintBoundary(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: WavePainter(
                    timeRad: t1,
                    opacity: 0.12,
                    waveHeight: 22,
                    offsetRad: 0,
                    baseColor: Colors.cyanAccent,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: WavePainter(
                    timeRad: t2,
                    opacity: 0.08,
                    waveHeight: 32,
                    offsetRad: math.pi / 2,
                    baseColor: Colors.blueAccent,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: WavePainter(
                    timeRad: t3,
                    opacity: 0.14,
                    waveHeight: 42,
                    offsetRad: math.pi,
                    baseColor: Colors.lightBlueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final double timeRad;
  final double opacity;
  final double waveHeight;
  final double offsetRad;
  final Color baseColor;

  WavePainter({
    required this.timeRad,
    required this.opacity,
    required this.waveHeight,
    required this.offsetRad,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor.withAlpha((opacity * 255).round())
      ..style = PaintingStyle.fill;
    final path = Path();
    final baseHeight = size.height * 0.82;
    path.moveTo(0, baseHeight);
    for (double i = 0; i <= size.width; i++) {
      final relativeX = i / size.width;
      final y =
          math.sin((relativeX * 2 * math.pi) + timeRad + offsetRad) *
          waveHeight;
      path.lineTo(i, baseHeight + y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) =>
      oldDelegate.timeRad != timeRad ||
      oldDelegate.opacity != opacity ||
      oldDelegate.waveHeight != waveHeight ||
      oldDelegate.offsetRad != offsetRad ||
      oldDelegate.baseColor != baseColor;
}
