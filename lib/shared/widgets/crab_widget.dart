import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CrabWidget extends StatefulWidget {
  final int endAt;
  const CrabWidget({super.key, required this.endAt});

  @override
  State<CrabWidget> createState() => _CrabWidgetState();
}

class _CrabWidgetState extends State<CrabWidget> {
  Timer? _timer;
  int _nowMs = 0;

  @override
  void initState() {
    super.initState();
    _nowMs = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leftMs = (widget.endAt - _nowMs).clamp(0, 600000);
    final leftSec = (leftMs / 1000).ceil();
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple.withAlpha(80),
            border: Border.all(
              color: Colors.cyanAccent.withAlpha(160),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text('🦀', style: TextStyle(fontSize: 26)),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '${leftSec}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
