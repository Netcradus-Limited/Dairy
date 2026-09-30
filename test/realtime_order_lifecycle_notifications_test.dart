import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/services/notification_service.dart';
import 'package:dairy_app/services/order_service.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testAddress = Address(
    id: 'addr_test_1',
    label: 'Home',
    fullName: 'Rohan Sharma',
    mobileNumber: '+91 9876543210',
    houseFlat: 'Flat 101, Galaxy Heights',
    streetArea: 'Scheme 78, Vijay Nagar',
    city: 'Indore',
    state: 'Madhya Pradesh',
    pinCode: '452010',
    latitude: 22.7533,
    longitude: 75.8937,
  );

  const customerUser = User(
    id: 'cust_rohan_1',
    name: 'Rohan Sharma',
    phone: '+91 9876543210',
    role: 'customer',
  );

  const deliveryAgentUser = User(
    id: 'agent_suresh_1',
    name: 'Suresh Delivery',
    phone: '+91 9123456789',
    role: 'delivery',
  );

  const adminUser = User(
    id: 'admin_boss_1',
    name: 'Admin Boss',
    phone: '+91 9999999999',
    role: 'admin',
  );

  const dummyProduct = Product(
    id: 'prod_milk_1',
    title: 'Fresh Cow Milk',
    unit: '1 Litre',
    price: 65.0,
    imageUrl: 'https://example.com/milk.png',
    categoryId: 'milk',
    categoryName: 'Milk',
  );

  const cartItem = CartItem(
    product: dummyProduct,
    quantity: 2,
  );

  group('Real-Time Order Lifecycle Events & Notifications Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderService orderService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      orderService = OrderService(firestore: fakeFirestore);

      // Seed Admin user
      await fakeFirestore.collection('users').doc(adminUser.id).set({
        'name': adminUser.name,
        'role': 'admin',
        'isAdmin': true,
      });

      // Seed Delivery Agent user (both in users and delivery_agents)
      await fakeFirestore.collection('users').doc(deliveryAgentUser.id).set({
        'name': deliveryAgentUser.name,
        'role': 'delivery',
        'isOnline': true,
      });
      await fakeFirestore.collection('delivery_agents').doc(deliveryAgentUser.id).set({
        'name': deliveryAgentUser.name,
        'isOnline': true,
        'status': 'onDuty',
      });

      // Seed Customer user
      await fakeFirestore.collection('users').doc(customerUser.id).set({
        'name': customerUser.name,
        'role': 'customer',
      });
    });

    test('1. Customer places new order -> Admin receives immediate notification with order details', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      expect(order, isNotNull);
      final orderId = order.id;

      // Verify Admin notification was created
      final notifId = 'order_${orderId}_created';
      final adminNotifDoc = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .doc(notifId)
          .get();

      expect(adminNotifDoc.exists, true, reason: 'Admin should receive new order notification');
      final notifData = adminNotifDoc.data()!;
      expect(notifData['title'], contains('New Order Received'));
      expect(notifData['body'], contains(customerUser.name));
      expect(notifData['body'], contains('160'));
      expect(notifData['body'], contains('COD'));
      expect(notifData['orderId'], orderId);
      expect(notifData['route'], '/admin/orders');
      expect(notifData['isRead'], false);
      expect(notifData['isActionable'], true);
    });

    test('2. Admin assigns delivery agent -> Delivery agent receives immediate notification', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      // Confirm and assign agent
      await orderService.approveAndAssignOrder(
        order.id,
        deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      // Verify order updated with assignment in Firestore
      final updatedOrder = await orderService.getOrderById(order.id);
      expect(updatedOrder?.assignedAgentId, deliveryAgentUser.id);

      // Verify delivery agent received assignment notification
      final notifId = 'delivery_${order.id}_assigned';
      final agentNotifDoc = await fakeFirestore
          .collection('users')
          .doc(deliveryAgentUser.id)
          .collection('notifications')
          .doc(notifId)
          .get();

      expect(agentNotifDoc.exists, true, reason: 'Delivery agent must receive assignment notification');
      final notifData = agentNotifDoc.data()!;
      expect(notifData['title'], contains('New Delivery Assignment'));
      expect(notifData['orderId'], order.id);
      expect(notifData['route'], startsWith('/delivery'));
      expect(notifData['body'], contains(testAddress.fullName));
      expect(notifData['body'], contains(testAddress.streetArea));
    });

    test('3. Delivery agent accepts order -> Admin receives immediate notification with agent name', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      await orderService.approveAndAssignOrder(
        order.id,
        deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      // Agent accepts order
      await orderService.acceptOrder(
        order.id,
        deliveryAgentUser.id,
      );

      // Verify Admin receives accepted notification
      final notifId = 'delivery_${order.id}_orderAccepted';
      final adminNotifDoc = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .doc(notifId)
          .get();

      expect(adminNotifDoc.exists, true, reason: 'Admin must receive agent acceptance notification');
      final notifData = adminNotifDoc.data()!;
      expect(notifData['title'], contains('Order Accepted'));
      expect(notifData['body'], contains('Delivery agent ${deliveryAgentUser.name} accepted Order #${order.orderCode}'));
      expect(notifData['orderId'], order.id);
      expect(notifData['assignedAgentId'], deliveryAgentUser.id);
    });

    test('4. Delivery agent starts delivery -> Firestore status outForDelivery, Admin & Customer notified', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      await orderService.approveAndAssignOrder(
        order.id,
        deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      await orderService.acceptOrder(
        order.id,
        deliveryAgentUser.id,
      );

      // Admin sets Preparing after acceptance
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);

      // Delivery agent updates status to outForDelivery
      await orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery);

      // Verify Firestore status
      final orderDoc = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(orderDoc.data()!['status'], 'outForDelivery');

      // Verify Admin received outForDelivery notification
      final adminNotifId = 'delivery_${order.id}_deliveryStarted';
      final adminNotifDoc = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .doc(adminNotifId)
          .get();

      expect(adminNotifDoc.exists, true, reason: 'Admin must receive out-for-delivery notification');
      expect(adminNotifDoc.data()!['body'], contains('is now out for delivery'));

      // Verify Customer received outForDelivery notification
      final custNotifId = 'order_${order.id}_outForDelivery';
      final custNotifDoc = await fakeFirestore
          .collection('users')
          .doc(customerUser.id)
          .collection('notifications')
          .doc(custNotifId)
          .get();

      expect(custNotifDoc.exists, true, reason: 'Customer must receive out-for-delivery tracking notification');
      expect(custNotifDoc.data()!['route'], '/orders/${order.id}');
      expect(custNotifDoc.data()!['body'], contains('out for delivery'));
    });

    test('5. Delivery agent marks delivered -> Order status delivered, Admin & Customer notified, read-only', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      await orderService.approveAndAssignOrder(
        order.id,
        deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      await orderService.acceptOrder(
        order.id,
        deliveryAgentUser.id,
      );

      // Admin sets Preparing
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);

      // Agent starts delivery
      await orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery);

      // Agent marks delivered
      await orderService.markOrderDelivered(
        orderId: order.id,
        agentId: deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      // Verify Firestore order status is delivered
      final orderDoc = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(orderDoc.data()!['status'], 'delivered');

      // Verify Admin received delivered notification
      final adminNotifId = 'delivery_${order.id}_deliveryConfirmed';
      final adminNotifDoc = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .doc(adminNotifId)
          .get();

      expect(adminNotifDoc.exists, true, reason: 'Admin must receive delivered notification');
      expect(adminNotifDoc.data()!['body'], contains('has been delivered'));

      // Verify Customer received delivered notification
      final custNotifId = 'order_${order.id}_delivered';
      final custNotifDoc = await fakeFirestore
          .collection('users')
          .doc(customerUser.id)
          .collection('notifications')
          .doc(custNotifId)
          .get();

      expect(custNotifDoc.exists, true, reason: 'Customer must receive delivered notification');
      expect(custNotifDoc.data()!['body'], contains('has been delivered'));
    });

    test('6. Deduplication: Retrying lifecycle notifications produces deterministic doc IDs and no duplicates', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      await orderService.approveAndAssignOrder(
        order.id,
        deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );

      // Trigger accept order twice
      await orderService.acceptOrder(
        order.id,
        deliveryAgentUser.id,
      );
      await orderService.acceptOrder(
        order.id,
        deliveryAgentUser.id,
      );

      final notifDoc = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .doc('delivery_${order.id}_orderAccepted')
          .get();

      expect(notifDoc.exists, true, reason: 'Notification should exist');

      final allAdminNotifs = await fakeFirestore
          .collection('users')
          .doc(adminUser.id)
          .collection('notifications')
          .get();

      final acceptedNotifs = allAdminNotifs.docs
          .where((d) => d.id == 'delivery_${order.id}_orderAccepted')
          .toList();

      expect(acceptedNotifs.length, 1,
          reason: 'Idempotent deterministic doc ID prevents duplicates');
    });

    test('7. Notification routing: Admin tapping any order notification is routed to /admin/orders', () {
      // Order created destination
      final routeCreated = NotificationService.resolveNotificationRoute(
        user: adminUser,
        explicitRoute: '/admin/orders',
        orderId: 'ORD-999',
        type: 'order',
      );
      expect(routeCreated, '/admin/orders');

      // Delivery event destination with /delivery route
      final routeDelivery = NotificationService.resolveNotificationRoute(
        user: adminUser,
        explicitRoute: '/delivery',
        orderId: 'ORD-999',
        type: 'delivery',
      );
      // Admin should be routed to /admin/orders instead of delivery panel
      expect(routeDelivery, '/admin/orders');
    });

    test('8. Security / RBAC: Customer only receives their notifications, agent only receives theirs', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );

      // Verify other delivery agents or unrelated customers do not have the notification
      final otherCustomerNotif = await fakeFirestore
          .collection('users')
          .doc('unrelated_customer')
          .collection('notifications')
          .doc('order_${order.id}_created')
          .get();

      expect(otherCustomerNotif.exists, false);

      final otherAgentNotif = await fakeFirestore
          .collection('users')
          .doc('unrelated_agent')
          .collection('notifications')
          .doc('delivery_${order.id}_assigned')
          .get();

      expect(otherAgentNotif.exists, false);
    });
  });

  group('Order Lifecycle State Machine & Terminal Enforcement Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderService orderService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      orderService = OrderService(firestore: fakeFirestore);

      // Seed Delivery Agent (online)
      await fakeFirestore.collection('delivery_agents').doc(deliveryAgentUser.id).set({
        'name': deliveryAgentUser.name,
        'isOnline': true,
        'status': 'onDuty',
      });
      await fakeFirestore.collection('users').doc(deliveryAgentUser.id).set({
        'name': deliveryAgentUser.name,
        'role': 'delivery',
        'isOnline': true,
      });

      // Seed Offline Agent
      await fakeFirestore.collection('delivery_agents').doc('offline_agent_1').set({
        'name': 'Offline Agent',
        'isOnline': false,
        'status': 'offDuty',
      });
      await fakeFirestore.collection('users').doc('offline_agent_1').set({
        'name': 'Offline Agent',
        'role': 'delivery',
        'isOnline': false,
      });
    });

    test('VALID: Full sequential lifecycle PENDING -> CONFIRMED -> ASSIGNED -> ACCEPTED -> PREPARING -> OUT_FOR_DELIVERY -> DELIVERED', () async {
      // 1. PENDING
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      var snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'].toString().toLowerCase(), anyOf('pending', 'placed'));

      // 2. CONFIRMED
      await orderService.updateOrderStatus(order.id, OrderStatus.confirmed);
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'confirmed');

      // 3. ASSIGNED
      await orderService.assignDeliveryAgent(order.id, deliveryAgentUser.id, agentName: deliveryAgentUser.name);
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'assigned');

      // 4. ACCEPTED
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'accepted');
      expect(snap.data()!['acceptedAt'], isNotNull);

      // 5. PREPARING (Admin sets preparing after acceptance)
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing, callerIsAdmin: true);
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'preparing');

      // 6. OUT_FOR_DELIVERY (Delivery agent starts delivery)
      await orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery);
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'outForDelivery');

      // 7. DELIVERED (Delivery agent marks delivered)
      await orderService.markOrderDelivered(
        orderId: order.id,
        agentId: deliveryAgentUser.id,
        agentName: deliveryAgentUser.name,
      );
      snap = await fakeFirestore.collection('orders').doc(order.id).get();
      expect(snap.data()!['status'], 'delivered');
    });

    test('INVALID: PENDING -> PREPARING is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.preparing),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: PENDING -> DELIVERED is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: CONFIRMED -> DELIVERED is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.updateOrderStatus(order.id, OrderStatus.confirmed);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: ASSIGNED -> OUT_FOR_DELIVERY is rejected without Preparing', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: ASSIGNED -> DELIVERED is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: ACCEPTED -> DELIVERED is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: PREPARING -> DELIVERED is rejected without Out for Delivery', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);

      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered),
        throwsA(isA<StateError>()),
      );
      expect(
        () => orderService.markOrderDelivered(orderId: order.id, agentId: deliveryAgentUser.id),
        throwsA(isA<StateError>()),
      );
    });

    test('DELIVERED TERMINAL LOCK: DELIVERED -> any status mutation is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);
      await orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery);
      await orderService.markOrderDelivered(orderId: order.id, agentId: deliveryAgentUser.id);

      // Attempt status mutations on delivered order
      for (final s in [OrderStatus.placed, OrderStatus.confirmed, OrderStatus.assigned, OrderStatus.preparing, OrderStatus.outForDelivery, OrderStatus.cancelled]) {
        expect(
          () => orderService.updateOrderStatus(order.id, s),
          throwsA(isA<StateError>()),
          reason: 'Cannot mutate delivered order to $s',
        );
      }

      // Cannot reassign delivered order
      expect(
        () => orderService.assignDeliveryAgent(order.id, deliveryAgentUser.id),
        throwsA(isA<StateError>()),
        reason: 'Delivered order cannot be reassigned',
      );

      // Cannot accept delivered order
      expect(
        () => orderService.acceptOrder(order.id, deliveryAgentUser.id),
        throwsA(isA<StateError>()),
        reason: 'Delivered order cannot be accepted again',
      );
    });

    test('Admin cannot set PREPARING before agent acceptance', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);

      // Order is assigned, NOT accepted yet
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.preparing, callerIsAdmin: true),
        throwsA(isA<StateError>()),
      );
    });

    test('Admin cannot force OUT_FOR_DELIVERY or DELIVERED', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);

      // Admin tries to force outForDelivery
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery, callerIsAdmin: true),
        throwsA(isA<StateError>()),
      );

      // Admin tries to force delivered
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.delivered, callerIsAdmin: true),
        throwsA(isA<StateError>()),
      );
    });

    test('Offline agent cannot be assigned', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.updateOrderStatus(order.id, OrderStatus.confirmed);

      expect(
        () => orderService.assignDeliveryAgent(order.id, 'offline_agent_1'),
        throwsA(isA<StateError>()),
      );
    });

    test('Non-assigned agent cannot accept or mark delivered', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);

      // Imposter agent tries to accept
      expect(
        () => orderService.acceptOrder(order.id, 'imposter_agent'),
        throwsA(isA<StateError>()),
      );

      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      await orderService.updateOrderStatus(order.id, OrderStatus.preparing);
      await orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery);

      // Imposter agent tries to mark delivered
      expect(
        () => orderService.markOrderDelivered(orderId: order.id, agentId: 'imposter_agent'),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: CONFIRMED -> OUT_FOR_DELIVERY is rejected', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.updateOrderStatus(order.id, OrderStatus.confirmed);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: ACCEPTED -> OUT_FOR_DELIVERY is rejected without Preparing', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      await orderService.approveAndAssignOrder(order.id, deliveryAgentUser.id);
      await orderService.acceptOrder(order.id, deliveryAgentUser.id);
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery),
        throwsA(isA<StateError>()),
      );
    });

    test('INVALID: legacy pickup status cannot transition to outForDelivery', () async {
      final order = await orderService.placeOrder(
        userId: customerUser.id,
        items: [cartItem],
        deliveryAddress: testAddress,
        paymentMethod: 'COD',
      );
      // Artificially inject legacy 'pickup' in Firestore
      await fakeFirestore.collection('orders').doc(order.id).update({'status': 'pickup'});
      expect(
        () => orderService.updateOrderStatus(order.id, OrderStatus.outForDelivery),
        throwsA(isA<StateError>()),
      );
    });

    test('DeliveryOrder mapping: assigned with acceptedAt maps to DeliveryOrderStatus.accepted, preparing maps to DeliveryOrderStatus.preparing', () async {
      final unacceptedOrder = Order(
        id: 'ord_map_1',
        items: [],
        subtotal: 100,
        deliveryCharge: 0,
        discount: 0,
        totalAmount: 100,
        status: OrderStatus.assigned,
        orderDate: DateTime.now(),
        deliveryAddress: testAddress,
      );
      final acceptedOrder = unacceptedOrder.copyWith(
        acceptedAt: DateTime.now(),
      );
      final preparingOrder = unacceptedOrder.copyWith(
        status: OrderStatus.preparing,
        acceptedAt: DateTime.now(),
      );

      final deliveryUnaccepted = deliveryOrderFromOrder(unacceptedOrder);
      final deliveryAccepted = deliveryOrderFromOrder(acceptedOrder);
      final deliveryPreparing = deliveryOrderFromOrder(preparingOrder);

      expect(deliveryUnaccepted.status, equals(DeliveryOrderStatus.pendingAcceptance));
      expect(deliveryAccepted.status, equals(DeliveryOrderStatus.accepted));
      expect(deliveryPreparing.status, equals(DeliveryOrderStatus.preparing));
    });
  });
}
