import 'package:cloud_firestore/cloud_firestore.dart';

class FeedService {
  static final _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> secretsStream() {
    final since = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );
    return _db
        .collection('secrets')
        .where('banned', isEqualTo: false)
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots();
  }

  static Stream<List<Map<String, dynamic>>> getFeedStream(String uid) {
    return secretsStream().asyncMap((snap) async {
      final seenSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('seenSecrets')
          .get();

      final seenIds = seenSnap.docs.map((d) => d.id).toSet();

      return snap.docs
          .map((d) => {"id": d.id, ...d.data()})
          .where((s) => !seenIds.contains(s['id']))
          .take(20)
          .toList();
    });
  }

  static Future<void> markAsSeen(String uid, String secretId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('seenSecrets')
        .doc(secretId)
        .set({'at': FieldValue.serverTimestamp()});
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> dropStream() {
    return _db.collection('drops').doc('current').snapshots();
  }
}
