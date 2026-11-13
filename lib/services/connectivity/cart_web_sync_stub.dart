import 'dart:async';
import 'package:flutter/foundation.dart';

/// No-op implementation for non-web environments (Android, iOS, desktop, test).
StreamSubscription? initCartWebSync(VoidCallback onSyncNeeded) {
  return null;
}
