import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/feed_service.dart';
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
    return math.sin(
          (x * 2 * math.pi / 240.0) + (t * 2 * math.pi * 0.28) + seed,
        ) *
        24.0;
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FeedService.getFeedStream(),
        builder: (context, snap) {
          final secrets = snap.data ?? [];
          return Stack(
            children: secrets.map((s) {
              final id = s['id'];
              final createdAtMs =
                  (s['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  _nowMs;
              final speed = ((s['speedMul'] as num?)?.toDouble() ?? 1.0) * 40.0;
              const double offset = 180.0;
              final double dist = w + (offset * 2);
              final double left =
                  (w + offset) -
                  (((_nowMs - createdAtMs) / 1000.0 * speed) % dist);

              double sinkDown = 0.0;
              if (_sinking[id] == true) {
                sinkDown = (_nowMs - _sinkStart[id]!) / 5.0;
              }

              final isMine = (s['authorId'] ?? s['secretAuthorId']) == uid;

              return Positioned(
                left: left,
                top:
                    _laneTop(s['laneIndex'] ?? 0) +
                    _wave(left, t, (s['phase'] as num?)?.toDouble() ?? 0.0) +
                    sinkDown,
                child: GestureDetector(
                  onTap: () => _openSecretDialog(uid, s),
                  child: isMine
                      ? SizedBox(
                          width: 60,
                          height: 80,
                          child: AppBottleWidget(type: 'diamond'),
                        )
                      : (s['tip'] == 'tekne'
                            ? CustomPaint(
                                painter: BoatPainter(),
                                size: const Size(78, 60),
                              )
                            : SizedBox(
                                width: 60,
                                height: 80,
                                child: AppBottleWidget(
                                  type: s['bottleType'] ?? 'blue',
                                ),
                              )),
                ),
              );
            }).toList(),
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
