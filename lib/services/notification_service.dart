import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../providers/user_provider.dart';

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

/// Holds the most recent order alert so the UI can react (e.g. show a banner
/// or refresh the orders list) when a notification arrives.
final orderAlertProvider = StateProvider<OrderAlert?>((ref) => null);

/// Background message handler. Must be a top-level function (not a closure) and
/// must be annotated so it survives tree-shaking. It is invoked when a message
/// arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint(
      '[FCM BACKGROUND] Message ID: ${message.messageId}, data: ${message.data}');
}

/// Wraps Firebase Cloud Messaging and local notifications:
/// - Requests runtime permission on Android 13+ and iOS.
/// - Configures high-importance Android notification channel.
/// - Manages FCM token registration and Firestore synchronization.
/// - Handles foreground, background, and terminated cold-start messages.
/// - Safely parses notification payloads and executes deep-link navigation.
class NotificationService {
  NotificationService(
    this._ref, {
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseFirestore? firestore,
  })  : _customMessaging = messaging,
        _customLocalNotifications = localNotifications,
        _customFirestore = firestore;

  final Ref _ref;
  final FirebaseMessaging? _customMessaging;
  final FlutterLocalNotificationsPlugin? _customLocalNotifications;
  final FirebaseFirestore? _customFirestore;

  FirebaseMessaging get _messaging =>
      _customMessaging ?? FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      _customLocalNotifications ?? FlutterLocalNotificationsPlugin();
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSub;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'order_alerts',
    'Order Alerts',
    description:
        'Notifications for new and updated orders, deliveries, and dairy updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initializes local notifications, notification channels, permissions,
  /// and wire up foreground, background, and cold-start listeners.
  Future<void> init() async {
    try {
      if (!kIsWeb) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onLocalNotificationTap,
        );
      }

      await requestPermission();

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Listen to background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp);

      // Handle cold start from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FCM COLD START] App opened from terminated state with message: ${initialMessage.data}');
        _handleIncomingPayload(
            initialMessage.data, initialMessage.notification);
      }

      // Wire up token refresh listener
      listenToTokenRefresh();

      // If user is already authenticated, sync token immediately
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final userUid = _ref.read(userProvider).id;
      final effectiveUid =
          (authUid != null && authUid.isNotEmpty) ? authUid : userUid;
      if (effectiveUid.isNotEmpty) {
        await syncUserToken(effectiveUid);
      }
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Initialization error: $e');
    }
  }

  /// Requests notification permission for iOS, Android (13+) and Web.
  Future<NotificationSettings?> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint(
          '[FCM PERMISSION] Authorization status: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      debugPrint('[FCM PERMISSION] Request error: $e');
      return null;
    }
  }

  /// The current FCM registration token.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM TOKEN] getToken error: $e');
      return null;
    }
  }

  /// Stream of token refreshes.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Syncs the device FCM token with the user's Firestore document.
  Future<void> syncUserToken(String userId, {String? token}) async {
    if (userId.isEmpty) return;
    try {
      final fcmToken = token ?? await getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      debugPrint('[FCM TOKEN SYNC] Registering token for user: $userId');
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
        'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint(
          '[FCM TOKEN SYNC] Successfully registered FCM token for user $userId');
    } catch (e) {
      debugPrint('[FCM TOKEN SYNC] Error syncing token for user $userId: $e');
    }
  }

  /// Starts listening to token refresh events.
  void listenToTokenRefresh() {
    _tokenRefreshSub?.cancel();
    try {
      _tokenRefreshSub = onTokenRefresh.listen((newToken) {
        debugPrint('[FCM TOKEN REFRESH] Token refreshed');
        final authUid = FirebaseAuth.instance.currentUser?.uid;
        final userUid = _ref.read(userProvider).id;
        final effectiveUid =
            (authUid != null && authUid.isNotEmpty) ? authUid : userUid;
        if (effectiveUid.isNotEmpty) {
          syncUserToken(effectiveUid, token: newToken);
        }
      }, onError: (err) {
        debugPrint('[FCM TOKEN REFRESH] Error: $err');
      });
    } catch (e) {
      debugPrint('[FCM TOKEN REFRESH] Listener setup error: $e');
    }
  }

  /// Clears token associations on user logout.
  Future<void> clearUserTokenOnLogout(String userId) async {
    if (userId.isEmpty) return;
    try {
      final currentToken = await getToken();
      if (currentToken != null && currentToken.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set({
          'fcmTokens': FieldValue.arrayRemove([currentToken]),
          'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      try {
        await _messaging.deleteToken();
      } catch (_) {}
      debugPrint('[FCM TOKEN CLEANUP] Token cleared for user: $userId');
    } catch (e) {
      debugPrint('[FCM TOKEN CLEANUP] Error clearing token for $userId: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[FCM FOREGROUND] Received message ID: ${message.messageId}, title: ${message.notification?.title}');
    _showLocalNotification(message);
    _pushOrderAlert(message.data, message.notification);
  }

  void _onOpenedApp(RemoteMessage message) {
    debugPrint(
        '[FCM OPENED APP] Background notification tapped: ${message.data}');
    _handleIncomingPayload(message.data, message.notification);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[LOCAL NOTIFICATION TAP] Payload: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.payload!);
        if (decoded is Map<String, dynamic>) {
          _handleIncomingPayload(decoded, null);
          return;
        }
      } catch (_) {}
    }
    _navigateToRoute('/notifications');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Sawariya Dairy';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';

    final payloadString = jsonEncode(message.data);

    try {
      await _localNotifications.show(
        notification?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payloadString,
      );
    } catch (e) {
      debugPrint('[LOCAL NOTIFICATION SHOW] Error: $e');
    }
  }

  void _pushOrderAlert(
      Map<String, dynamic> data, RemoteNotification? notification) {
    final orderId = data['orderId'] ?? data['order_id'];
    if (orderId == null) return;

    _ref.read(orderAlertProvider.notifier).state = OrderAlert(
      orderId: orderId.toString(),
      title: notification?.title ?? data['title']?.toString(),
      body: notification?.body ?? data['body']?.toString(),
      data: data,
    );
  }

  /// Parses payload safely and navigates to the appropriate screen.
  void _handleIncomingPayload(
      Map<String, dynamic> data, RemoteNotification? notification) {
    _pushOrderAlert(data, notification);

    final explicitRoute = data['route']?.toString().trim();
    final rawOrderId = (data['orderId'] ?? data['order_id'])?.toString().trim();
    final type = data['type']?.toString().trim();

    debugPrint(
        '[NOTIFICATION ROUTE] explicitRoute: $explicitRoute, orderId: $rawOrderId, type: $type');

    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      _navigateToRoute(explicitRoute);
      return;
    }

    if (rawOrderId != null && rawOrderId.isNotEmpty) {
      _navigateToRoute('/orders/$rawOrderId');
      return;
    }

    final user = _ref.read(userProvider);
    if (user.isAdmin) {
      _navigateToRoute('/admin');
      return;
    }
    if (user.isDelivery) {
      _navigateToRoute('/delivery');
      return;
    }

    // Default for customer
    _navigateToRoute('/notifications');
  }

  void _navigateToRoute(String route) {
    try {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        GoRouter.of(context).push(route);
      }
    } catch (e) {
      debugPrint('[NOTIFICATION NAVIGATION] Error navigating to $route: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}

/// Provides the [NotificationService], bound to the Riverpod container.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService(ref));

/// Triggers one-time initialization of notifications (permission + listeners).
/// Watch this from the app root (see [MyApp]) so it runs exactly once.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  await service.init();
});
