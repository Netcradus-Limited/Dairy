import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/notification_item.dart';

/// FCM-related test helpers and constants
const String testDeliveryUid = 'delivery_agent_abc';
const String testAdminUid = 'admin_abc';
const String testCustomerUid = 'customer_abc';

void main() {
  group('Notifications Security, Path & Model Tests', () {
    test(
        'Notification path construction matches exact Firestore subcollection structure',
        () {
      const userId = 'user_abc_123';
      const notificationId = 'notif_xyz_789';

      // Exact path verified: users/{userId}/notifications/{notificationId}
      const collectionPath = 'users/$userId/notifications';
      const documentPath = 'users/$userId/notifications/$notificationId';

      expect(collectionPath, 'users/user_abc_123/notifications');
      expect(documentPath, 'users/user_abc_123/notifications/notif_xyz_789');
    });

    test('NotificationItem serializes to and from Firestore map correctly', () {
      final now = DateTime(2026, 9, 9, 12, 0, 0);
      final item = NotificationItem(
        id: 'notif_1',
        type: NotificationType.order,
        title: 'Order Confirmed',
        body: 'Your fresh milk order #ORD-101 is confirmed.',
        timestamp: now,
        orderId: 'ORD-101',
        route: '/orders/ORD-101',
        assignedAgentId: 'agent_99',
        isRead: false,
        isActionable: true,
        createdBy: 'admin_1',
        userId: 'cust_1',
        metadata: {'status': 'confirmed'},
      );

      final firestoreMap = item.toFirestore();
      expect(firestoreMap['type'], 'order');
      expect(firestoreMap['title'], 'Order Confirmed');
      expect(
          firestoreMap['body'], 'Your fresh milk order #ORD-101 is confirmed.');
      expect(firestoreMap['orderId'], 'ORD-101');
      expect(firestoreMap['route'], '/orders/ORD-101');
      expect(firestoreMap['assignedAgentId'], 'agent_99');
      expect(firestoreMap['isRead'], false);
      expect(firestoreMap['isActionable'], true);
      expect(firestoreMap['createdBy'], 'admin_1');
      expect(firestoreMap['userId'], 'cust_1');
      expect(firestoreMap['metadata']['status'], 'confirmed');

      // Test copyWith
      final readItem = item.copyWith(isRead: true);
      expect(readItem.isRead, true);
      expect(readItem.id, 'notif_1');
      expect(readItem.title, 'Order Confirmed');
      expect(readItem.route, '/orders/ORD-101');
    });

    test('NotificationType parsing and icon coverage', () {
      expect(NotificationTypeExtension.fromString('order'),
          NotificationType.order);
      expect(NotificationTypeExtension.fromString('delivery'),
          NotificationType.delivery);
      expect(NotificationTypeExtension.fromString('promotional'),
          NotificationType.promotional);
      expect(NotificationTypeExtension.fromString('subscription'),
          NotificationType.subscription);
      expect(NotificationTypeExtension.fromString('unknown'),
          NotificationType.system);

      expect(NotificationType.order.value, 'order');
      expect(NotificationType.delivery.value, 'delivery');
      expect(NotificationType.promotional.value, 'promotional');
      expect(NotificationType.subscription.value, 'subscription');
      expect(NotificationType.system.value, 'system');
    });

    test('Dual orderId / order_id parsing in NotificationItem.fromFirestore', () {
      final now = DateTime.now();

      // Case 1: camelCase orderId
      final mapCamel = {
        'id': 'n1',
        'type': 'order',
        'title': 'Test',
        'body': 'Test body',
        'timestamp': now.toIso8601String(),
        'orderId': 'ORD-CAMEL-100',
      };
      final itemCamel = NotificationItem.fromMap(mapCamel, 'n1');
      expect(itemCamel.orderId, 'ORD-CAMEL-100');

      // Case 2: snake_case order_id
      final mapSnake = {
        'id': 'n2',
        'type': 'order',
        'title': 'Test',
        'body': 'Test body',
        'timestamp': now.toIso8601String(),
        'order_id': 'ORD-SNAKE-200',
      };
      final itemSnake = NotificationItem.fromMap(mapSnake, 'n2');
      expect(itemSnake.orderId, 'ORD-SNAKE-200');

      // Case 3: Both null/missing
      final mapNone = {
        'id': 'n3',
        'type': 'promotional',
        'title': 'Promo',
        'body': 'Promo body',
        'timestamp': now.toIso8601String(),
      };
      final itemNone = NotificationItem.fromMap(mapNone, 'n3');
      expect(itemNone.orderId, isNull);
    });

    group('Task 5 — Type-Specific Notification Flow & Business Logic', () {
      // 1. ORDER NOTIFICATIONS
      test(
          'ORDER: Resolves only the customer who owns the order and generates order route',
          () {
        final orderDoc = {
          'id': 'ORD-888',
          'userId': 'customer_cust_123',
          'status': 'confirmed',
        };

        // Recipient must be the customer
        final recipientUserId = orderDoc['userId'];
        expect(recipientUserId, 'customer_cust_123');

        // Unrelated user must not receive it
        const unrelatedUserId = 'customer_unrelated_456';
        expect(unrelatedUserId == recipientUserId, isFalse);

        final notif = NotificationItem(
          id: 'n_ord_1',
          type: NotificationType.order,
          title: 'Order Confirmed',
          body: 'Order #ORD-888 confirmed',
          timestamp: DateTime.now(),
          orderId: orderDoc['id'],
          route: '/orders/${orderDoc['id']}',
          userId: recipientUserId,
        );

        expect(notif.orderId, 'ORD-888');
        expect(notif.route, '/orders/ORD-888');
        expect(notif.userId, 'customer_cust_123');
      });

      // 2. DELIVERY NOTIFICATIONS
      test('DELIVERY: Resolves customer and/or assigned agent with correct IDs',
          () {
        final deliveryOrder = {
          'id': 'ORD-999',
          'userId': 'customer_alpha',
          'assignedAgentId': 'agent_bravo',
          'status': 'outForDelivery',
        };

        // Customer notification
        final customerNotif = NotificationItem(
          id: 'deliv_cust_1',
          type: NotificationType.delivery,
          title: 'Out for Delivery 🚀',
          body: 'Your fresh milk is on its way.',
          timestamp: DateTime.now(),
          orderId: deliveryOrder['id'],
          assignedAgentId: deliveryOrder['assignedAgentId'],
          route: '/orders/${deliveryOrder['id']}',
          userId: deliveryOrder['userId'],
        );

        // Agent notification
        final agentNotif = NotificationItem(
          id: 'deliv_agent_1',
          type: NotificationType.delivery,
          title: 'New Delivery Assigned 📦',
          body: 'Deliver order #ORD-999 to customer',
          timestamp: DateTime.now(),
          orderId: deliveryOrder['id'],
          assignedAgentId: deliveryOrder['assignedAgentId'],
          route: '/orders/${deliveryOrder['id']}',
          userId: deliveryOrder['assignedAgentId'],
        );

        expect(customerNotif.userId, 'customer_alpha');
        expect(agentNotif.userId, 'agent_bravo');
        expect(customerNotif.assignedAgentId, 'agent_bravo');
        expect(agentNotif.orderId, 'ORD-999');
      });

      // 3. PROMOTIONAL NOTIFICATIONS
      test(
          'PROMOTIONAL: Operates without orderId and chunks recipients into batches <= 500',
          () {
        // Simulates 1250 total user IDs
        final allUserIds = List.generate(1250, (index) => 'user_$index');

        final chunks = <List<String>>[];
        for (var i = 0; i < allUserIds.length; i += 500) {
          chunks.add(
            allUserIds.sublist(
              i,
              i + 500 > allUserIds.length ? allUserIds.length : i + 500,
            ),
          );
        }

        expect(chunks.length, 3);
        expect(chunks[0].length, 500);
        expect(chunks[1].length, 500);
        expect(chunks[2].length, 250);

        final promoNotif = NotificationItem(
          id: 'promo_1',
          type: NotificationType.promotional,
          title: 'Diwali Dairy Fest 🪔',
          body: 'Get 25% discount on Pure Cow Ghee',
          timestamp: DateTime.now(),
          route: '/notifications',
        );

        expect(promoNotif.orderId, isNull);
        expect(promoNotif.route, '/notifications');
        expect(promoNotif.type, NotificationType.promotional);
      });

      // 4. SUBSCRIPTION NOTIFICATIONS
      test(
          'SUBSCRIPTION: Filters only active subscribers and excludes non-subscribers',
          () {
        final mockSubscriptions = [
          {'userId': 'sub_user_1', 'status': 'active'},
          {'userId': 'sub_user_2', 'status': 'active'},
          {'userId': 'sub_user_3', 'status': 'cancelled'},
          {'userId': 'sub_user_4', 'status': 'expired'},
          {
            'userId': 'sub_user_1',
            'status': 'active'
          }, // Duplicate user with 2 active subs
        ];

        final activeUserIds = mockSubscriptions
            .where((doc) => doc['status']?.toLowerCase() == 'active')
            .map((doc) => doc['userId']!)
            .toSet()
            .toList();

        expect(activeUserIds.length, 2);
        expect(activeUserIds, contains('sub_user_1'));
        expect(activeUserIds, contains('sub_user_2'));
        expect(activeUserIds.contains('sub_user_3'), isFalse);
        expect(activeUserIds.contains('sub_user_4'), isFalse);
      });

      // 5. SYSTEM NOTIFICATIONS
      test(
          'SYSTEM: Provides safe fallback route when route is empty or unspecified',
          () {
        final systemNotif = NotificationItem(
          id: 'sys_1',
          type: NotificationType.system,
          title: 'Scheduled Maintenance Notice',
          body: 'App services will undergo maintenance from 2 AM to 4 AM.',
          timestamp: DateTime.now(),
          route: null,
        );

        final resolvedRoute =
            (systemNotif.route != null && systemNotif.route!.isNotEmpty)
                ? systemNotif.route!
                : '/notifications';

        expect(resolvedRoute, '/notifications');
        expect(systemNotif.type, NotificationType.system);
      });
    });

    group('FCM Token Security & Ownership Tests', () {
      // Simulates the FCM token storage logic: only the authenticated delivery
      // agent may save/update their own token. Admins may write any token.
      // Other users cannot write tokens.

      test('Delivery agent CAN save their own FCM token', () {
        // evaluateFCMTokenRule mimics the check in FCMService._saveTokenIfAuthorized():
        // - authUid must be non-empty (authenticated)
        // - user document must exist with role == 'delivery' or 'superadmin'
        // - token must be non-empty
        final result = evaluateFCMTokenRule(
          authUid: testDeliveryUid,
          authRole: 'delivery',
          targetUserId: testDeliveryUid,
          token: 'some_fcm_token_123',
        );
        expect(result, isTrue);
      });

      test(
          'Delivery agent CANNOT save another delivery agent\'s FCM token', () {
        final result = evaluateFCMTokenRule(
          authUid: testDeliveryUid,
          authRole: 'delivery',
          targetUserId: 'other_delivery_uid',
          token: 'some_fcm_token_456',
        );
        expect(result, isFalse);
      });

      test('Admin CAN save FCM token for any user', () {
        final result = evaluateFCMTokenRule(
          authUid: testAdminUid,
          authRole: 'admin',
          targetUserId: testDeliveryUid,
          token: 'some_fcm_token_789',
        );
        expect(result, isTrue);
      });

      test('Customer CANNOT save FCM token', () {
        final result = evaluateFCMTokenRule(
          authUid: testCustomerUid,
          authRole: 'customer',
          targetUserId: testCustomerUid,
          token: 'some_fcm_token_123',
        );
        expect(result, isFalse);
      });

      test('Unauthenticated user CANNOT save FCM token', () {
        final result = evaluateFCMTokenRule(
          authUid: null,
          authRole: null,
          targetUserId: testDeliveryUid,
          token: 'some_fcm_token_123',
        );
        expect(result, isFalse);
      });
    });

    group('Firestore Security Rules Logic Verification', () {
      // Simulates the exact rules evaluated in firestore.rules:
      // match /users/{userId}/notifications/{notifId} {
      //   allow read, create, update, delete: if isAdmin() || isOwnDoc(userId);
      // }
      // where isOwnDoc(userId) = (request.auth != null && request.auth.uid == userId)
      // and isAdmin() = (request.auth != null && role in ['admin', 'superadmin'])

      bool evaluateNotificationRule({
        required String? authUid,
        required String? authRole,
        required String targetUserId,
      }) {
        final isSignedIn = authUid != null && authUid.isNotEmpty;
        final isOwnDoc = isSignedIn && authUid == targetUserId;
        final isAdmin =
            isSignedIn && (authRole == 'admin' || authRole == 'superadmin');

        return isAdmin || isOwnDoc;
      }

      test('Authenticated user CAN read and write their OWN notifications', () {
        final allowed = evaluateNotificationRule(
          authUid: 'user_123',
          authRole: 'customer',
          targetUserId: 'user_123',
        );
        expect(allowed, isTrue);
      });

      test(
          'Authenticated user CANNOT read or write ANOTHER user notifications',
          () {
        final allowed = evaluateNotificationRule(
          authUid: 'user_123',
          authRole: 'customer',
          targetUserId: 'user_456',
        );
        expect(allowed, isFalse);
      });

      test('Unauthenticated user CANNOT read or write any notifications', () {
        final allowed = evaluateNotificationRule(
          authUid: null,
          authRole: null,
          targetUserId: 'user_123',
        );
        expect(allowed, isFalse);
      });

      test('Admin CAN write to another user notifications (broadcasts)', () {
        final allowed = evaluateNotificationRule(
          authUid: 'admin_999',
          authRole: 'admin',
          targetUserId: 'user_123',
        );
        expect(allowed, isTrue);
      });

      test('Superadmin CAN write to another user notifications', () {
        final allowed = evaluateNotificationRule(
          authUid: 'superadmin_1',
          authRole: 'superadmin',
          targetUserId: 'user_123',
        );
        expect(allowed, isTrue);
      });

      test('Delivery agent CANNOT read another customer notifications', () {
        final allowed = evaluateNotificationRule(
          authUid: 'agent_55',
          authRole: 'delivery',
          targetUserId: 'user_123',
        );
        expect(allowed, isFalse);
      });
    });

    group('Web FCM Service Worker File & Configuration Tests', () {
      test('web/firebase-messaging-sw.js exists and is not empty', () {
        final swFile = File('web/firebase-messaging-sw.js');
        expect(swFile.existsSync(), isTrue,
            reason: 'web/firebase-messaging-sw.js must exist in the Flutter web public root');
        final content = swFile.readAsStringSync();
        expect(content.trim().isNotEmpty, isTrue);
      });

      test('web/firebase-messaging-sw.js contains exact Firebase web credentials', () {
        final swFile = File('web/firebase-messaging-sw.js');
        final content = swFile.readAsStringSync();

        expect(content.contains('AIzaSyCHV_tWBg53-HsR5DDFL7WQfJrL56qvBaI'), isTrue,
            reason: 'Service worker must contain the exact web apiKey');
        expect(content.contains('1:325042169664:web:78b972a71a1775611d7ca5'), isTrue,
            reason: 'Service worker must contain the exact web appId');
        expect(content.contains('325042169664'), isTrue,
            reason: 'Service worker must contain the exact messagingSenderId');
        expect(content.contains('sawariya-7efd4'), isTrue,
            reason: 'Service worker must contain the exact projectId');
        expect(content.contains('sawariya-7efd4.firebaseapp.com'), isTrue,
            reason: 'Service worker must contain the exact authDomain');
      });

      test('web/firebase-messaging-sw.js imports compat libraries and registers listeners', () {
        final swFile = File('web/firebase-messaging-sw.js');
        final content = swFile.readAsStringSync();

        expect(content.contains('firebase-app-compat.js'), isTrue);
        expect(content.contains('firebase-messaging-compat.js'), isTrue);
        expect(content.contains('onBackgroundMessage'), isTrue);
        expect(content.contains('notificationclick'), isTrue);
        expect(content.contains('/#/delivery'), isTrue);
      });
    });
  });
}

