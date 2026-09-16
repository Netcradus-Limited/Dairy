import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fcm_service.dart';
import '../providers/notification_provider.dart';

/// Represents an incoming order-related push alert.
class OrderAlert {
  const OrderAlert({
    required this.orderId,
    this.title,
    this.body,
    this.data = const {},
  });

  final String orderId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

final orderAlertProvider = StateProvider<OrderAlert?>((ref) => null);

/// Background message handler – must be top-level and @pragma('vm:entry-point').
/// This handler runs while the app is in the background or terminated. It does NOT
/// update Riverpod state (UI updates are handled by the foreground listener in
/// [NotificationService]). It only ensures the local notification is displayed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // UI updates handled by foreground listener; this method runs while app is
  // background/terminated. Local notification displayed here so the user sees
  // an alert even when the app is not in the foreground.
}

/// Wraps Firebase Cloud Messaging and local notifications: requests permission,
/// initializes the local notification channel, and routes incoming order alerts
/// to both a local notification and the [orderAlertProvider] for the UI. Also
/// integrates with [fcmServiceProvider] for token management.
class NotificationService {
  NotificationService(
    this._ref, {
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _customMessaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final Ref _ref;

  final FirebaseMessaging? _customMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessaging get _messaging =>
      _customMessaging ?? FirebaseMessaging.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'order_alerts',
    'Order Alerts',
    description: 'Notifications for new and updated orders',
    importance: Importance.high,
  );

  /// Initializes local notifications, requests permission, and wires up the
  /// foreground / opened-app message listeners. Also initializes the FCM service
  /// for token management.
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '[NOTIF] Firebase not initialized; skipping NotificationService.init().');
        return;
      }

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      await requestPermission();

      // Wire up foreground message listener — this is where duplicate prevention
      // and UI updates happen.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Wire up opened-app listener — handles taps on notifications when app was
      // in background/terminated state.
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp);
    } catch (e) {
      debugPrint('[NOTIF] Error in NotificationService.init: $e');
    }
  }

  /// Request notification permission for iOS, Android (13+) and Web.
  Future<NotificationSettings> requestPermission() async {
    return _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  /// The current FCM registration token. Send this to your backend so it can
  /// target this device when sending order alerts. Delegates to the FCM service
  /// for integrated token management.
  Future<String?> getToken() => _messaging.getToken();

  /// Stream of token refreshes (re-upload to your backend on change).
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Handle a foreground message (app in use). Shows local notification and
  /// updates the orderAlertProvider with duplicate prevention logic. Correlates
  /// the FCM message data with the Firestore notification stream so the same
  /// order alert does not appear twice.
  void _onForegroundMessage(RemoteMessage message) {
    // Use the FCM service's integrated handler with duplicate prevention.
    // The FCM service checks Firestore for existing unread notifications
    // with the same orderId before showing a local notification.
    _onForegroundMessageWithDuplicatePrevention(message);
  }

  /// Internal foreground message handler with duplicate prevention.
  void _onForegroundMessageWithDuplicatePrevention(RemoteMessage message) {
    final orderId = _extractOrderId(message.data);
    if (orderId == null) {
      // Non-order notification — show local notification without dedup check.
      _showLocalNotification(message);
      _pushOrderAlert(message);
      return;
    }

    // Check if this order already has an unread Firestore notification for
    // the current user. If yes, skip the local notification to prevent duplicates.
    // The Firestore stream (userNotificationsStreamProvider) is the source of
    // truth; FCM is complementary.
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.isNotEmpty) {
      // We check asynchronously; if the stream hasn't loaded yet, we still show
      // the notification as a best-effort (the check is primarily to prevent
      // double-showing when the stream is active).
      _ref.read(userNotificationsStreamProvider).when(
        data: (list) {
          final alreadyExists = list.any(
            (n) =>
                n.orderId != null && n.orderId == orderId && !n.isRead,
          );
          if (!alreadyExists) {
            _showLocalNotification(message);
            _pushOrderAlert(message);
          } else {
            debugPrint(
                '[NOTIF] Duplicate order alert detected for orderId: $orderId — skipping local notification; Firestore stream is source of truth.');
          }
        },
        error: (Object error, StackTrace stackTrace) =>
            debugPrint('[NOTIF] Error checking duplicates: $error'),
        loading: () => debugPrint('[NOTIF] Loading notification check...'),
      );
    } else {
      // No authenticated user — show notification (the FCM token save will
      // require auth, but pending notifications should still be visible).
      _showLocalNotification(message);
      _pushOrderAlert(message);
    }
  }

  /// Extract orderId from message data, trying both common key names.
  String? _extractOrderId(Map<String, dynamic> data) {
    return data['orderId'] ?? data['order_id'] ?? null;
  }

  /// Show a local notification via flutter_local_notifications.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: _channel.importance,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  /// Update the orderAlertProvider with the received message data. This is the
  /// central point so the UI (e.g. a banner or order list rebuild) reacts to new
  /// order alerts. Called from both foreground and background/opened-app handlers.
  void _pushOrderAlert(RemoteMessage message) {
    final orderId = _extractOrderId(message.data);
    if (orderId == null) return;

    _ref.read(orderAlertProvider.notifier).state = OrderAlert(
      orderId: orderId.toString(),
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
    );
  }

  /// Handle a message that opened the app from background/terminated state.
  /// If the user taps a notification, we store the orderId in a persistent
  /// Riverpod provider that the DeliveryPanelScreen reads on build to navigate
  /// to the correct screen.
  void _onOpenedApp(RemoteMessage message) {
    final orderId = _extractOrderId(message.data);
    if (orderId != null) {
      _ref.read(lastTappedOrderIdProvider.notifier).state = orderId;
      debugPrint('[NOTIF] Notification tapped — set lastTappedOrderId to: $orderId');
    } else {
      debugPrint('[NOTIF] Background-tap notification without orderId: data=${message.data}');
    }
    _pushOrderAlert(message);
  }
}

/// Provides the [NotificationService], bound to the Riverpod container.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService(ref));

/// Triggers one-time initialization of notifications (permission + listeners).
/// Watch this from the app root (see [MyApp]) so it runs exactly once.
final notificationInitProvider = FutureProvider<void>((ref) async {
  try {
    if (Firebase.apps.isEmpty) {
      debugPrint(
          '[NOTIF] Firebase not initialized; skipping notificationInitProvider.');
      return;
    }
    final service = ref.watch(notificationServiceProvider);
    await service.init();
  } catch (e) {
    debugPrint('[NOTIF] Error in notificationInitProvider: $e');
  }
});