import 'package:cloud_firestore/cloud_firestore.dart';

class UsageService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _dayId(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static DocumentReference<Map<String, dynamic>> dailyRef(
    String uid,
    String dayId,
  ) {
    return _db.collection('usage').doc(uid).collection('daily').doc(dayId);
  }

  static Map<String, dynamic> _baseDailyDoc(String uid, String dayId) {
    return {
      'dayId': dayId,
      'userId': uid,
      'secrets': 0,
      'catches': 0,
      'messages': 0,
      'lastMessageAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<void> ensureDailyDoc(String uid) async {
    final dayId = _dayId(DateTime.now());
    final ref = dailyRef(uid, dayId);

    await ref.set(_baseDailyDoc(uid, dayId), SetOptions(merge: true));
  }

  static Future<void> createSecret({
    required String uid,
    required String secretDocId,
    required Map<String, dynamic> secretData,
  }) async {
    final dayId = _dayId(DateTime.now());
    final usageRef = dailyRef(uid, dayId);
    final secretRef = _db.collection('secrets').doc(secretDocId);

    final batch = _db.batch();

    batch.set(usageRef, _baseDailyDoc(uid, dayId), SetOptions(merge: true));
    batch.set(secretRef, secretData, SetOptions(merge: false));

    batch.set(usageRef, {
      'secrets': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  static Future<void> createCatchRequest({
    required String uid,
    required String requestDocId,
    required Map<String, dynamic> requestData,
  }) async {
    final dayId = _dayId(DateTime.now());
    final usageRef = dailyRef(uid, dayId);
    final reqRef = _db.collection('chat_requests').doc(requestDocId);

    final batch = _db.batch();

    batch.set(usageRef, _baseDailyDoc(uid, dayId), SetOptions(merge: true));
    batch.set(reqRef, requestData, SetOptions(merge: false));

    batch.set(usageRef, {
      'catches': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  static Future<void> createMessage({
    required String uid,
    required String chatId,
    required String messageDocId,
    required Map<String, dynamic> messageData,
  }) async {
    final dayId = _dayId(DateTime.now());
    final usageRef = dailyRef(uid, dayId);

    final msgRef = _db
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId);

    final batch = _db.batch();

    batch.set(usageRef, _baseDailyDoc(uid, dayId), SetOptions(merge: true));
    batch.set(msgRef, messageData, SetOptions(merge: false));

    batch.set(usageRef, {
      'messages': FieldValue.increment(1),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
