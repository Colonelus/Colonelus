import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'viral_loop_models.dart';

class ViralLoopService {
  ViralLoopService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<SecretShareLinkResult> createSecretShareLink({
    required String secretId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }
    final callable = _functions.httpsCallable('createSecretShareLink');
    final result = await callable.call(<String, dynamic>{
      'secretId': secretId,
    });
    return SecretShareLinkResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  static Future<void> shareSecret({
    required String secretId,
    String? textPrefix,
  }) async {
    final result = await createSecretShareLink(secretId: secretId);
    final text = [
      if ((textPrefix ?? '').trim().isNotEmpty) textPrefix!.trim(),
      result.url,
    ].join('\n');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  static Future<SecretShareResolveResult> resolveSecretShareLink({
    required String shareId,
  }) async {
    final callable = _functions.httpsCallable('resolveSecretShareLink');
    final result = await callable.call(<String, dynamic>{
      'shareId': shareId,
    });
    return SecretShareResolveResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  static Future<SecretShareClaimResult> claimSecretShareAttribution({
    required String shareId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }
    final callable = _functions.httpsCallable('claimSecretShareAttribution');
    final result = await callable.call(<String, dynamic>{
      'shareId': shareId,
    });
    return SecretShareClaimResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  static Future<SecretShareQualifyResult> qualifySecretShareAttribution({
    required String shareId,
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }
    final callable = _functions.httpsCallable('qualifySecretShareAttribution');
    final result = await callable.call(<String, dynamic>{
      'shareId': shareId,
      'action': action,
    });
    return SecretShareQualifyResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }
}
