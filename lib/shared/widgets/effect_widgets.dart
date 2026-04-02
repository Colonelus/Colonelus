import 'dart:math' as math;
import 'package:flutter/material.dart';

class SecretRevealGlowPainter extends CustomPainter {
  final double progress;
  final bool isVip;
  final String rarity;
  const SecretRevealGlowPainter({
    required this.progress,
    required this.isVip,
    required this.rarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.72);
    final rarityColor = const Color(0xFFBEEBFF);
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              rarityColor.withAlpha(
                (28 + (54 * progress)).round().clamp(0, 255),
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: size.width * (0.34 + (0.12 * progress)),
            ),
          )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, size.width * (0.34 + (0.12 * progress)), halo);

    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          rarityColor.withAlpha((16 + (52 * progress)).round().clamp(0, 255)),
          Colors.white.withAlpha((8 + (16 * progress)).round().clamp(0, 255)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final beamPath = Path()
      ..moveTo(size.width * 0.39, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.04,
        size.width * 0.61,
        size.height * 0.18,
      )
      ..lineTo(size.width * 0.70, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.86,
        size.width * 0.30,
        size.height * 0.72,
      )
      ..close();
    canvas.drawPath(beamPath, beam);
  }

  @override
  bool shouldRepaint(covariant SecretRevealGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SecretDustPainter extends CustomPainter {
  final double progress;
  final bool isVip;
  final String rarity;
  const SecretDustPainter({
    required this.progress,
    required this.isVip,
    required this.rarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final seed = math.Random(42);
    final base = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 20; i++) {
      final dx = size.width * (0.18 + seed.nextDouble() * 0.64);
      final dy =
          size.height * (0.78 - progress * (0.30 + seed.nextDouble() * 0.18));
      final radius = 1.6 + seed.nextDouble() * 3.0;
      final alpha = ((0.10 + (1 - (i / 20)) * 0.35) * progress * 255).round();
      base.color = Colors.white.withAlpha(alpha.clamp(0, 255));
      canvas.drawCircle(Offset(dx, dy), radius, base);
    }
  }

  @override
  bool shouldRepaint(covariant SecretDustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SecretSparklePainter extends CustomPainter {
  final double progress;
  final String rarity;
  const SecretSparklePainter({required this.progress, required this.rarity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(99);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final cx = size.width * (0.16 + random.nextDouble() * 0.68);
      final cy = size.height * (0.16 + random.nextDouble() * 0.54);
      final twinkle = (0.40 + 0.60 * math.sin((progress * math.pi * 2) + i))
          .abs();
      final arm = (3.5 + random.nextDouble() * 5.0) * (0.55 + progress * 0.65);
      paint
        ..color = Colors.white.withAlpha(
          (24 + (150 * twinkle * progress)).round().clamp(0, 255),
        )
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);
      canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SecretSparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
