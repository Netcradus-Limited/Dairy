// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation displaying a desktop/browser notification via Web Notification API.
void showWebNotification({
  required String title,
  required String body,
  String? icon,
  String? tag,
  Map<String, dynamic>? data,
  void Function()? onClick,
}) {
  try {
    if (!html.Notification.supported) {
      debugPrint('[WEB NOTIFICATION] Notifications are not supported in this browser.');
      return;
    }
    if (html.Notification.permission != 'granted') {
      debugPrint('[WEB NOTIFICATION] Permission not granted: ${html.Notification.permission}');
      return;
    }

    final notif = html.Notification(
      title,
      body: body,
      icon: icon ?? '/favicon.png',
      tag: tag,
    );

    if (onClick != null) {
      notif.onClick.listen((_) {
        try {
          (html.window as dynamic).focus();
        } catch (_) {}
        onClick();
      });
    }
  } catch (e) {
    debugPrint('[WEB NOTIFICATION] Error displaying notification: $e');
  }
}
