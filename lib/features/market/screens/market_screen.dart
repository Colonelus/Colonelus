import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/billing_service.dart';
import '../../auth/services/auth_profile_service.dart';
import '../../../data/models/user_model.dart';
import 'dart:math' as math;

class MarketEkrani extends StatefulWidget {
  final Map<String, dynamic> me;
  const MarketEkrani({super.key, required this.me});

  @override
  State<MarketEkrani> createState() => _MarketEkraniState();
}

class _MarketEkraniState extends State<MarketEkrani>
    with TickerProviderStateMixin {
  bool _busy = false;
  String? _status;

  final Color _bgColor = const Color(0xFF0F172A);
  final Color _sectionColor = const Color(0xFF1E1E38);
  final Color _borderColor = const Color(0xFFB8860B);
  final Color _textColor = const Color(0xFFFACC15);

  @override
  void initState() {
    super.initState();
    BillingService.start(
      onMessage: (message) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  void dispose() {
    BillingService.stop();
    super.dispose();
  }

  Future<void> _handleItemTap(String id) async {
    if (_busy) return;
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      color: _sectionColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottleItem(
    String assetPath,
    int price, {
    Color glowColor = const Color(0xFFFACC15),
  }) {
    const double bottleHeight = 80.0;
    const double effectAreaSize = 100.0;

    return Column(
      children: [
        SizedBox(
          height: effectAreaSize,
          width: effectAreaSize / 1.5,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AtesBocegiEfekti(parcacikSayisi: 8, renk: glowColor),
              ),
              SizedBox(
                height: bottleHeight,
                child: Image.asset(assetPath, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            color: Colors.transparent,
          ),
          child: Text(
            '$price İnci',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inci = (widget.me['inci'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Market',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '$inci İnci',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle('Şişe Renkleri'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottleItem(
                        'assets/images/bottles/bottle_green.png',
                        5,
                        glowColor: const Color(0xFF69F0AE),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_orange.png',
                        7,
                        glowColor: const Color(0xFFFFAB40),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_purple.png',
                        10,
                        glowColor: const Color(0xFFE040FB),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_diamond.png',
                        25,
                        glowColor: const Color(0xFF18FFFF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class AtesBocegiEfekti extends StatefulWidget {
  final int parcacikSayisi;
  final Color renk;

  const AtesBocegiEfekti({
    super.key,
    required this.parcacikSayisi,
    required this.renk,
  });

  @override
  State<AtesBocegiEfekti> createState() => _AtesBocegiEfektiState();
}

class _AtesBocegiEfektiState extends State<AtesBocegiEfekti>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _opacityAnimations;
  late List<Animation<Offset>> _motionAnimations;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _opacityAnimations = [];
    _motionAnimations = [];

    for (int i = 0; i < widget.parcacikSayisi; i++) {
      final duration = Duration(milliseconds: 2000 + _random.nextInt(2000));
      final controller = AnimationController(vsync: this, duration: duration);

      Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });

      final opacityAnimation = Tween<double>(
        begin: 0.1,
        end: 0.8,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      final motionAnimation = Tween<Offset>(
        begin: Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5),
        end: Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5),
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      _controllers.add(controller);
      _opacityAnimations.add(opacityAnimation);
      _motionAnimations.add(motionAnimation);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: List.generate(widget.parcacikSayisi, (index) {
            final size = 2.0 + _random.nextDouble() * 3.0;

            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                final xPos =
                    constraints.maxWidth / 2 +
                    (_motionAnimations[index].value.dx * constraints.maxWidth);
                final yPos =
                    constraints.maxHeight / 2 +
                    (_motionAnimations[index].value.dy * constraints.maxHeight);

                return Positioned(
                  left: xPos,
                  top: yPos,
                  child: Opacity(
                    opacity: _opacityAnimations[index].value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.renk,
                        boxShadow: [
                          BoxShadow(
                            color: widget.renk.withOpacity(0.5),
                            blurRadius: size * 2,
                            spreadRadius: size / 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}
