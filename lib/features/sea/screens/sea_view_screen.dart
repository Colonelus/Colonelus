import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/feed_service.dart';
import '../../chat/services/chat_service.dart';
import '../widgets/secret_reveal_dialog.dart';
import '../../../shared/widgets/bottle_widgets.dart';

class DenizAkisiEkrani extends StatefulWidget {
  final Map<String, dynamic> me;
  const DenizAkisiEkrani({super.key, required this.me});
  @override
  State<DenizAkisiEkrani> createState() => _DenizAkisiEkraniState();
}

class _DenizAkisiEkraniState extends State<DenizAkisiEkrani>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _nowMs = 0;
  final Map<String, bool> _sinking = {};
  final Map<String, int> _sinkStart = {};

  final String adminUid = 's9Vo2O5FnKZ7grNN3kRu7DUsN222';

  @override
  void initState() {
    super.initState();
    _nowMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = createTicker((_) {
      if (DateTime.now().millisecond % 2 != 0) return;
      if (!mounted) return;
      _nowMs = DateTime.now().millisecondsSinceEpoch;
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _laneTop(int lane) => 120.0 + (lane.clamp(0, 5) * 92.0);

  double _wave(double x, double t, double seed) {
    return math.sin((x * 2 * math.pi / 240.0) + (t * math.pi * 0.56) + seed) *
        24.0;
  }

  Widget _buildBottle(String type) {
    final double w = type == 'owner_diamond' ? 100 : 60;
    final double h = type == 'owner_diamond' ? 100 : 80;

    final bottle = SizedBox(
      width: w,
      height: h,
      child: AppBottleWidget(type: type),
    );

    Color? glowColor;
    int parcacikSayisi = 6;

    switch (type) {
      case 'purple':
        glowColor = const Color(0xFFE040FB);
        break;
      case 'green':
        glowColor = const Color(0xFF69F0AE);
        break;
      case 'orange':
        glowColor = const Color(0xFFFFAB40);
        break;
      case 'diamond':
        glowColor = const Color(0xFF18FFFF);
        break;
      case 'owner_diamond':
        glowColor = const Color(0xFF18FFFF);
        break;
      case 'blue':
      default:
        glowColor = null;
        break;
    }

    if (glowColor == null) return bottle;

    return SizedBox(
      width: w + 30,
      height: h + 30,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AtesBocegiEfekti(
              parcacikSayisi: parcacikSayisi,
              renk: glowColor,
            ),
          ),
          bottle,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    final w = MediaQuery.of(context).size.width;
    final t = _nowMs / 1000.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Sırdaş Denizi"),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: ChatService.blockedIdsStream(uid),
        builder: (context, blockSnap) {
          final blockedIds = blockSnap.data ?? [];

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FeedService.getFeedStream(uid),
            builder: (context, snap) {
              final rawSecrets = snap.data ?? [];

              final secrets = rawSecrets.where((s) {
                final bool isDeleted = s['isDeleted'] ?? false;
                final authorId = s['authorId'] ?? s['secretAuthorId'] ?? '';
                return !isDeleted && !blockedIds.contains(authorId);
              }).toList();

              return Stack(
                children: secrets.map((s) {
                  final id = s['id'];
                  final createdAtMs =
                      (s['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      _nowMs;
                  final speed =
                      ((s['speedMul'] as num?)?.toDouble() ?? 1.0) * 40.0;
                  const double offset = 180.0;
                  final double dist = w + (offset * 2);
                  final double left =
                      (w + offset) -
                      (((_nowMs - createdAtMs) / 1000.0 * speed) % dist);

                  double sinkDown = 0.0;
                  if (_sinking[id] == true) {
                    sinkDown = (_nowMs - _sinkStart[id]!) / 5.0;
                  }

                  final String authorId =
                      s['authorId'] ?? s['secretAuthorId'] ?? '';
                  final bool isAdmin = authorId == adminUid;
                  final bool isMine = authorId == uid;

                  Widget bottleWidget;
                  if (isAdmin) {
                    bottleWidget = _buildBottle('owner_diamond');
                  } else if (isMine) {
                    bottleWidget = _buildBottle('diamond');
                  } else if (s['tip'] == 'tekne') {
                    bottleWidget = CustomPaint(
                      painter: BoatPainter(),
                      size: const Size(78, 60),
                    );
                  } else {
                    bottleWidget = _buildBottle(s['bottleType'] ?? 'blue');
                  }

                  return Positioned(
                    left: left,
                    top:
                        _laneTop(s['laneIndex'] ?? 0) +
                        _wave(
                          left,
                          t,
                          (s['phase'] as num?)?.toDouble() ?? 0.0,
                        ) +
                        sinkDown,
                    child: GestureDetector(
                      onTap: () => _openSecretDialog(uid, s),
                      child: bottleWidget,
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  void _openSecretDialog(String meId, Map<String, dynamic> s) {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;

    showDialog(
      context: context,
      builder: (_) => SecretRevealDialog(
        author: s['authorName'] ?? 'Anonim',
        content: s['content'] ?? s['secretText'] ?? '',
        isVip:
            s['tip'] == 'tekne' &&
            (s['authorId'] ?? s['secretAuthorId']) != uid,
        bottleType: s['bottleType'] ?? 'blue',
        parchmentType: s['parchmentType'] ?? 'normal',
        parchmentRarity: s['parchmentRarity'] ?? 'common',
        meId: meId,
        authorId: s['authorId'] ?? s['secretAuthorId'] ?? '',
        secret: s,
        me: widget.me,
        onSink: () async {
          await FeedService.markAsSeen(uid, s['id']);
          if (!mounted) return;
          setState(() {
            _sinking[s['id']] = true;
            _sinkStart[s['id']] = _nowMs;
          });
          await Future.delayed(const Duration(milliseconds: 1900));
        },
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
                            color: widget.renk.withValues(alpha: 0.5),
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