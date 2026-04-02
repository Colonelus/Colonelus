import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_enums.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static String _rid(String prefix) =>
      "${prefix}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}";

  static Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestsStream(
    String uid,
  ) {
    return _db
        .collection('chat_requests')
        .where('secretAuthorId', isEqualTo: uid)
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
        .limit(80)
        .snapshots();
  }

  static Future<void> markConversationRead({
    required String convId,
    required String userId,
  }) async {
    await _db.collection('conversations').doc(convId).set({
      'unreadBy': {userId: 0},
    }, SetOptions(merge: true));
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
        safeSecretAuthorId == safeRequesterId) {
      return;
    }

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
      "createdAt": FieldValue.serverTimestamp(),
      "banned": false,
      "suspendedUntil": null,
      "decisionAt": null,
      "conversationId": null,
    };

    final existing = await _db
        .collection('chat_requests')
        .where('secretId', isEqualTo: safeSecretId)
        .where('requesterId', isEqualTo: safeRequesterId)
        .limit(10)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      if ((data['secretAuthorId'] as String?)?.trim() != safeSecretAuthorId) {
        continue;
      }
      if (data['status'] == RequestStatus.pending.name) {
        await doc.reference.set(basePayload, SetOptions(merge: true));
        return;
      }
      final existingConvId = (data['conversationId'] as String?)?.trim() ?? '';
      if (data['status'] == RequestStatus.accepted.name &&
          existingConvId.isNotEmpty) {
        await doc.reference.set({
          "secretAuthorName": basePayload["secretAuthorName"],
          "secretSnapshotText": basePayload["secretSnapshotText"],
          "requesterName": basePayload["requesterName"],
          "firstMessageText": basePayload["firstMessageText"],
        }, SetOptions(merge: true));
        return;
      }
    }

    await _db.collection('chat_requests').doc(_rid("req")).set(basePayload);
  }

  static Future<String?> acceptRequest({
    required String requestId,
    required String accepterId,
  }) async {
    final reqRef = _db.collection('chat_requests').doc(requestId);
    Map<String, dynamic>? acceptedRequest;
    final convId = await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      final req = reqSnap.data();
      if (req == null) return null;
      if (req['status'] != RequestStatus.pending.name) return null;
      if (req['secretAuthorId'] != accepterId) return null;

      acceptedRequest = Map<String, dynamic>.from(req);

      final existingConvId = (req['conversationId'] as String?)?.trim();
      if (existingConvId != null && existingConvId.isNotEmpty) {
        final existingConv = await tx.get(
          _db.collection('conversations').doc(existingConvId),
        );
        if (existingConv.exists) {
          tx.update(reqRef, {
            'status': RequestStatus.accepted.name,
            'decisionAt': FieldValue.serverTimestamp(),
          });
          return existingConvId;
        }
      }

      final convId = _rid('conv');
      final convRef = _db.collection('conversations').doc(convId);
      final now = FieldValue.serverTimestamp();
      final firstMessageText =
          (req['firstMessageText'] as String?)?.trim() ?? '';

      tx.set(convRef, {
        'memberIds': [req['secretAuthorId'], req['requesterId']],
        'memberNames': {
          req['secretAuthorId']: req['secretAuthorName'],
          req['requesterId']: req['requesterName'],
        },
        'createdAt': now,
        'lastAt': now,
        'lastText': firstMessageText,
        'unreadBy': {req['secretAuthorId']: 0, req['requesterId']: 0},
      });

      tx.update(reqRef, {
        'status': RequestStatus.accepted.name,
        'decisionAt': now,
        'conversationId': convId,
      });

      return convId;
    });

    if (convId == null) return null;

    final req = acceptedRequest;
    final firstMessageText =
        (req?['firstMessageText'] as String?)?.trim() ?? '';
    final requesterId = (req?['requesterId'] as String?)?.trim() ?? '';
    if (firstMessageText.isNotEmpty && requesterId.isNotEmpty) {
      final existingFirst = await _db
          .collection('conversations')
          .doc(convId)
          .collection('messages')
          .limit(1)
          .get();
      if (existingFirst.docs.isEmpty) {
        await sendMessage(
          convId: convId,
          senderId: requesterId,
          text: firstMessageText,
        );
      }
    }

    return convId;
  }

  static Future<void> rejectRequest({
    required String requestId,
    required String rejecterId,
  }) async {
    final ref = _db.collection('chat_requests').doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data();
      if (d == null) return;
      if (d['status'] != RequestStatus.pending.name) return;
      if (d['secretAuthorId'] != rejecterId) return;
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
      if (d == null) return;
      if (d['status'] != RequestStatus.pending.name) return;
      if (d['requesterId'] != requesterId) return;
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
      final conv = convSnap.data() ?? const <String, dynamic>{};
      final memberIds = ((conv['memberIds'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      final now = FieldValue.serverTimestamp();
      tx.set(convRef.collection('messages').doc(_rid('msg')), {
        'senderId': senderId,
        'text': text,
        'createdAt': now,
        'banned': false,
        'suspendedUntil': null,
      });
      final update = <String, dynamic>{
        'lastAt': now,
        'lastText': text,
        'unreadBy.$senderId': 0,
      };
      for (final memberId in memberIds) {
        if (memberId == senderId) continue;
        update['unreadBy.$memberId'] = FieldValue.increment(1);
      }
      tx.set(convRef, update, SetOptions(merge: true));
    });
  }

  static DocumentReference<Map<String, dynamic>> _blockRef(
    String ownerId,
    String otherId,
  ) => _db.collection('users').doc(ownerId).collection('blocks').doc(otherId);

  static Stream<DocumentSnapshot<Map<String, dynamic>>> blockDocStream({
    required String ownerId,
    required String otherId,
  }) => _blockRef(ownerId, otherId).snapshots();

  static Future<void> blockUser({
    required String ownerId,
    required String otherId,
    required String otherName,
  }) async {
    await _blockRef(ownerId, otherId).set({
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
    await _blockRef(ownerId, otherId).delete();
  }

  static Future<bool> isBlockedEitherWay({
    required String meId,
    required String otherId,
  }) async {
    final a = await _blockRef(meId, otherId).get();
    if (a.exists) return true;
    final b = await _blockRef(otherId, meId).get();
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
    final r = reason.trim();
    if (r.isEmpty) return;
    await _db.collection('reports').doc(_rid("rep")).set({
      "reporterId": reporterId,
      "reporterName": reporterName,
      "targetId": targetId,
      "targetName": targetName,
      "targetType": targetType,
      "reason": r.length > 120 ? r.substring(0, 120) : r,
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
