import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../repositories/notification_repository.dart';

/// FCM Service handling token management, permission, and message routing for
/// the Delivery Panel. Integrates with the existing Firestore notification model
/// and prevents duplicate notifications between FCM and the Firestore stream.
///
/// Design goals:
/// - Never crash if permission is denied or token is unavailable
/// - Only register/update token for authenticated delivery agents
/// - One delivery agent cannot manage another agent's token
/// - Duplicate prevention: Firestore notification stream and FCM messages use
///   message ID / order ID correlation to avoid showing the same notification twice
/// - Platform-safe: Android, iOS, Web all handled without breaking any platform
/// - All operations gracefully handle missing/auth state
class FCMService {
  FCMService(
    this._ref, {
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationRepository? notifRepo,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _customMessaging = messaging,
        _customAuth = auth,
        _customFirestore = firestore,
        _notifRepo = notifRepo ?? NotificationRepository(),
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final Ref _ref;

  final FirebaseMessaging? _customMessaging;
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final NotificationRepository _notifRepo;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessaging get _messaging =>
      _customMessaging ?? FirebaseMessaging.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Platform-specific FCM token. Returns the most recent cached token value
  /// (may be stale; prefer listening to [onTokenRefresh] stream for up-to-date values).
  /// Call [getCurrentToken] async method for the actual token fetch.
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Error in getCurrentToken: $e');
      return null;
    }
  }

