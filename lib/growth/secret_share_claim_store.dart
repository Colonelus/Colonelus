import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecretShareClaimStore {
  SecretShareClaimStore._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> savePendingShareId(String shareId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'pendingSecretShareId': shareId,
      'pendingSecretShareUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String?> getPendingShareId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final value = (data?['pendingSecretShareId'] ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static Future<void> clearPendingShareId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'pendingSecretShareId': FieldValue.delete(),
      'pendingSecretShareUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
