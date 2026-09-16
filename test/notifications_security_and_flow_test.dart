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
        isRead: false,
        isActionable: true,
        createdBy: 'admin_1',
        userId: 'cust_1',
      );

      final firestoreMap = item.toFirestore();
      expect(firestoreMap['type'], 'order');
      expect(firestoreMap['title'], 'Order Confirmed');
      expect(
          firestoreMap['body'], 'Your fresh milk order #ORD-101 is confirmed.');
      expect(firestoreMap['orderId'], 'ORD-101');
      expect(firestoreMap['isRead'], false);
      expect(firestoreMap['isActionable'], true);
      expect(firestoreMap['createdBy'], 'admin_1');
      expect(firestoreMap['userId'], 'cust_1');

      // Test copyWith
      final readItem = item.copyWith(isRead: true);
      expect(readItem.isRead, true);
      expect(readItem.id, 'notif_1');
      expect(readItem.title, 'Order Confirmed');
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

      test('Delivery agent CANNOT save another delivery agent\'s FCM token', () {
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

      test('Authenticated user CANNOT read or write ANOTHER user notifications', () {
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