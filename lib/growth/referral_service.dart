import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralService {
  ReferralService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyUser() {
    return _userRef.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyReferrals() {
    return _firestore
        .collection('referrals')
        .where('inviterUid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> ensureInviteCode() async {
    final callable = _functions.httpsCallable('ensureInviteCode');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['inviteCode'] ?? '').toString();
  }

  Future<void> bindReferralCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Referral code is required.',
      );
    }
    final callable = _functions.httpsCallable('bindReferralCode');
    await callable.call({'code': normalized});
  }

  Future<void> markQualified() async {
    final callable = _functions.httpsCallable('markReferralQualified');
    await callable.call();
  }

  Future<Map<String, dynamic>> getSummary() async {
    final callable = _functions.httpsCallable('getReferralSummary');
    final result = await callable.call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String> buildShareText() async {
    final snapshot = await _userRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final inviteCode = ((data['inviteCode'] ?? '') as String).trim();
    final baseUrl = ((data['growthInviteBaseUrl'] ?? '') as String).trim();
    final code = inviteCode.isEmpty ? await ensureInviteCode() : inviteCode;
    final uri = baseUrl.isEmpty ? '' : '$baseUrl?ref=$code';
    return [
      'Sırdaş\'a davetlisin.',
      'Kod: $code',
      if (uri.isNotEmpty) uri,
    ].join('\n');
  }
}