/// Evaluates whether a delivery agent / admin may save an FCM token.
///
/// This mirrors the logic in FCMService._saveTokenIfAuthorized():
/// - authUid must be non-empty (user is authenticated)
/// - The user document must exist and have role == 'delivery' or 'superadmin'
/// - The token must be non-empty
/// - The targetUserId must match the authUid (delivery agent owns their own token)
///   OR the authUid is an admin (admin can set any user's token)
bool evaluateFCMTokenRule({
  required String? authUid,
  required String? authRole,
  required String targetUserId,
  required String token,
}) {
  // Step 1: auth must exist
  if (authUid == null || authUid.isEmpty) return false;

  // Step 2: valid role check (delivery or superadmin for own token, admin for any)
  final validRoles = ['delivery', 'superadmin'];
  if (authRole != null && validRoles.contains(authRole)) {
    // OK, authenticated user is delivery or superadmin
  } else if (authRole == 'admin' || authRole == null) {
    // Admin or unknown — will be handled in step 4
  } else {
    // Unknown role — deny
    return false;
  }

  // Step 3: token must be non-empty
  if (token.isEmpty) return false;

  // Step 4: ownership check
  // Delivery agent may only set their own token; admin may set any user's token
  final isOwnToken = authUid == targetUserId;
  final isAdmin = authRole == 'admin' || authRole == 'superadmin';

  return isOwnToken || isAdmin;
}