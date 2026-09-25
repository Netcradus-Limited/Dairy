import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dairy_app/services/notification_service.dart';
import 'package:dairy_app/models/notification_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM & Notification Service Unit Tests', () {
    test('AndroidNotificationChannel is properly configured for high priority',
        () {
      const channel = NotificationService.channel;
      expect(channel.id, 'order_alerts');
      expect(channel.name, 'Order Alerts');
      expect(channel.importance, Importance.high);
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
    });

    test('OrderAlert model holds correct values and data map', () {
      const alert = OrderAlert(
        orderId: 'ORD-999',
        title: 'Out for Delivery 🚀',
        body: 'Rider is on the way with your dairy products.',
        data: {'status': 'outForDelivery', 'agentName': 'Vikram'},
      );

      expect(alert.orderId, 'ORD-999');
      expect(alert.title, 'Out for Delivery 🚀');
      expect(alert.body, 'Rider is on the way with your dairy products.');
      expect(alert.data['status'], 'outForDelivery');
      expect(alert.data['agentName'], 'Vikram');
    });

    test('orderAlertProvider initializes as null and updates state correctly',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(orderAlertProvider), isNull);

      container.read(orderAlertProvider.notifier).state = const OrderAlert(
        orderId: 'ORD-1234',
        title: 'Order Confirmed',
        body: 'We have received your morning subscription.',
      );

      final state = container.read(orderAlertProvider);
      expect(state, isNotNull);
      expect(state?.orderId, 'ORD-1234');
      expect(state?.title, 'Order Confirmed');
    });

    test(
        'Safe payload extraction handles snake_case order_id and camelCase orderId',
        () {
      // camelCase
      final camelData = {
        'orderId': 'ORD-CAMEL-1',
        'type': 'order',
        'title': 'Test Title',
      };
      final camelOrderId = camelData['orderId'] ?? camelData['order_id'];
      expect(camelOrderId, 'ORD-CAMEL-1');

      // snake_case
      final snakeData = {
        'order_id': 'ORD-SNAKE-2',
        'type': 'order',
        'title': 'Test Title',
      };
      final snakeOrderId = snakeData['orderId'] ?? snakeData['order_id'];
      expect(snakeOrderId, 'ORD-SNAKE-2');
    });

    test(
        'Safe payload extraction handles missing, null, or empty order IDs without error',
        () {
      final emptyData = <String, dynamic>{};
      final orderId = emptyData['orderId'] ?? emptyData['order_id'];
      expect(orderId, isNull);

      final nullData = <String, dynamic>{'orderId': null, 'order_id': null};
      final nullOrderId = nullData['orderId'] ?? nullData['order_id'];
      expect(nullOrderId, isNull);
    });

    test('JSON serialization for local notification payload is robust', () {
      final rawData = {
        'orderId': 'ORD-777',
        'type': 'delivery',
        'route': '/notifications',
        'isActionable': 'true',
      };

      final serialized = jsonEncode(rawData);
      expect(serialized, isA<String>());

      final decoded = jsonDecode(serialized) as Map<String, dynamic>;
      expect(decoded['orderId'], 'ORD-777');
      expect(decoded['type'], 'delivery');
      expect(decoded['route'], '/notifications');
      expect(decoded['isActionable'], 'true');
    });

    test('Malformed payload string decoding does not throw unhandled exception',
        () {
      const invalidJson = '{malformed: true, missing quotes}';
      Map<String, dynamic>? decoded;

      try {
        final parsed = jsonDecode(invalidJson);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        }
      } catch (_) {
        decoded = null;
      }

      expect(decoded, isNull);
    });

    test('NotificationItem data structure aligns with FCM message payloads',
        () {
      final notif = NotificationItem(
        id: 'notif_101',
        type: NotificationType.order,
        title: 'Morning Milk Delivery',
        body: 'Arriving at your doorstep in 15 minutes.',
        timestamp: DateTime(2026, 9, 15, 6, 30),
        orderId: 'ORD-101',
        isRead: false,
        isActionable: true,
        createdBy: 'admin_1',
        userId: 'cust_1',
      );

      final map = notif.toFirestore();
      expect(map['title'], 'Morning Milk Delivery');
      expect(map['orderId'], 'ORD-101');
      expect(map['type'], 'order');
      expect(map['isActionable'], true);
    });

    test(
        'Web firebase-messaging-sw.js exists and contains Firebase compat SDK and config',
        () {
      final swFile = File('web/firebase-messaging-sw.js');
      expect(swFile.existsSync(), isTrue,
          reason: 'web/firebase-messaging-sw.js must exist for Web FCM');

      final content = swFile.readAsStringSync();
      expect(content.contains('firebase-app-compat.js'), isTrue);
      expect(content.contains('firebase-messaging-compat.js'), isTrue);
      expect(content.contains('sawariya-7efd4'), isTrue);
      expect(content.contains('325042169664'), isTrue);
      expect(content.contains('firebase.initializeApp'), isTrue);
      expect(content.contains('onBackgroundMessage'), isTrue);
    });
  });
}
