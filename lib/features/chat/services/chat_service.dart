import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_enums.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static String _rid(String prefix) =>
      "${prefix}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}";

  static Stream<int> pendingRequestsCountStream(String uid) {
    return _db
        .collection('chat_requests')
        .where('secretAuthorId', isEqualTo: uid)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Stream<int> unreadConversationsCountStream(String uid) {
    return _db
        .collection('conversations')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
          return snap.docs.where((doc) {
            final unreadMap = doc.data()['unreadBy'] as Map?;
            final count = unreadMap?[uid] ?? 0;
            return count > 0;
          }).length;
        });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestsStream(
    String uid,
  ) {
    return _db
        .collection('chat_requests')
        .where('secretAuthorId', isEqualTo: uid)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> outgoingRequestsStream(
    String uid,
  ) {
    return _db
        .collection('chat_requests')
        .where('requesterId', isEqualTo: uid)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream(
    String uid,
  ) {
    return _db
        .collection('conversations')
        .where('memberIds', arrayContains: uid)
        .orderBy('lastAt', descending: true)
        .limit(80)
        .snapshots();
  }

  static Future<void> markConversationRead({
    required String convId,
    required String userId,
  }) async {
    await _db.collection('conversations').doc(convId).update({
      'unreadBy.$userId': 0,
    });
  }

  static Future<void> createChatRequest({
    required String secretId,
    required String secretAuthorId,
    required String secretAuthorName,
    required String secretText,
    required String requesterId,
    required String requesterName,
    required String firstMessageText,
  }) async {
    final safeSecretId = secretId.trim();
    final safeSecretAuthorId = secretAuthorId.trim();
    final safeRequesterId = requesterId.trim();
    final safeFirstMessageText = firstMessageText.trim();

    if (safeSecretId.isEmpty ||
        safeSecretAuthorId.isEmpty ||
        safeRequesterId.isEmpty ||
        safeFirstMessageText.isEmpty ||
        safeSecretAuthorId == safeRequesterId)
      return;

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    batch.set(
      _db
          .collection('users')
          .doc(safeRequesterId)
          .collection('seenSecrets')
          .doc(safeSecretId),
      {"at": now},
    );

    final basePayload = <String, dynamic>{
      "secretId": safeSecretId,
      "secretAuthorId": safeSecretAuthorId,
      "secretAuthorName": secretAuthorName.trim().isEmpty
          ? "sırdaş"
          : secretAuthorName.trim(),
      "secretSnapshotText": secretText,
      "requesterId": safeRequesterId,
      "requesterName": requesterName.trim().isEmpty
          ? "sırdaş"
          : requesterName.trim(),
      "firstMessageText": safeFirstMessageText,
      "status": RequestStatus.pending.name,
      "createdAt": now,
      "banned": false,
      "suspendedUntil": null,
      "decisionAt": null,
      "conversationId": null,
    };

    final existing = await _db
        .collection('chat_requests')
        .where('secretId', isEqualTo: safeSecretId)
        .where('requesterId', isEqualTo: safeRequesterId)
        .limit(5)
        .get();

    bool updated = false;
    for (final doc in existing.docs) {
      final data = doc.data();
      if (data['status'] == RequestStatus.pending.name) {
        batch.set(doc.reference, basePayload, SetOptions(merge: true));
        updated = true;
        break;
      }
      if (data['status'] == RequestStatus.accepted.name) {
        await batch.commit();
        return;
      }
    }

    if (!updated) {
      batch.set(_db.collection('chat_requests').doc(_rid("req")), basePayload);
    }

    await batch.commit();
  }

  static Future<String?> acceptRequest({
    required String requestId,
    required String accepterId,
  }) async {
    final reqRef = _db.collection('chat_requests').doc(requestId);
    return await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return null;
      final req = reqSnap.data()!;
      if (req['status'] != RequestStatus.pending.name ||
          req['secretAuthorId'] != accepterId)
        return null;

      final convId = _rid('conv');
      final convRef = _db.collection('conversations').doc(convId);
      final now = FieldValue.serverTimestamp();
      final firstMsg = (req['firstMessageText'] as String?)?.trim() ?? '';

      tx.set(convRef, {
        'id': convId,
        'memberIds': [req['secretAuthorId'], req['requesterId']],
        'memberNames': {
          req['secretAuthorId']: req['secretAuthorName'],
          req['requesterId']: req['requesterName'],
        },
        'createdAt': now,
        'lastAt': now,
        'lastText': firstMsg,
        'unreadBy': {req['secretAuthorId']: 0, req['requesterId']: 1},
      });

      tx.set(convRef.collection('messages').doc(_rid('msg')), {
        'senderId': req['requesterId'],
        'text': firstMsg,
        'createdAt': now,
      });

      tx.update(reqRef, {
        'status': RequestStatus.accepted.name,
        'decisionAt': now,
        'conversationId': convId,
      });
      return convId;
    });
  }

  static Future<void> rejectRequest({
    required String requestId,
    required String rejecterId,
  }) async {
    final ref = _db.collection('chat_requests').doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data();
      if (d == null ||
          d['status'] != RequestStatus.pending.name ||
          d['secretAuthorId'] != rejecterId)
        return;
      tx.update(ref, {
        "status": RequestStatus.rejected.name,
        "decisionAt": FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> cancelRequest({
    required String requestId,
    required String requesterId,
  }) async {
    final ref = _db.collection('chat_requests').doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data();
      if (d == null ||
          d['status'] != RequestStatus.pending.name ||
          d['requesterId'] != requesterId)
        return;
      tx.update(ref, {
        "status": RequestStatus.cancelled.name,
        "decisionAt": FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String convId, {
    int limit = 60,
  }) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Future<void> sendMessage({
    required String convId,
    required String senderId,
    required String text,
  }) async {
    final convRef = _db.collection('conversations').doc(convId);
    await _db.runTransaction((tx) async {
      final convSnap = await tx.get(convRef);
      final conv = convSnap.data() ?? {};
      final memberIds = List<String>.from(conv['memberIds'] ?? []);
      final now = FieldValue.serverTimestamp();

      tx.set(convRef.collection('messages').doc(_rid('msg')), {
        'senderId': senderId,
        'text': text,
        'createdAt': now,
      });
      final update = <String, dynamic>{'lastAt': now, 'lastText': text};
      for (var mid in memberIds) {
        if (mid != senderId) update['unreadBy.$mid'] = FieldValue.increment(1);
      }
      tx.update(convRef, update);
    });
  }

  static Future<void> blockUser({
    required String ownerId,
    required String otherId,
    required String otherName,
  }) async {
    await _db
        .collection('users')
        .doc(ownerId)
        .collection('blocks')
        .doc(otherId)
        .set({
          "otherId": otherId,
          "otherName": otherName,
          "createdAt": FieldValue.serverTimestamp(),
          "banned": false,
          "suspendedUntil": null,
        });
  }

  static Future<void> unblockUser({
    required String ownerId,
    required String otherId,
  }) async {
    await _db
        .collection('users')
        .doc(ownerId)
        .collection('blocks')
        .doc(otherId)
        .delete();
  }

  static Future<bool> isBlockedEitherWay({
    required String meId,
    required String otherId,
  }) async {
    final a = await _db
        .collection('users')
        .doc(meId)
        .collection('blocks')
        .doc(otherId)
        .get();
    if (a.exists) return true;
    final b = await _db
        .collection('users')
        .doc(otherId)
        .collection('blocks')
        .doc(meId)
        .get();
    return b.exists;
  }

  static Future<void> createReport({
    required String reporterId,
    required String reporterName,
    required String targetId,
    required String targetName,
    required String targetType,
    required String reason,
    String? secretId,
    String? convId,
    String? snapshotText,
  }) async {
    if (reason.trim().isEmpty) return;
    await _db.collection('reports').doc(_rid("rep")).set({
      "reporterId": reporterId,
      "reporterName": reporterName,
      "targetId": targetId,
      "targetName": targetName,
      "targetType": targetType,
      "reason": reason.length > 120 ? reason.substring(0, 120) : reason,
      "secretId": secretId,
      "convId": convId,
      "snapshotText": snapshotText,
      "status": "open",
      "createdAt": FieldValue.serverTimestamp(),
      "banned": false,
      "suspendedUntil": null,
    });
  }
}
