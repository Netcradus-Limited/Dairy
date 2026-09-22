import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../models/user.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import 'fcm_service.dart';

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

/// Encapsulates destination details extracted from an incoming notification payload.
class NotificationDestination {
  final String? notificationId;
  final String? orderId;
  final String? route;
  final String? type;
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  NotificationDestination({
    this.notificationId,
    this.orderId,
    this.route,
    this.type,
    this.messageId,
    this.title,
    this.body,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NotificationDestination.fromPayload(
    Map<String, dynamic> data, {
    String? messageId,
    String? title,
    String? body,
  }) {
    final notifId = (data['notificationId'] ??
            data['notifId'] ??
            data['notification_id'] ??
            data['id'])
        ?.toString()
        .trim();
    final orderId = (data['orderId'] ?? data['order_id'])?.toString().trim();
    final route = data['route']?.toString().trim();
    final type = data['type']?.toString().trim();

    return NotificationDestination(
      notificationId:
          (notifId != null && notifId.isNotEmpty) ? notifId : null,
      orderId: (orderId != null && orderId.isNotEmpty) ? orderId : null,
      route: (route != null && route.isNotEmpty) ? route : null,
      type: (type != null && type.isNotEmpty) ? type : null,
      messageId: messageId,
      title: title,
      body: body,
      data: data,
      timestamp: DateTime.now(),
    );
  }
}

/// Holds the pending destination if a notification is tapped while the user
/// is unauthenticated or the router/splash screen is not yet ready.
final pendingNotificationDestinationProvider =
    StateProvider<NotificationDestination?>((ref) => null);

/// Background message handler – must be top-level and @pragma('vm:entry-point').
/// This handler runs while the app is in the background or terminated. It does NOT
/// update Riverpod state (UI updates are handled by the foreground listener in
/// [NotificationService]). It only ensures the local notification is displayed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint(
      '[FCM BACKGROUND] Message ID: ${message.messageId}, data: ${message.data}');
}

