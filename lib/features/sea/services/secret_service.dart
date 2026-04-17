import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/filter_service.dart';

class SecretService {
  static final _db = FirebaseFirestore.instance;

  static String _rid() =>
      "sec_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}";

  static Future<void> createSecret({
    required String uid,
    required String name,
    required String text,
  }) async {
    final id = _rid();
    final random = math.Random();

    FilterService.checkAndReport(text, uid);

    await _db.collection('secrets').doc(id).set({
      "secretId": id,
      "secretAuthorId": uid,
      "secretAuthorName": name.isEmpty ? "sırdaş" : name,
      "content": text,
      "authorId": uid,
      "bottleType": "blue",
      "banned": false,
      "createdAt": FieldValue.serverTimestamp(),
      "laneIndex": random.nextInt(6),
      "phase": random.nextDouble() * 2 * math.pi,
      "speedMul": 0.8 + (random.nextDouble() * 0.4),
    });
  }

  static Future<void> banSecret(String secretId) async {
    await _db.collection('secrets').doc(secretId).update({'banned': true});
  }

  static Future<void> banUser(String userId) async {
    await _db.collection('users').doc(userId).update({'banned': true});
  }

  static Future<void> unbanUser(String userId) async {
    await _db.collection('users').doc(userId).update({'banned': false});
  }

  static Future<void> deleteSecret(String secretId) async {
    await _db.collection('secrets').doc(secretId).delete();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getSecretsInSea() {
    final threshold = DateTime.now().subtract(const Duration(hours: 24));
    return _db
        .collection('secrets')
        .where('banned', isEqualTo: false)
        .where('createdAt', isGreaterThan: threshold)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
