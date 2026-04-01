import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../models/viral_share_resolution.dart';

class ViralLoopService {
  ViralLoopService._();

  static final ViralLoopService instance = ViralLoopService._();

  static const String _pendingTokenKey = 'viral_pending_share_token';
  static const String _pendingOwnerUidKey = 'viral_pending_share_owner_uid';
  static const String _pendingSecretIdKey = 'viral_pending_share_secret_id';
  static const String _pendingPreviewTextKey =
      'viral_pending_share_preview_text';

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _appLinks = AppLinks();
    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null) {
      await handleIncomingUri(initialUri);
    }
    _sub = _appLinks!.uriLinkStream.listen((uri) async {
      await handleIncomingUri(uri);
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }

  Future<String> createSecretShareLink({
    required String secretId,
    required String previewText,
    String? source,
  }) async {
    final callable = _functions.httpsCallable('createSecretShareLink');
    final result = await callable.call({
      'secretId': secretId,
      'previewText': previewText,
      'source': source ?? 'app',
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['url'] ?? '').toString();
  }

  Future<void> shareSecret({
    required String secretId,
    required String previewText,
    String? source,
  }) async {
    final url = await createSecretShareLink(
      secretId: secretId,
      previewText: previewText,
      source: source,
    );
    await _analytics.logEvent(
      name: 'secret_share_link_created',
      parameters: {'secret_id': secretId, 'source': source ?? 'app'},
    );
    await Share.share('$previewText\n\n$url');
    await _analytics.logEvent(
      name: 'secret_share_sheet_opened',
      parameters: {'secret_id': secretId, 'source': source ?? 'app'},
    );
  }

  Future<ViralShareResolution?> handleIncomingUri(Uri uri) async {
    final token = uri.queryParameters['vt'];
    if (token == null || token.isEmpty) {
      return null;
    }
    final callable = _functions.httpsCallable('resolveSecretShareLink');
    final result = await callable.call({'token': token});
    final resolution = ViralShareResolution.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
    if (!resolution.ok) {
      return resolution;
    }
    await _savePendingResolution(resolution);
    await _analytics.logEvent(
      name: 'secret_share_link_opened',
      parameters: {
        'secret_id': resolution.secretId,
        'owner_uid': resolution.ownerUid,
      },
    );
    return resolution;
  }

  Future<ViralShareResolution?> getPendingResolution() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingTokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    return ViralShareResolution(
      ok: true,
      token: token,
      ownerUid: prefs.getString(_pendingOwnerUidKey) ?? '',
      secretId: prefs.getString(_pendingSecretIdKey) ?? '',
      previewText: prefs.getString(_pendingPreviewTextKey) ?? '',
      alreadyClaimed: false,
      ownerIsCurrentUser:
          _auth.currentUser?.uid ==
          (prefs.getString(_pendingOwnerUidKey) ?? ''),
    );
  }

  Future<void> clearPendingResolution() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingTokenKey);
    await prefs.remove(_pendingOwnerUidKey);
    await prefs.remove(_pendingSecretIdKey);
    await prefs.remove(_pendingPreviewTextKey);
  }

  Future<bool> claimPendingShareAttribution({String? trigger}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final pending = await getPendingResolution();
    if (pending == null) return false;
    if (pending.ownerUid == user.uid) {
      await clearPendingResolution();
      return false;
    }
    final callable = _functions.httpsCallable('claimSecretShareAttribution');
    final result = await callable.call({
      'token': pending.token,
      'trigger': trigger ?? 'manual_claim',
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final ok = data['ok'] == true;
    if (ok) {
      await _analytics.logEvent(
        name: 'secret_share_claimed',
        parameters: {
          'secret_id': pending.secretId,
          'owner_uid': pending.ownerUid,
          'trigger': trigger ?? 'manual_claim',
        },
      );
      await clearPendingResolution();
    }
    return ok;
  }

  Future<bool> qualifyPendingShareAttribution({String? trigger}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final pending = await getPendingResolution();
    if (pending == null) return false;
    if (pending.ownerUid == user.uid) {
      await clearPendingResolution();
      return false;
    }
    final callable = _functions.httpsCallable('qualifySecretShareAttribution');
    final result = await callable.call({
      'token': pending.token,
      'trigger': trigger ?? 'qualified_action',
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final ok = data['ok'] == true;
    if (ok) {
      await _analytics.logEvent(
        name: 'secret_share_qualified',
        parameters: {
          'secret_id': pending.secretId,
          'owner_uid': pending.ownerUid,
          'trigger': trigger ?? 'qualified_action',
        },
      );
      await clearPendingResolution();
    }
    return ok;
  }

  Future<void> markQualifiedAction({
    required String action,
    String? secretId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('growth_events').add({
      'uid': user.uid,
      'action': action,
      'secretId': secretId,
      'createdAt': FieldValue.serverTimestamp(),
      'source': kIsWeb ? 'web' : 'app',
    });
    final parameters = <String, Object>{'action': action};
    if (secretId != null && secretId.isNotEmpty) {
      parameters['secret_id'] = secretId;
    }
    await _analytics.logEvent(
      name: 'growth_qualified_action',
      parameters: parameters,
    );
  }

  Future<void> _savePendingResolution(ViralShareResolution resolution) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingTokenKey, resolution.token);
    await prefs.setString(_pendingOwnerUidKey, resolution.ownerUid);
    await prefs.setString(_pendingSecretIdKey, resolution.secretId);
    await prefs.setString(_pendingPreviewTextKey, resolution.previewText);
  }
}
