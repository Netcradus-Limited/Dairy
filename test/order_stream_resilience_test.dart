import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart' hide Order;
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/services/order_service.dart';

void main() {
  group('BUG-001: OrderService streamOrdersForUser Resilience & Caching Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderService orderService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      orderService = OrderService(firestore: fakeFirestore);
    });

    test('streamOrdersForUser returns empty stream immediately for empty userId', () async {
      final stream = orderService.streamOrdersForUser('');
      final orders = await stream.first;
      expect(orders, isEmpty);
    });

    test('streamOrdersForUser returns empty stream immediately for whitespace userId', () async {
      final stream = orderService.streamOrdersForUser('   ');
      final orders = await stream.first;
      expect(orders, isEmpty);
    });

    test('streamOrdersForUser streams orders and sorts newest first', () async {
      const userId = 'user_test_123';

      final olderDate = DateTime.now().subtract(const Duration(days: 2));
      final newerDate = DateTime.now().subtract(const Duration(hours: 1));

      await fakeFirestore.collection('orders').doc('order_1').set({
        'userId': userId,
        'orderCode': 'ORD001',
        'subtotal': 100.0,
        'deliveryCharge': 0.0,
        'discount': 0.0,
        'totalAmount': 100.0,
        'status': 'Pending',
        'items': [],
        'orderDate': Timestamp.fromDate(olderDate),
      });

      await fakeFirestore.collection('orders').doc('order_2').set({
        'userId': userId,
        'orderCode': 'ORD002',
        'subtotal': 200.0,
        'deliveryCharge': 0.0,
        'discount': 0.0,
        'totalAmount': 200.0,
        'status': 'Delivered',
        'items': [],
        'orderDate': Timestamp.fromDate(newerDate),
      });

      final stream = orderService.streamOrdersForUser(userId);
      final firstEmit = await stream.first;

      expect(firstEmit.length, equals(2));
      expect(firstEmit.first.id, equals('order_2'), reason: 'Newer order must appear first');
      expect(firstEmit.last.id, equals('order_1'), reason: 'Older order must appear second');
    });

    test('streamOrdersForUser immediately emits in-memory cached orders to new subscriber', () async {
      const userId = 'user_cached_456';
      final now = DateTime.now();

      await fakeFirestore.collection('orders').doc('order_cached_1').set({
        'userId': userId,
        'orderCode': 'CSH001',
        'subtotal': 350.0,
        'deliveryCharge': 30.0,
        'discount': 0.0,
        'totalAmount': 380.0,
        'status': 'Confirmed',
        'items': [],
        'orderDate': Timestamp.fromDate(now),
      });

      // First subscriber to populate cache
      final sub1 = orderService.streamOrdersForUser(userId);
      final orders1 = await sub1.first;
      expect(orders1.length, equals(1));
      expect(orders1.first.id, equals('order_cached_1'));

      // Second subscriber receives cached items immediately on listen
      final sub2 = orderService.streamOrdersForUser(userId);
      final completer = Completer<List<Order>>();
      final subscription = sub2.listen((orders) {
        if (!completer.isCompleted) {
          completer.complete(orders);
        }
      });

      final cachedOrders = await completer.future.timeout(const Duration(milliseconds: 200));
      await subscription.cancel();

      expect(cachedOrders.length, equals(1));
      expect(cachedOrders.first.id, equals('order_cached_1'));
    });
  });
}
