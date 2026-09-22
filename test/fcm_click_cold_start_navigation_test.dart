import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/notification_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/repositories/notification_repository.dart';
import 'package:dairy_app/services/fcm_service.dart';
import 'package:dairy_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 10 — FCM Click & Cold Start Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('1. NotificationDestination Payload Extraction', () {
      test('Extracts camelCase orderId, route, and type', () {
        final payload = {
          'orderId': 'ORD-101',
          'route': '/orders/ORD-101',
          'type': 'order_status',
          'extra': 'value',
        };

        final dest = NotificationDestination.fromPayload(
          payload,
          messageId: 'msg-001',
          title: 'Order Dispatched',
          body: 'Your milk has been dispatched',
        );

        expect(dest.orderId, 'ORD-101');
        expect(dest.route, '/orders/ORD-101');
        expect(dest.type, 'order_status');
        expect(dest.messageId, 'msg-001');
        expect(dest.title, 'Order Dispatched');
        expect(dest.body, 'Your milk has been dispatched');
        expect(dest.data['extra'], 'value');
      });

      test('Extracts snake_case order_id when orderId is absent', () {
        final payload = {
          'order_id': 'ORD-202',
          'type': 'delivery_assigned',
        };

        final dest = NotificationDestination.fromPayload(payload);
        expect(dest.orderId, 'ORD-202');
      });

      test('Extracts notificationId from notificationId, notifId, or id', () {
        final dest1 = NotificationDestination.fromPayload({
          'notificationId': 'nid-123',
          'orderId': 'ORD-1',
        });
        expect(dest1.notificationId, 'nid-123');

        final dest2 = NotificationDestination.fromPayload({
          'notifId': 'nid-456',
          'orderId': 'ORD-2',
        });
        expect(dest2.notificationId, 'nid-456');

        final dest3 = NotificationDestination.fromPayload({
          'id': 'nid-789',
        });
        expect(dest3.notificationId, 'nid-789');
      });

      test('Handles empty and malformed payloads without crashing', () {
        final dest = NotificationDestination.fromPayload(const {});
        expect(dest.notificationId, isNull);
        expect(dest.orderId, isNull);
        expect(dest.route, isNull);
        expect(dest.type, isNull);
        expect(dest.data, isEmpty);
      });
    });

    group('2. Deduplication & Debounce Logic', () {
      test('Rejects rapid duplicate messageId within debounce window', () {
        final service = container.read(notificationServiceProvider);

        final data = {'orderId': 'ORD-303'};
        final firstTap = service.isDuplicateTap('msg-abc', data);
        expect(firstTap, isFalse, reason: 'First tap must be processed');

        final immediateDuplicate = service.isDuplicateTap('msg-abc', data);
        expect(immediateDuplicate, isTrue, reason: 'Duplicate tap must be blocked');
      });

      test('Rejects rapid duplicate data signature when messageId is missing', () {
        final service = container.read(notificationServiceProvider);

        final data = {'orderId': 'ORD-404', 'route': '/orders/ORD-404'};
        final firstTap = service.isDuplicateTap(null, data);
        expect(firstTap, isFalse);

        final duplicateSig = service.isDuplicateTap(null, data);
        expect(duplicateSig, isTrue);
      });

      test('Allows processing of different notifications in rapid succession', () {
        final service = container.read(notificationServiceProvider);

        final first = service.isDuplicateTap('msg-1', {'orderId': 'ORD-1'});
        expect(first, isFalse);

        final second = service.isDuplicateTap('msg-2', {'orderId': 'ORD-2'});
        expect(second, isFalse, reason: 'Different message ID must not be blocked');
      });
    });

    group('3. Strict RBAC & Route Resolution Matrix', () {
      const customerUser = User(
        id: 'cust-1',
        name: 'Test Customer',
        phone: '9999999999',
        role: 'customer',
      );

      const deliveryUser = User(
        id: 'deliv-1',
        name: 'Test Agent',
        phone: '8888888888',
        role: 'delivery',
      );

      const adminUser = User(
        id: 'admin-1',
        name: 'Test Admin',
        phone: '7777777777',
        role: 'admin',
      );

      test('Customer with orderId resolves to /orders/<orderId>', () {
        final route = NotificationService.resolveNotificationRoute(
          user: customerUser,
          orderId: 'ORD-500',
        );
        expect(route, '/orders/ORD-500');
      });

      test('Customer with allowed customer routes resolves correctly', () {
        for (final validRoute in ['/cart', '/shop', '/checkout', '/settings', '/support']) {
          final route = NotificationService.resolveNotificationRoute(
            user: customerUser,
            explicitRoute: validRoute,
          );
          expect(route, validRoute, reason: 'Route $validRoute must be allowed for customer');
        }
      });

      test('Customer is blocked from /admin routes and falls back to /notifications', () {
        final route = NotificationService.resolveNotificationRoute(
          user: customerUser,
          explicitRoute: '/admin/orders',
        );
        expect(route, '/notifications');
      });

      test('Customer is blocked from /delivery routes and falls back to /notifications', () {
        final route = NotificationService.resolveNotificationRoute(
          user: customerUser,
          explicitRoute: '/delivery',
        );
        expect(route, '/notifications');
      });

      test('Customer with unknown/malformed route falls back to /notifications', () {
        final route = NotificationService.resolveNotificationRoute(
          user: customerUser,
          explicitRoute: '/some/malicious/or/invalid/path',
        );
        expect(route, '/notifications');
      });

      test('Delivery agent with orderId resolves to /delivery (DeliveryPanel)', () {
        final route = NotificationService.resolveNotificationRoute(
          user: deliveryUser,
          orderId: 'ORD-600',
        );
        expect(route, '/delivery');
      });

      test('Delivery agent with /delivery-map resolves to /delivery-map', () {
        final route = NotificationService.resolveNotificationRoute(
          user: deliveryUser,
          explicitRoute: '/delivery-map',
        );
        expect(route, '/delivery-map');
      });

      test('Delivery agent is strictly blocked from /admin routes', () {
        final route = NotificationService.resolveNotificationRoute(
          user: deliveryUser,
          explicitRoute: '/admin',
        );
        expect(route, '/delivery');
      });

      test('Admin with orderId resolves to /admin/orders', () {
        final route = NotificationService.resolveNotificationRoute(
          user: adminUser,
          orderId: 'ORD-700',
        );
        expect(route, '/admin/orders');
      });

      test('Admin with explicit route resolves to requested admin route', () {
        final route = NotificationService.resolveNotificationRoute(
          user: adminUser,
          explicitRoute: '/admin/settings',
        );
        expect(route, '/admin/settings');
      });
    });

    group('4. Unauthenticated Buffering & State Updates', () {
      test('Tapping notification when user is unauthenticated buffers into pendingNotificationDestinationProvider', () {
        final service = container.read(notificationServiceProvider);

        final dest = NotificationDestination.fromPayload(
          {'orderId': 'ORD-800'},
          messageId: 'msg-unauth-1',
          title: 'New Order',
          body: 'Milk delivery ready',
        );

        service.handleNotificationTap(dest);

        // Verify lastTappedOrderIdProvider is updated
        expect(container.read(lastTappedOrderIdProvider), 'ORD-800');

        // Verify orderAlertProvider is updated
        final alert = container.read(orderAlertProvider);
        expect(alert?.orderId, 'ORD-800');
        expect(alert?.title, 'New Order');

        // Verify pending destination is buffered because userProvider is empty (unauthenticated)
        final pending = container.read(pendingNotificationDestinationProvider);
        expect(pending, isNotNull);
        expect(pending?.orderId, 'ORD-800');
        expect(pending?.messageId, 'msg-unauth-1');
      });
    });

    group('5. Notification Read / Mark-Read Behavior', () {
      test('Tapping notification with notificationId calls markAsRead for authenticated user', () {
        final mockRepo = _TestNotificationRepo();
        const testUser = User(
          id: 'cust-marked-1',
          name: 'Logged Customer',
          phone: '9876543210',
          role: 'customer',
        );

        final authContainer = ProviderContainer(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(mockRepo),
            userProvider.overrideWith((ref) => _TestUserNotifier(testUser)),
          ],
        );

        final service = authContainer.read(notificationServiceProvider);
        final dest = NotificationDestination.fromPayload({
          'notificationId': 'notif-doc-999',
          'orderId': 'ORD-999',
          'route': '/orders/ORD-999',
        });

        service.handleNotificationTap(dest);

        expect(mockRepo.markedReadNotifIds, contains('notif-doc-999'));
        expect(mockRepo.markedReadUserIds, contains('cust-marked-1'));
        authContainer.dispose();
      });
    });
  });
}

class _TestNotificationRepo extends NotificationRepository {
  final List<String> markedReadNotifIds = [];
  final List<String> markedReadUserIds = [];

  @override
  Future<void> markAsRead(String userId, String notifId) async {
    markedReadUserIds.add(userId);
    markedReadNotifIds.add(notifId);
  }
}

class _TestUserNotifier extends UserNotifier {
  _TestUserNotifier(User user) {
    state = user;
  }

  @override
  Future<void> loadSession() async {
    // No-op in tests to avoid unmounted state mutation after container disposal
  }
}