/// Wraps Firebase Cloud Messaging and local notifications:
/// - Requests runtime permission on Android 13+, iOS, and Web.
/// - Configures high-importance Android notification channel.
/// - Manages FCM token registration and Firestore synchronization.
/// - Handles foreground, background, and terminated cold-start messages.
/// - Safely parses notification payloads and executes deep-link routing.
/// - Integrates with [fcmServiceProvider] and [lastTappedOrderIdProvider].
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

  String? _lastProcessedMessageId;
  String? _lastProcessedSignature;
  DateTime? _lastProcessedTimestamp;
  bool _hasProcessedInitialMessage = false;

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
      if (Firebase.apps.isEmpty) {
        debugPrint(
            '[NOTIF] Firebase not initialized; skipping NotificationService.init().');
        return;
      }

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

      // Listen to foreground messages (display only; no auto-navigation)
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Listen to background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp);

      // Handle cold start from terminated state exactly once
      if (!_hasProcessedInitialMessage) {
        _hasProcessedInitialMessage = true;
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint(
              '[FCM COLD START] App opened from terminated state with message: ${initialMessage.data}');
          final dest = NotificationDestination.fromPayload(
            initialMessage.data,
            messageId: initialMessage.messageId,
            title: initialMessage.notification?.title,
            body: initialMessage.notification?.body,
          );
          handleNotificationTap(dest);
        }
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

  /// Checks if this notification tap is a duplicate within a 2-second debounce window
  /// or matches the exact messageId or data signature.
  bool isDuplicateTap(String? messageId, Map<String, dynamic> data) {
    final now = DateTime.now();
    final orderId = data['orderId']?.toString() ?? data['order_id']?.toString() ?? '';
    final route = data['route']?.toString() ?? '';
    final signature = '${messageId ?? ''}_${orderId}_$route';

    if (_lastProcessedTimestamp != null &&
        now.difference(_lastProcessedTimestamp!) < const Duration(seconds: 2)) {
      if (messageId != null && messageId.isNotEmpty && messageId == _lastProcessedMessageId) {
        debugPrint('[NOTIFICATION DEDUP] Duplicate messageId: $messageId ignored');
        return true;
      }
      if (signature.isNotEmpty && signature == _lastProcessedSignature) {
        debugPrint('[NOTIFICATION DEDUP] Duplicate signature: $signature ignored');
        return true;
      }
    }

    _lastProcessedMessageId = messageId;
    _lastProcessedSignature = signature;
    _lastProcessedTimestamp = now;
    return false;
  }

  /// Resolves the valid, RBAC-compliant destination route based on the user's role and payload.
  static String resolveNotificationRoute({
    required User user,
    String? explicitRoute,
    String? orderId,
    String? type,
  }) {
    // 1. Delivery agent RBAC & Route handling
    if (user.isDelivery) {
      // Delivery agent: route must NOT lead into admin screens
      if (explicitRoute != null && explicitRoute.startsWith('/admin')) {
        debugPrint('[NOTIFICATION RBAC] Blocked delivery agent from admin route: $explicitRoute');
        return '/delivery';
      }
      // If orderId is provided, delivery agent goes to /delivery (DeliveryPanel) with focused order
      if (orderId != null && orderId.isNotEmpty) {
        return '/delivery';
      }
      if (explicitRoute != null && explicitRoute.isNotEmpty) {
        // Allowed delivery-specific routes
        final clean = explicitRoute.split('?').first;
        if (clean == '/delivery' ||
            clean == '/delivery-map' ||
            clean.startsWith('/delivery') ||
            clean == '/notifications' ||
            clean == '/profile') {
          return explicitRoute;
        }
        return '/delivery';
      }
      return '/delivery';
    }

    // 2. Admin RBAC & Route handling
    if (user.isAdmin) {
      if (explicitRoute != null && explicitRoute.isNotEmpty) {
        return explicitRoute;
      }
      if (orderId != null && orderId.isNotEmpty) {
        return '/admin/orders';
      }
      return '/admin';
    }

    // 3. Customer User
    // Block customer from /admin or /delivery routes
    if (explicitRoute != null &&
        (explicitRoute.startsWith('/admin') || explicitRoute.startsWith('/delivery'))) {
      debugPrint('[NOTIFICATION RBAC] Blocked customer from protected route: $explicitRoute');
      return '/notifications';
    }

    if (orderId != null && orderId.isNotEmpty) {
      return '/orders/$orderId';
    }

    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      final clean = explicitRoute.split('?').first;
      const allowedCustomerRoutes = [
        '/home',
        '/shop',
        '/products',
        '/product-details',
        '/cart',
        '/orders',
        '/subscriptions',
        '/profile',
        '/notifications',
        '/address',
        '/checkout',
        '/settings',
        '/support',
      ];
      if (allowedCustomerRoutes.contains(clean) ||
          clean.startsWith('/orders/') ||
          clean.startsWith('/product/')) {
        return explicitRoute;
      }
      return '/notifications';
    }

    // Default fallback
    return '/notifications';
  }

  /// Primary entry point for handling notification taps from any lifecycle state.
  void handleNotificationTap(NotificationDestination destination) {
    if (isDuplicateTap(destination.messageId, destination.data)) {
      return;
    }

    final orderId = destination.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      try {
        _ref.read(lastTappedOrderIdProvider.notifier).state = orderId;
        debugPrint('[NOTIFICATION ROUTE] Set lastTappedOrderIdProvider to: $orderId');
      } catch (e) {
        debugPrint('[NOTIFICATION ROUTE] Could not set lastTappedOrderIdProvider: $e');
      }
    }

    if (orderId != null && orderId.isNotEmpty) {
      _ref.read(orderAlertProvider.notifier).state = OrderAlert(
        orderId: orderId,
        title: destination.title,
        body: destination.body,
        data: destination.data,
      );
    }

    final user = _ref.read(userProvider);
    bool isAuthenticated = false;
    try {
      if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
        isAuthenticated = true;
      }
    } catch (_) {}

    // Mark notification as read in Firestore if notificationId is present and user is authenticated
    final notifId = destination.notificationId;
    if (notifId != null && notifId.isNotEmpty && user.id.isNotEmpty) {
      try {
        _ref.read(notificationRepositoryProvider).markAsRead(user.id, notifId);
        debugPrint('[NOTIFICATION TAP] Marked notification $notifId as read for ${user.id}');
      } catch (e) {
        debugPrint('[NOTIFICATION TAP] Could not mark as read: $e');
      }
    }

    // If user is unauthenticated or user profile has not loaded yet, buffer it
    if (!isAuthenticated || user.id.isEmpty) {
      debugPrint('[NOTIFICATION TAP] User unauthenticated or profile pending; buffering destination.');
      _ref.read(pendingNotificationDestinationProvider.notifier).state = destination;
      return;
    }

    final targetRoute = resolveNotificationRoute(
      user: user,
      explicitRoute: destination.route,
      orderId: destination.orderId,
      type: destination.type,
    );

    debugPrint('[NOTIFICATION TAP] Navigating to resolved route: $targetRoute');
    _navigateToRoute(targetRoute);
  }

  /// Handles incoming foreground message: displays local notification and updates orderAlertProvider.
  /// Does NOT trigger disruptive auto-navigation.
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[FCM FOREGROUND] Received message ID: ${message.messageId}, title: ${message.notification?.title}');
    _showLocalNotification(message);
    _pushOrderAlert(message.data, message.notification);
  }

  /// Handles notification tap when app is in background.
  void _onOpenedApp(RemoteMessage message) {
    debugPrint(
        '[FCM OPENED APP] Background notification tapped: ${message.data}');
    final dest = NotificationDestination.fromPayload(
      message.data,
      messageId: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    handleNotificationTap(dest);
  }

  /// Handles local notification response tap.
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[LOCAL NOTIFICATION TAP] Payload: ${response.payload}');
    Map<String, dynamic> data = {};
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.payload!);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}
    }
    final dest = NotificationDestination.fromPayload(data);
    handleNotificationTap(dest);
  }

  /// Extract orderId from message data, supporting both camelCase and snake_case.
  String? _extractOrderId(Map<String, dynamic> data) {
    return data['orderId']?.toString() ?? data['order_id']?.toString();
  }

  /// Displays high-importance local notification for incoming message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;
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

  /// Pushes alert into [orderAlertProvider] for UI listeners.
  void _pushOrderAlert(
      Map<String, dynamic> data, RemoteNotification? notification) {
    final orderId = _extractOrderId(data);
    if (orderId == null || orderId.isEmpty) return;

    _ref.read(orderAlertProvider.notifier).state = OrderAlert(
      orderId: orderId,
      title: notification?.title ?? data['title']?.toString(),
      body: notification?.body ?? data['body']?.toString(),
      data: data,
    );
  }

  void _navigateToRoute(String route) {
    try {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        final router = GoRouter.of(context);
        final currentLoc = router.routeInformationProvider.value.uri.toString();
        if (currentLoc == route) {
          debugPrint('[NOTIFICATION NAVIGATION] Already at route $route; skipping redundant push.');
          return;
        }
        router.push(route);
      } else {
        debugPrint('[NOTIFICATION NAVIGATION] Context not mounted; buffering route.');
        _ref.read(pendingNotificationDestinationProvider.notifier).state =
            NotificationDestination(route: route, data: const {});
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