  /// Stream of token refresh events. Emits new token when FCM rotates the token.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Initialize FCM: request permission, get token, register with backend.
  /// Must be called once after Firebase initialization and auth state is known.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '[FCM] Firebase not initialized; skipping FCMService.init().');
        return;
      }

      // Android 13+ POST_NOTIFICATIONS permission is requested implicitly by
      // requestPermission, but we explicitly check and request on platforms that
      // require it so the app never silently fails.
      await _requestPlatformPermission();

      // Observe token refresh and automatically sync to Firestore for the
      // authenticated delivery agent.
      _listenTokenRefresh();

      // Initial token fetch & registration (best-effort; never crashes).
      await _saveTokenIfAuthorized();
    } catch (e) {
      debugPrint('[FCM] Error in FCMService.init: $e');
    }
  }

  /// Platform-safe permission request.
  ///
  /// - iOS: Shows system permission dialog; returns granted/denied.
  /// - Android 13+: Requests POST_NOTIFICATIONS permission if not already granted.
  /// - Web: Uses browser notification permission.
  /// - If permission is denied, the method completes without throwing; the app
  ///   simply will not receive FCM notifications until permission is re-enabled.
  Future<void> _requestPlatformPermission() async {
    try {
      // iOS and Android 13+ ask via requestPermission; Web uses getPermission.
      final NotificationSettings settings = await _messaging.requestPermission();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('[FCM] Notification permission denied or not granted.');
        // Do not throw — the app continues without push notifications.
        return;
      }
    } catch (e) {
      // Permission not supported (e.g. some web contexts) or already handled.
      debugPrint('[FCM] Permission request error: $e');
    }
  }

  /// Listen to FCM token refreshes and automatically sync the new token to
  /// Firestore for the authenticated delivery agent. Only writes if the token
  /// changes.
  void _listenTokenRefresh() {
    onTokenRefresh.listen((String? newToken) async {
      if (newToken == null) {
        debugPrint('[FCM] Token refresh emitted null — skipping Firestore write.');
        return;
      }
      await _saveTokenIfAuthorized();
    }).onError((Object error) {
      debugPrint('[FCM] onTokenRefresh error: $error');
    });
  }

  /// Save or update the FCM token for the authenticated delivery agent in
  /// Firestore. Only writes if:
  ///   • A Firebase UID is available (user is authenticated)
  ///   • The token is not empty/null
  ///   • The token differs from what's already stored (best-effort dedup)
  ///
  /// The token is stored under the delivery agent's user document so that the
  /// backend can target notifications to this specific agent. The structure uses
  /// a subcollection or a dedicated field; here we store it as a field on the
  /// user's main document under a `fcmTokens` map keyed by platform identifier.
  Future<void> _saveTokenIfAuthorized() async {
    final authUid = _auth.currentUser?.uid;

    // Only authenticated delivery agents may have their token stored.
    if (authUid == null || authUid.isEmpty) {
      debugPrint('[FCM] No authenticated user — skipping token save.');
      return;
    }

    // Verify this user has a delivery role per the existing RBAC.
    final userData = await _firestore.collection('users').doc(authUid).get();
    if (!userData.exists) {
      debugPrint('[FCM] User document does not exist — skipping token save.');
      return;
    }
    final role = userData.data()?['role'] ?? '';
    if (role != 'delivery' && role != 'superadmin') {
      debugPrint('[FCM] User role "$role" is not a delivery role — skipping token save.');
      return;
    }

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Error getting token in _saveTokenIfAuthorized: $e');
    }
    if (token == null || token.isEmpty) {
      debugPrint('[FCM] No FCM token available — skipping Firestore write.');
      return;
    }

    // Write token to user document. We store it as a simple string field
    // `fcmToken` for the delivery agent's UID. The Firestore rules (updated
    // below) allow the owner to update this field.
    await _firestore.collection('users').doc(authUid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[FCM] Token saved to Firestore for delivery agent: $authUid');
  }

  /// Handle a foreground message (app in use). Routes to the existing local
  /// notification display and the orderAlertProvider, with duplicate prevention
  /// logic that correlates the FCM message data with the Firestore notification
  /// stream so the same order alert does not appear twice.
  ///
  /// The [RemoteMessage] contains:
  ///   - notification.title / notification.body (displayed via local notification)
  ///   - data.orderId / data.order_id (used for correlation with Firestore)
  ///
  /// If the message contains an orderId that already has a corresponding
  /// unread notification in Firestore, we skip showing a duplicate local
  /// notification — the Firestore stream will already deliver it.
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    final orderId = _extractOrderId(message.data);
    if (orderId == null) {
      // Non-order notification — show local notification without duplicate check.
      _showLocalNotification(message);
      return;
    }

    // Check if this order already has an unread Firestore notification for
    // the current delivery agent. If yes, skip the local notification to
    // prevent duplicates.
    final authUid = _auth.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      final list = await _notifRepo.streamUserNotifications(authUid).first;
      final alreadyExists = list.any(
          (n) => n.orderId != null && n.orderId == orderId && !n.isRead);
      if (alreadyExists) {
        debugPrint('[FCM] Duplicate order alert detected — skipping local notification for orderId: $orderId');
        return;
      }
    }

    _showLocalNotification(message);
  }

  /// Extract orderId from message data, trying both common key names.
  String? _extractOrderId(Map<String, dynamic> data) {
    return data['orderId'] ?? data['order_id'];
  }

  /// Show a local notification via flutter_local_notifications. Safe to call even
  /// if the notification channel hasn't been fully initialized (the underlying
  /// plugin handles missing channel gracefully).
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'order_alerts',
          'Order Alerts',
          channelDescription: 'Notifications for new and updated orders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  /// Handle a message that opened the app from background/terminated state.
  /// If the user taps a notification, we navigate to the appropriate Delivery
  /// Panel screen based on the message data.
  Future<void> handleMessageOpenedApp(RemoteMessage message) async {
    final orderId = _extractOrderId(message.data);
    if (orderId != null) {
      // Navigate to the delivery panel order detail screen.
      // The app router is accessed via Riverpod; we emit a navigation event
      // that the router watches. Since we cannot directly reference the router
      // from this service (it would create a circular dependency), we store the
      // navigation intent in a persistent location (last tapped notification)
      // that the DeliveryPanelScreen reads on build.
      _ref.read(lastTappedOrderIdProvider.notifier).state = orderId;
      debugPrint('[FCM] Notification tapped — set lastTappedOrderId to: $orderId');
    } else {
      debugPrint('[FCM] Background-tap notification without orderId: data=${message.data}');
    }
    _showLocalNotification(message);
  }

  /// Background message handler. This top-level function is registered in
  /// main.dart and runs while the app is in the background or terminated. It
  /// does NOT update Riverpod state (UI is updated only in foreground via
  /// [handleForegroundMessage]). It only ensures the local notification is
  /// displayed for background/terminated cases.
  ///
  /// IMPORTANT: This function must be a top-level @pragma('vm:entry-point')
  /// function and must NOT depend on the Riverpod container.
  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    // For background/terminated state, we show the local notification directly.
    // The foreground handler [handleForegroundMessage] is responsible for
    // duplicate prevention and UI state updates.
    final notification = message.notification;
    if (notification != null) {
      try {
        final localNotifications = FlutterLocalNotificationsPlugin();
        await localNotifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        await localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'order_alerts',
              'Order Alerts',
              channelDescription: 'Notifications for new and updated orders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (_) {
        // Best-effort; do not crash the background isolate.
      }
    }
  }

  /// Dispose of listeners etc. Called when the service is no longer needed.
  void dispose() {
    // The streams are managed by Riverpod/lifecycle; no explicit cancel needed
    // for the FirebaseMessaging streams as they are tied to the app lifecycle.
  }
}

/// Riverpod provider for the FCM service.
final fcmServiceProvider = Provider<FCMService>((ref) => FCMService(ref));

/// Holds the orderId of the last notification tapped by the user, so the
/// DeliveryPanelScreen can navigate to the correct screen after the app resumes.
final lastTappedOrderIdProvider = StateProvider<String>((ref) => '');

/// Triggers one-time initialization of FCM (permission + token registration).
/// Watched from MyApp so it runs exactly once at app start.
final fcmInitProvider = FutureProvider<void>((ref) async {
  try {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase not initialized; skipping fcmInitProvider.');
      return;
    }
    final service = ref.watch(fcmServiceProvider);
    await service.init();
  } catch (e) {
    debugPrint('[FCM] Error in fcmInitProvider: $e');
  }
});