import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = fb.FirebaseAuth.instance;

  static const String kOwnerAdminUid = 's9Vo2O5FnKZ7grNN3kRu7DUsN222';
  static const String kOwnerAdminBottleType = 'owner_diamond';
  static const String kOwnerAdminParchmentType = 'diamond';
  static const String kOwnerAdminParchmentRarity = 'diamond';

  static bool isOwnerAdminUid(String? uid) =>
      (uid ?? '').trim() == kOwnerAdminUid;

  static Map<String, dynamic> ownerAdminCosmeticsPayload() => const {
    'selectedBottle': kOwnerAdminBottleType,
    'selectedParchment': kOwnerAdminParchmentType,
    'selectedParchmentType': kOwnerAdminParchmentType,
    'selectedParchmentRarity': kOwnerAdminParchmentRarity,
    'kagitTip': kOwnerAdminParchmentType,
  };

  static String _rumuzUret() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = math.Random();
    final s = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return "sırdaş_$s";
  }

  static Future<void> ensureUserDoc() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) {
      if (isOwnerAdminUid(u.uid)) {
        await ref.set(ownerAdminCosmeticsPayload(), SetOptions(merge: true));
      }
      return;
    }
    final payload = <String, dynamic>{
      "uid": u.uid,
      "rumuz": _rumuzUret(),
      "isVip": false,
      "vipLevel": 0,
      "inci": 250,
      "createdAt": FieldValue.serverTimestamp(),
      "banned": false,
      "suspendedUntil": null,
    };
    if (isOwnerAdminUid(u.uid)) {
      payload.addAll(ownerAdminCosmeticsPayload());
    }
    await ref.set(payload);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> meStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  static Future<void> deleteAccountAndData(String uid) async {
    final batch = _db.batch();
    final secrets = await _db
        .collection('secrets')
        .where('authorId', isEqualTo: uid)
        .get();
    for (final d in secrets.docs) {
      batch.delete(d.reference);
    }
    final reqIn = await _db
        .collection('chat_requests')
        .where('secretAuthorId', isEqualTo: uid)
        .get();
    for (final d in reqIn.docs) {
      batch.delete(d.reference);
    }
    final reqOut = await _db
        .collection('chat_requests')
        .where('requesterId', isEqualTo: uid)
        .get();
    for (final d in reqOut.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('users').doc(uid));
    await batch.commit();
  }
}
