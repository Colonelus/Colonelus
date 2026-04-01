import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSounds {
  static const String channelId = 'sirdas_default_channel';
  static const String channelName = 'Sırdaş Bildirimleri';
  static const String channelDesc = 'Sırdaş bildirim kanalı';
  static const AndroidNotificationSound androidSound =
      RawResourceAndroidNotificationSound('notif_sirdas');
  static const String iosSound = 'notif_sirdas.mp3';
}
