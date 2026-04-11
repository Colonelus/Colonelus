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
        .limit(20)
        .snapshots();
  }

  static Stream<List<Map<String, dynamic>>> getFeedStream() {
    return secretsStream().map((snap) {
      return snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> dropStream() {
    return _db.collection('drops').doc('current').snapshots();
  }
}
