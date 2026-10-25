import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:kaamfast_partner/services/job_alert.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (JobAlert.isJobPayload(message.data, type: message.data['type'])) {
    await JobAlert.ringAndOpen(openApp: true);
  }
}

class PushService {
  PushService._();

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
          .timeout(const Duration(seconds: 8));
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          )
          .timeout(const Duration(seconds: 5));
      _ready = true;
    } catch (e) {
      debugPrint('Push init skipped: $e');
    }
  }

  static Future<String?> token() async {
    try {
      await init();
      return await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('FCM token failed: $e');
      return null;
    }
  }

  static Stream<RemoteMessage> get foreground => FirebaseMessaging.onMessage;
  static Stream<RemoteMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp;

  static Future<RemoteMessage?> initialMessage() async {
    try {
      await init();
      return FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      return null;
    }
  }
}
