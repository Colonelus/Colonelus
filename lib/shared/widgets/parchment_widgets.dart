import 'package:flutter/material.dart';

class AppParchmentSheet extends StatelessWidget {
  final String type;
  const AppParchmentSheet({super.key, required this.type});

  String get _assetPath {
    if (type == 'diamond') {
      return 'assets/images/parchments/diamond_parchment.png';
    }
    switch (type) {
      case 'royal':
        return 'assets/images/parchments/parchment_royal.png';
      case 'obsidian':
        return 'assets/images/parchments/parchment_obsidian.png';
      case 'emerald':
        return 'assets/images/parchments/parchment_emerald.png';
      case 'rose':
        return 'assets/images/parchments/parchment_rose.png';
      case 'gold':
        return 'assets/images/parchments/parchment_gold.png';
      case 'ancient':
        return 'assets/images/parchments/parchment_ancient.png';
      case 'normal':
      default:
        return 'assets/images/parchments/parchment_normal.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_assetPath, fit: BoxFit.fill),
          CustomPaint(painter: _ParchmentTexturePainter(type: type)),
        ],
      ),
    );
  }
}

class _ParchmentTexturePainter extends CustomPainter {
  final String type;
  const _ParchmentTexturePainter({required this.type});
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color =
          (type == 'obsidian'
                  ? Colors.white
                  : type == 'diamond'
                  ? const Color(0xFFBFF9FF)
                  : Colors.white70)
              .withAlpha(type == 'diamond' ? 58 : 28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.32, size.height * 0.18),
        width: size.width * 0.50,
        height: size.height * 0.22,
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _ParchmentTexturePainter oldDelegate) =>
      oldDelegate.type != type;
}
