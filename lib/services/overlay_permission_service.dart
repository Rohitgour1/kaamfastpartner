import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:kaamfast_partner/l10n/app_strings.dart';
import 'package:kaamfast_partner/services/job_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayPermissionService {
  OverlayPermissionService._();
  static final instance = OverlayPermissionService._();

  static const prefKey = 'overlay_display_enabled';

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<bool> isPermissionGranted() async {
    if (!isAndroid) return false;
    return FlutterOverlayWindow.isPermissionGranted();
  }

  /// Opens Android "Display over other apps" settings.
  /// Always opens the system screen so the user can enable/disable overlay.
  Future<void> openOverlaySettings() async {
    if (!isAndroid) return;
    await FlutterOverlayWindow.requestPermission();
  }

  /// Opens settings only when not granted yet. Returns whether permission is granted after.
  Future<bool> requestPermission() async {
    if (!isAndroid) return false;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    await openOverlaySettings();
    return FlutterOverlayWindow.isPermissionGranted();
  }

  Future<bool> isPreferenceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  Future<void> setPreferenceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }

  Future<bool> isOverlayActive() async {
    if (!isAndroid) return false;
    return FlutterOverlayWindow.isActive();
  }

  Future<void> showOnlineBubble({required String partnerName}) async {
    if (!isAndroid) return;
    final allowed = await isPermissionGranted();
    if (!allowed) return;

    final active = await isOverlayActive();
    if (active) {
      await FlutterOverlayWindow.shareData({'status': 'online', 'name': partnerName});
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      height: 140,
      width: 140,
      alignment: OverlayAlignment.centerRight,
      enableDrag: true,
      overlayTitle: AppStrings.tr('Kaam Fast Partner'),
      overlayContent: AppStrings.tr('You are online'),
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
    );
    await JobAlert.attachOverlayLaunchChannel();
    await FlutterOverlayWindow.shareData({'status': 'online', 'name': partnerName});
  }

  Future<void> hideBubble() async {
    if (!isAndroid) return;
    final active = await isOverlayActive();
    if (active) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// Call after online toggle / preference change.
  Future<void> syncWithOnlineState({
    required bool isOnline,
    required String partnerName,
  }) async {
    if (!isAndroid) return;
    final prefOn = await isPreferenceEnabled();
    final permitted = await isPermissionGranted();
    if (isOnline && prefOn && permitted) {
      await showOnlineBubble(partnerName: partnerName);
    } else {
      await hideBubble();
    }
  }
}
