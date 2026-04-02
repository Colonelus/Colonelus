import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class CrabService {
  static final _db = FirebaseFirestore.instance;
  static final _rnd = Random();

  static Future<void> checkCrabStatus() async {
    final docRef = _db.collection('system').doc('crab_drop');
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final now = DateTime.now();

        if (!snap.exists) {
          tx.set(docRef, {
            'isActive': true,
            'expiresAt': Timestamp.fromDate(
              now.add(const Duration(seconds: 15)),
            ),
            'nextSpawnTime': Timestamp.fromDate(
              now.add(const Duration(hours: 6)),
            ),
            'claimedBy': [],
          });
          return;
        }

        final data = snap.data()!;
        final nextSpawnTime = (data['nextSpawnTime'] as Timestamp?)?.toDate();
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final isActive = data['isActive'] ?? false;

        if (nextSpawnTime != null && now.isAfter(nextSpawnTime)) {
          tx.update(docRef, {
            'isActive': true,
            'expiresAt': Timestamp.fromDate(
              now.add(const Duration(seconds: 15)),
            ),
            'nextSpawnTime': Timestamp.fromDate(
              now.add(const Duration(hours: 6)),
            ),
            'claimedBy': [],
          });
        } else if (isActive && expiresAt != null && now.isAfter(expiresAt)) {
          tx.update(docRef, {'isActive': false});
        }
      });
    } catch (_) {}
  }

  static Future<int> claimCrab() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Giriş yapmadınız.");

    final docRef = _db.collection('system').doc('crab_drop');
    final userRef = _db.collection('users').doc(uid);

    return await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception("Sistem hatası.");

      final data = snap.data()!;
      final isActive = data['isActive'] ?? false;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      List claimedBy = List.from(data['claimedBy'] ?? []);

      if (!isActive ||
          (expiresAt != null && DateTime.now().isAfter(expiresAt))) {
        throw Exception("Yengeç çoktan kaçtı!");
      }
      if (claimedBy.length >= 10) {
        throw Exception("Yengeci başkaları kaptı!");
      }
      if (claimedBy.contains(uid)) {
        throw Exception("Bu yengeci zaten yakaladın!");
      }

      claimedBy.add(uid);
      bool shouldDeactivate = claimedBy.length >= 10;

      tx.update(docRef, {
        'claimedBy': claimedBy,
        if (shouldDeactivate) 'isActive': false,
      });

      int roll = _rnd.nextInt(100);
      int reward = 10;
      if (roll < 85) {
        reward = 10;
      } else if (roll < 95) {
        reward = 25;
      } else {
        reward = 50;
      }

      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        int currentInci = userSnap.data()?['inci'] ?? 0;
        tx.update(userRef, {'inci': currentInci + reward});
      }

      return reward;
    });
  }
}
