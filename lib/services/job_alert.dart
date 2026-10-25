import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class JobAlert {
  JobAlert._();

  static const _channel = MethodChannel('kaamfast.partner/launch');
  static DateTime? _lastAlert;

  static bool isJobPayload(Map<String, dynamic> data, {String? title, String? type}) {
    final t = (data['type'] ?? type ?? '').toString();
    final titleText = (title ?? data['title'] ?? '').toString().toLowerCase();
    // Accepting a job sends "New job assigned" / booking.assigned / open_app.
    // That must not start the ringtone. Ring only for a new offer.
    if (t.isNotEmpty && t != 'booking.available' && t != 'job_offer') {
      return false;
    }
    if (titleText.contains('assigned')) return false;
    if (t == 'booking.available' || t == 'job_offer') return true;
    return titleText.contains('new helper') ||
        titleText.contains('new job') ||
        titleText.contains('new cleaning') ||
        titleText.contains('new laundry') ||
        titleText.contains('new delivery') ||
        titleText.contains('pickup delivery job') ||
        titleText.contains('return delivery job');
  }

  static Future<void> ringAndOpen({bool openApp = true}) async {
    final now = DateTime.now();
    if (_lastAlert != null && now.difference(_lastAlert!) < const Duration(seconds: 4)) {
      return;
    }
    _lastAlert = now;
    try {
      await _channel.invokeMethod('playJobAlert');
    } catch (_) {}
    if (openApp) {
      await openAppIfPossible();
    }
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'action': 'new_job',
          'status': 'alert',
        });
      }
    } catch (_) {}
  }

  static Future<void> openAppIfPossible() async {
    try {
      await _channel.invokeMethod('bringToForeground');
    } catch (_) {}
  }

  static Future<void> attachOverlayLaunchChannel() async {
    try {
      await _channel.invokeMethod('attachOverlayLaunch');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopJobAlert');
    } catch (_) {}
  }
}
