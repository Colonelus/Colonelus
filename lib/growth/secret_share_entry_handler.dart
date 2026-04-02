import 'package:firebase_auth/firebase_auth.dart';

import 'secret_share_bootstrap.dart';
import 'secret_share_claim_store.dart';
import 'viral_loop_models.dart';
import 'viral_loop_service.dart';

class SecretShareEntryHandler {
  SecretShareEntryHandler._();

  static Future<SecretShareResolveResult?> consumeIncomingLink() async {
    final shareId = SecretShareBootstrap.instance.takeShareId();
    if (shareId == null) return null;
    final resolved = await ViralLoopService.resolveSecretShareLink(shareId: shareId);
    if (!resolved.ok) return resolved;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return resolved;
    }
    if (resolved.ownerUid == user.uid) {
      return resolved;
    }
    await SecretShareClaimStore.savePendingShareId(resolved.shareId);
    return resolved;
  }

  static Future<SecretShareClaimResult?> claimIfPossible() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final shareId = await SecretShareClaimStore.getPendingShareId();
    if (shareId == null) return null;
    final result = await ViralLoopService.claimSecretShareAttribution(shareId: shareId);
    if (result.ok && result.claimed) {
      await SecretShareClaimStore.clearPendingShareId();
    }
    return result;
  }

  static Future<SecretShareQualifyResult?> qualifyIfPossible({
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final shareId = await SecretShareClaimStore.getPendingShareId();
    if (shareId == null) return null;
    final result = await ViralLoopService.qualifySecretShareAttribution(
      shareId: shareId,
      action: action,
    );
    if (result.ok && result.rewarded) {
      await SecretShareClaimStore.clearPendingShareId();
    }
    return result;
  }
}
