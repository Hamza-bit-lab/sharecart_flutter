import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
/// Android channel id — keep in sync with [AndroidManifest] default FCM channel meta-data.
const String kFcmAlertsChannelId = 'sharecart_alerts_v1';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

final Int64List kAlertVibrationPattern = Int64List.fromList(<int>[0, 280, 120, 280]);

/// Call once after [Firebase.initializeApp]. Sets up channels (Android) and permissions.
Future<void> initializeLocalNotificationsPlugin() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _localNotifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          kFcmAlertsChannelId,
          'Alerts',
          description: 'List updates and nudges',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: kAlertVibrationPattern,
          showBadge: true,
        ),
      );
    }
  }
}

/// Foreground / background handler: show banner on both Android and iOS.
Future<void> showLocalPushFromMessage({
  required int id,
  required String title,
  required String body,
}) async {
  await _localNotifications.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        kFcmAlertsChannelId,
        'Alerts',
        channelDescription: 'List updates and nudges',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: kAlertVibrationPattern,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        ticker: title,
        channelShowBadge: true,
        styleInformation: body.length > 60 ? BigTextStyleInformation(body, contentTitle: title) : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await initializeLocalNotificationsPlugin();
  if (message.notification != null) return;
  final data = message.data;
  final title = data['title'] as String? ?? data['subject'] as String? ?? data['gcm_title'] as String?;
  final body = data['body'] as String? ??
      data['message'] as String? ??
      data['content'] as String? ??
      data['alert'] as String?;
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
  await showLocalPushFromMessage(
    id: message.hashCode,
    title: (title != null && title.isNotEmpty) ? title : 'Share Cart',
    body: body ?? '',
  );
}
