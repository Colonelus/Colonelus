import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class DropService {
  static final Random _rnd = Random();

  static Future<Map<String, dynamic>?> openDropBox() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final int roll = _rnd.nextInt(100);
    int rewardInci = 0;
    String rewardName = "";
    bool isVipReward = false;

    if (roll < 50) {
      rewardInci = 10;
      rewardName = "Deniz Kabuğu (10 İnci)";
    } else if (roll < 85) {
      rewardInci = 50;
      rewardName = "Kayıp Define (50 İnci)";
    } else if (roll < 98) {
      rewardInci = 200;
      rewardName = "Kraliyet İncisi (200 İnci)";
    } else {
      isVipReward = true;
      rewardName = "1 Günlük VIP Sırdaş";
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final currentInci = data['inci'] ?? 0;

      Map<String, dynamic> updates = {};

      if (isVipReward) {
        updates['isVip'] = true;
      } else {
        updates['inci'] = currentInci + rewardInci;
      }

      updates['lastDropDate'] = FieldValue.serverTimestamp();

      tx.update(docRef, updates);
    });

    return {'name': rewardName, 'inci': rewardInci, 'isVip': isVipReward};
  }
}
