// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation listening for cross-tab localStorage mutations
/// and document visibility/focus transitions.
StreamSubscription? initCartWebSync(VoidCallback onSyncNeeded) {
  try {
    html.window.onStorage.listen((event) {
      if (event.key == null || event.key == 'flutter.cart_items') {
        onSyncNeeded();
      }
    });

    html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') {
        onSyncNeeded();
      }
    });
    return null;
  } catch (e) {
    debugPrint('[CART WEB SYNC] Initialization error: $e');
    return null;
  }
}
