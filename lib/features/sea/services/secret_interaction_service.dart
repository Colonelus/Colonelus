import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/services/auth_profile_service.dart';

class SecretInteractionService {
  static final _db = FirebaseFirestore.instance;

  static String _rid(String prefix) =>
      "${prefix}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}";

  static String _normalizeParchmentType(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'paper_classic':
      case 'classic':
      case 'normal':
        return 'normal';
      case 'paper_gold':
      case 'gold':
        return 'gold';
      case 'paper_dark':
      case 'dark':
      case 'obsidian':
        return 'obsidian';
      case 'paper_white':
      case 'white':
      case 'royal':
        return 'royal';
      case 'paper_flower':
      case 'flower':
      case 'rose':
        return 'rose';
      case 'emerald':
        return 'emerald';
      case 'ancient':
        return 'ancient';
      case 'paper_diamond':
      case 'diamond':
        return 'diamond';
      default:
        return 'normal';
    }
  }

  static String _parchmentRarityForType(String? raw) {
    switch (_normalizeParchmentType(raw)) {
      case 'diamond':
        return 'diamond';
      case 'gold':
        return 'legendary';
      case 'obsidian':
      case 'royal':
        return 'epic';
      case 'ancient':
      case 'emerald':
      case 'rose':
        return 'rare';
      case 'normal':
      default:
        return 'common';
    }
  }

  static Future<void> createSecret({
    required String uid,
    required String rumuz,
    required bool isVip,
    required String content,
  }) async {
    final tip = isVip ? 'tekne' : 'sise';
    final rnd = math.Random();
    final secretRef = _db.collection('secrets').doc(_rid("secret"));
    final userRef = _db.collection('users').doc(uid);

    final userSnap = await userRef.get();
    final isOwnerAdmin = AuthProfileService.isOwnerAdminUid(uid);

    final selectedBottle = isOwnerAdmin
        ? AuthProfileService.kOwnerAdminBottleType
        : ((userSnap.data()?['selectedBottle'] as String?) ?? 'blue');

    final selectedParchment = isOwnerAdmin
        ? AuthProfileService.kOwnerAdminParchmentType
        : _normalizeParchmentType(
            (userSnap.data()?['selectedParchment'] as String?) ??
                (userSnap.data()?['selectedParchmentType'] as String?) ??
                (userSnap.data()?['selectedKagitTip'] as String?) ??
                (userSnap.data()?['kagitTip'] as String?) ??
                'normal',
          );

    final selectedParchmentRarity = isOwnerAdmin
        ? AuthProfileService.kOwnerAdminParchmentRarity
        : _parchmentRarityForType(selectedParchment);

    final batch = _db.batch();

    batch.set(secretRef, {
      "authorId": uid,
      "authorName": rumuz,
      "authorIsVip": isVip,
      "content": content,
      "tip": tip,
      "createdAt": FieldValue.serverTimestamp(),
      "banned": false,
      "suspendedUntil": null,
      "expiresAt": Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      "laneIndex": rnd.nextInt(6),
      "xOffset": 40.0 + rnd.nextInt(180),
      "speedMul": isVip
          ? (0.86 + rnd.nextDouble() * 0.10)
          : (0.92 + rnd.nextDouble() * 0.16),
      "phase": rnd.nextDouble() * math.pi * 2,
      "siseRenk": "0xFF18FFFF",
      "kagitTip": selectedParchment,
      "paperStyleId": selectedParchment,
      "cardStyleId": selectedParchment,
      "parchmentType": selectedParchment,
      "parchmentRarity": selectedParchmentRarity,
      "bottleType": selectedBottle,
    });

    final userUpdate = <String, dynamic>{"inci": FieldValue.increment(3)};
    if (isOwnerAdmin) {
      userUpdate.addAll(AuthProfileService.ownerAdminCosmeticsPayload());
    }
    batch.set(userRef, userUpdate, SetOptions(merge: true));

    await batch.commit();
  }
}
