import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InciMigrationService {
  static Future<void> run() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    if (data['inciMigrationDone'] == true) return;

    await ref.set({
      'inci': 0,
      'inciMigrationDone': true,
    }, SetOptions(merge: true));
  }
}
