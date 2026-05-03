import 'package:cloud_firestore/cloud_firestore.dart';

class RateLimiter {
  static bool allowSecret(String uid, String text, bool isVip) {
    return true;
  }

  static Future<bool> canWriteSecret(String uid, bool isVip) async {
    final now = DateTime.now();
    final int limit = isVip ? 3 : 1;

    final query = await FirebaseFirestore.instance
        .collection('secrets')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(hours: 24))))
        .get();

    int occupiedSlots = 0;

    for (var doc in query.docs) {
      final data = doc.data();
      final bool isDeleted = data['isDeleted'] ?? false;

      if (!isDeleted) {
        occupiedSlots++;
      } else {
        final Timestamp? deletedAt = data['deletedAt'] as Timestamp?;
        if (deletedAt != null) {
          final diff = now.difference(deletedAt.toDate());
          if (diff.inHours < 6) {
            occupiedSlots++;
          }
        }
      }
    }

    return occupiedSlots < limit;
  }
}