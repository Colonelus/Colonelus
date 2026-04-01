import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/services/notification_service.dart';

StreamSubscription<fb.User?>? _authSub;
StreamSubscription<RemoteMessage>? _msgSub;
StreamSubscription<String>? _tokenSub;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reqSub;
String? _activeUid;
final Set<String> _knownPendingIds = <String>{};

void setupNotificationsBootstrap() {
  _authSub ??= fb.FirebaseAuth.instance.authStateChanges().listen((u) async {
    await NotificationService.init();
    await NotificationService.requestPermissions();

    final token = await FirebaseMessaging.instance.getToken();
    await NotificationService.onToken(token);

    _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      await NotificationService.onToken(t);
    });

    _msgSub ??= FirebaseMessaging.onMessage.listen((m) async {
      await NotificationService.showFromMessage(m);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await NotificationService.handleOpenFromMessage(initial);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((m) async {
      await NotificationService.handleOpenFromMessage(m);
    });

    await _reqSub?.cancel();
    _reqSub = null;
    _activeUid = u?.uid;
    _knownPendingIds.clear();

    if (u == null) return;

    _reqSub = FirebaseFirestore.instance
        .collection('chat_requests')
        .where('secretAuthorId', isEqualTo: u.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) async {
          if (_activeUid != u.uid) return;

          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final id = change.doc.id;
            if (!_knownPendingIds.add(id)) continue;
            final data = change.doc.data();
            final name = (data?['requesterName'] as String?) ?? 'Birisi';
            await NotificationService.showLocal(
              title: 'Yeni sohbet isteği',
              body: '$name sırrını yakaladı.',
              payload: id,
            );
          }
        });
  });
}
