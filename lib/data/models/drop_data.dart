// lib/data/models/drop_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DropData {
  final String dropId;
  final bool active;
  final int startAt;
  final int endAt;
  final int limit;
  final int winnerCount;

  DropData({
    required this.dropId,
    required this.active,
    required this.startAt,
    required this.endAt,
    required this.limit,
    required this.winnerCount,
  });

  static DropData? fromSnap(DocumentSnapshot<Map<String, dynamic>>? snap) {
    final d = snap?.data();
    if (d == null) return null;
    final dropId = (d['dropId'] as String?) ?? '';
    final active = (d['active'] as bool?) ?? false;
    final startAt = (d['startAt'] as num?)?.toInt() ?? 0;
    final endAt = (d['endAt'] as num?)?.toInt() ?? 0;
    final limit = (d['limit'] as num?)?.toInt() ?? 0;
    final winnerCount = (d['winnerCount'] as num?)?.toInt() ?? 0;
    if (!active) return null;
    if (dropId.isEmpty) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (endAt <= now) return null;
    return DropData(
      dropId: dropId,
      active: active,
      startAt: startAt,
      endAt: endAt,
      limit: limit,
      winnerCount: winnerCount,
    );
  }
}
