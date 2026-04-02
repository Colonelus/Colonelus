import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;

    final androidInit = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    try {
      await Function.apply(
        (_fln as dynamic).initialize,
        [initSettings],
        {#onDidReceiveNotificationResponse: (dynamic r) async {}},
      );
    } catch (_) {
      await Function.apply((_fln as dynamic).initialize, [], {
        #initializationSettings: initSettings,
        #onDidReceiveNotificationResponse: (dynamic r) async {},
      });
    }

    _inited = true;
  }

  static Future<void> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final impl = Function.apply(
          (_fln as dynamic).resolvePlatformSpecificImplementation,
          [],
        );
        if (impl != null) {
          try {
            await Function.apply((impl as dynamic).requestPermissions, [], {
              #alert: true,
              #badge: true,
              #sound: true,
            });
          } catch (_) {
            await Function.apply((impl as dynamic).requestPermissions, [
              true,
              true,
              true,
            ]);
          }
        }
      } catch (_) {}
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> onToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmTokenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> showFromMessage(RemoteMessage m) async {
    final title = m.notification?.title ?? (m.data['title']?.toString() ?? '');
    final body = m.notification?.body ?? (m.data['body']?.toString() ?? '');
    if (title.isEmpty && body.isEmpty) return;

    await showLocal(
      title: title.isEmpty ? 'Sırdaş' : title,
      body: body,
      payload: m.data.isEmpty ? null : m.data.toString(),
    );
  }

  static Future<void> handleOpenFromMessage(RemoteMessage m) async {}

  static Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      'sirdas_default',
      'Sırdaş',
      channelDescription: 'Sırdaş bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notif_sirdas'),
    );

    final iosDetails = const DarwinNotificationDetails(presentSound: true);

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    try {
      await Function.apply(
        (_fln as dynamic).show,
        [id, title, body, details],
        {#payload: payload},
      );
    } catch (_) {
      await Function.apply((_fln as dynamic).show, [], {
        #id: id,
        #title: title,
        #body: body,
        #notificationDetails: details,
        #payload: payload,
      });
    }
  }
}
