import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppBottleWidget extends StatelessWidget {
  final String type;
  const AppBottleWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    String path;
    switch (type) {
      case 'diamond':
        path = 'assets/images/bottles/bottle_diamond.png';
        break;
      case 'blue':
        path = 'assets/images/bottles/bottle_blue.png';
        break;
      case 'orange':
        path = 'assets/images/bottles/bottle_orange.png';
        break;
      case 'purple':
        path = 'assets/images/bottles/bottle_purple.png';
        break;
      case 'green':
        path = 'assets/images/bottles/bottle_green.png';
        break;
      case 'owner_diamond':
        return const _OwnerAdminBottleWidget();
      default:
        path = 'assets/images/bottles/bottle_blue.png';
    }
    return SizedBox.expand(child: Image.asset(path, fit: BoxFit.contain));
  }
}

class BottlePainter extends CustomPainter {
  final Color color;
  BottlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final neck = RRect.fromLTRBR(
      w * 0.40,
      h * 0.02,
      w * 0.60,
      h * 0.22,
      Radius.circular(w * 0.10),
    );
    final shoulder = RRect.fromLTRBR(
      w * 0.30,
      h * 0.18,
      w * 0.70,
      h * 0.30,
      Radius.circular(w * 0.14),
    );
    final body = RRect.fromLTRBR(
      w * 0.16,
      h * 0.26,
      w * 0.84,
      h * 0.98,
      Radius.circular(w * 0.22),
    );
    final bottlePath = Path()
      ..addRRect(neck)
      ..addRRect(shoulder)
      ..addRRect(body);
    final glowPaint = Paint()
      ..color = color.withAlpha(51)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(bottlePath, glowPaint);
    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withAlpha(46), color.withAlpha(26), color.withAlpha(56)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bottlePath, glassPaint);
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withAlpha(166);
    canvas.drawPath(bottlePath, rimPaint);
  }

  @override
  bool shouldRepaint(covariant BottlePainter oldDelegate) =>
      oldDelegate.color != color;
}

class BoatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hull = Paint()..color = const Color(0xFF5B3A29);
    final sail = Paint()..color = Colors.white;
    final mast = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.7);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width * 0.2, size.height);
    path.close();

    canvas.drawPath(path, hull);

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.2),
      mast,
    );

    final sailPath = Path();
    sailPath.moveTo(size.width * 0.5, size.height * 0.2);
    sailPath.lineTo(size.width * 0.5, size.height * 0.7);
    sailPath.lineTo(size.width * 0.8, size.height * 0.5);
    sailPath.close();

    canvas.drawPath(sailPath, sail);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OwnerAdminBottleWidget extends StatefulWidget {
  const _OwnerAdminBottleWidget();
  @override
  State<_OwnerAdminBottleWidget> createState() =>
      _OwnerAdminBottleWidgetState();
}

class _OwnerAdminBottleWidgetState extends State<_OwnerAdminBottleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
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
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _OwnerAdminAuraPainter(progress: _controller.value),
          ),
          Image.asset('assets/images/adminin_gemi.png', fit: BoxFit.contain),
        ],
      ),
    );
  }
}

class _OwnerAdminAuraPainter extends CustomPainter {
  final double progress;
  const _OwnerAdminAuraPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.56);
    final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF7DF9FF).withAlpha((28 + (46 * pulse)).round()),
              const Color(0xFF9F8CFF).withAlpha((18 + (32 * pulse)).round()),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: w * (0.74 + (0.10 * pulse)),
            ),
          )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, w * (0.74 + (0.10 * pulse)), haloPaint);
  }

  @override
  bool shouldRepaint(covariant _OwnerAdminAuraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
