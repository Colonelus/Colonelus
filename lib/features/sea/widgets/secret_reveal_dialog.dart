import 'package:flutter/material.dart';
import '../../../shared/widgets/bottle_widgets.dart';
import '../../../shared/widgets/effect_widgets.dart';
import '../../chat/screens/first_message_screen.dart';
import '../services/secret_interaction_service.dart';
import '../../../core/utils/filter_service.dart';
import '../../../core/utils/rate_limiter.dart';

class SecretRevealDialog extends StatefulWidget {
  final String author;
  final String content;
  final bool isVip;
  final String bottleType;
  final String parchmentType;
  final String parchmentRarity;
  final String meId;
  final String authorId;
  final Map<String, dynamic> secret;
  final Map<String, dynamic> me;
  final Future<void> Function() onSink;

  const SecretRevealDialog({
    super.key,
    required this.author,
    required this.content,
    required this.isVip,
    required this.bottleType,
    required this.parchmentType,
    required this.parchmentRarity,
    required this.meId,
    required this.authorId,
    required this.secret,
    required this.me,
    required this.onSink,
  });

  @override
  State<SecretRevealDialog> createState() => _SecretRevealDialogState();
}

class _SecretRevealDialogState extends State<SecretRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bottleScale;
  late final Animation<double> _bottleLift;
  late final Animation<double> _bottleRotate;
  late final Animation<double> _bottleGlow;
  late final Animation<double> _paperHeight;
  late final Animation<double> _paperWidth;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _textScale;
  late final Animation<double> _dustBurst;
  late final Animation<double> _shineSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2450),
    )..forward();
    _bottleScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOutBack),
      ),
    );
    _bottleLift = Tween<double>(begin: 58, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.26, curve: Curves.easeOutCubic),
      ),
    );
    _bottleRotate = Tween<double>(begin: -0.12, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _bottleGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.40, curve: Curves.easeOut),
      ),
    );
    _paperHeight = Tween<double>(begin: 0.08, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.86, curve: Curves.easeOutBack),
      ),
    );
    _paperWidth = Tween<double>(begin: 0.22, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.76, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _textScale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );
    _dustBurst = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.62, curve: Curves.easeOut),
      ),
    );
    _shineSlide = Tween<double>(begin: -1.25, end: 1.35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.94, curve: Curves.easeInOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2235),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SizedBox(
                height: 478,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SecretRevealGlowPainter(
                          progress: _bottleGlow.value,
                          isVip: widget.isVip,
                          rarity: widget.parchmentRarity,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SecretDustPainter(
                          progress: _dustBurst.value,
                          isVip: widget.isVip,
                          rarity: widget.parchmentRarity,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SecretSparklePainter(
                          progress: _shineSlide.value,
                          rarity: widget.parchmentRarity,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 24,
                      bottom: 112,
                      child: Opacity(
                        opacity: _textFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.content,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, _bottleLift.value),
                        child: Transform.scale(
                          scale: _bottleScale.value,
                          child: SizedBox(
                            width: 136,
                            height: 188,
                            child: AppBottleWidget(type: widget.bottleType),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onSink();
                    },
                    child: const Text('Denize Göm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.authorId == widget.meId ? null : () {},
                    child: const Text('Sırrı Yakala'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
