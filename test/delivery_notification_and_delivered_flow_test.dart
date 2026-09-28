import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:dairy_app/features/delivery_panel/screens/delivery_order_detail_view.dart';
import 'package:dairy_app/features/orders/order_details_screen.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/notification_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/repositories/notification_repository.dart';
import 'package:dairy_app/services/notification_service.dart';
import 'package:dairy_app/services/order_service.dart';

class MockOrderService extends OrderService {
  MockOrderService({super.firestore});

  String? lastMarkedDeliveredOrderId;
  String? lastMarkedDeliveredAgentId;
  String? lastMarkedDeliveredAgentName;
  int markDeliveredCallCount = 0;

  @override
  Future<void> markOrderDelivered({
    required String orderId,
    required String agentId,
    String? agentName,
  }) async {
    markDeliveredCallCount++;
    lastMarkedDeliveredOrderId = orderId;
    lastMarkedDeliveredAgentId = agentId;
    lastMarkedDeliveredAgentName = agentName;
    return super.markOrderDelivered(
      orderId: orderId,
      agentId: agentId,
      agentName: agentName,
    );
  }
}

class MockDeliveryAgentNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryAgentNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserNotifier extends StateNotifier<User> implements UserNotifier {
  MockUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testAddress = Address(
    id: 'addr_1',
    label: 'Home',
    fullName: 'Rahul Sharma',
    mobileNumber: '+91 9876543210',
    houseFlat: 'Flat 402, Green Heights',
    streetArea: 'Scheme No 54, Vijay Nagar',
    city: 'Indore',
    state: 'Madhya Pradesh',
    pinCode: '452010',
    latitude: 22.7533,
    longitude: 75.8937,
  );

  const testDeliveryAgent = DeliveryAgent(
    id: 'agent_999',
    name: 'Suresh Kumar',
    phone: '+91 9876543210',
    vehicle: 'Bike',
    vehicleNumber: 'MP 09 AB 1234',
    assignedZone: 'Indore',
    status: DeliveryStatus.onDuty,
    totalDeliveriesToday: 0,
    completedDeliveriesToday: 0,
    earningsToday: 0.0,
  );

  const deliveryUser = User(
    id: 'agent_999',
    name: 'Suresh Kumar',
    phone: '+91 9876543210',
    role: 'delivery',
  );

  const customerUser = User(
    id: 'cust_111',
    name: 'Rahul Sharma',
    phone: '+91 9876543210',
    role: 'customer',
  );

  const adminUser = User(
    id: 'admin_1',
    name: 'Admin Boss',
    phone: '+91 9999999999',
    role: 'superadmin',
  );

  final testOrderActive = Order(
    id: 'ORD-101',
    orderCode: 'SWD101',
    userId: 'cust_111',
    items: const [
      CartItem(
        product: Product(
          id: 'p1',
          title: 'Fresh Milk 1L',
          price: 60.0,
          originalPrice: 65.0,
          description: 'Milk',
          imageUrl: '',
          categoryId: 'milk',
          categoryName: 'Milk',
          unit: '1L',
          inStock: true,
          rating: 4.5,
          reviewCount: 10,
        ),
        quantity: 2,
      )
    ],
    subtotal: 120.0,
    totalAmount: 120.0,
    status: OrderStatus.outForDelivery,
    orderDate: DateTime(2026, 9, 28, 10, 0),
    deliveryAddress: testAddress,
    paymentMethod: 'Cash on Delivery',
    paymentStatus: 'Pending',
    assignedAgentId: 'agent_999',
    assignedAgentName: 'Suresh Kumar',
  );

  final testDeliveryOrderActive = DeliveryOrder(
    id: 'ORD-101',
    orderId: 'ORD-101',
    orderCode: 'SWD101',
    customerName: 'Rahul Sharma',
    customerPhone: '+91 9876543210',
    customerAddress: 'Flat 402, Green Heights, Indore',
    pickupLocation: 'Sawariya Central Hub',
    pickupPhone: '+91 9999988888',
    items: const ['Fresh Milk 1L x2'],
    amount: 120.0,
    deliveryFee: 0.0,
    status: DeliveryOrderStatus.outForDelivery,
    orderTime: DateTime(2026, 9, 28, 10, 0),
    paymentMethod: 'Cash on Delivery',
    paymentStatus: 'Pending',
    distance: '2.5 km',
    estimatedTime: '~10 min',
    assignedAgentId: 'agent_999',
  );

  group('1. Notification Routing Tests', () {
    test('Delivery assignment notification routes delivery boy directly to delivery order detail', () {
      final route = NotificationService.resolveNotificationRoute(
        user: deliveryUser,
        orderId: 'ORD-101',
      );
      expect(route, '/delivery/orders/ORD-101');
    });

    test('Customer order notification routes customer directly to customer order detail', () {
      final route = NotificationService.resolveNotificationRoute(
        user: customerUser,
        orderId: 'ORD-101',
      );
      expect(route, '/orders/ORD-101');
    });

    test('Admin order notification routes admin to admin orders panel', () {
      final route = NotificationService.resolveNotificationRoute(
        user: adminUser,
        orderId: 'ORD-101',
        explicitRoute: '/admin/orders',
      );
      expect(route, '/admin/orders');
    });
  });

  group('2. Delivery Panel Order Detail UI Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockOrderService mockOrderService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockOrderService = MockOrderService(firestore: fakeFirestore);
    });

    testWidgets('Delivery order shows "Delivered" instead of "Track Order"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(testDeliveryAgent)),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testDeliveryOrderActive,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Primary button must be Delivered
      expect(find.text('Delivered'), findsOneWidget);

      // Must show order information
      expect(find.text('#SWD101'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Cash on Delivery'), findsOneWidget);
      expect(find.text('₹120'), findsWidgets);

      // Must NOT show customer-only actions
      expect(find.text('Track Order'), findsNothing);
      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('Tapping "Delivered" in DeliveryOrderDetailView calls markOrderDelivered', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed order in fake firestore
      await fakeFirestore.collection('orders').doc('ORD-101').set({
        'orderCode': 'SWD101',
        'userId': 'cust_111',
        'status': 'out_for_delivery',
        'assignedAgentId': 'agent_999',
        'assignedAgentName': 'Suresh Kumar',
        'totalAmount': 120.0,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWithValue(mockOrderService),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(testDeliveryAgent)),
          ],
          child: MaterialApp(
            home: DeliveryOrderDetailView(
              order: testDeliveryOrderActive,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delivered'));
      await tester.pump();

      expect(mockOrderService.markDeliveredCallCount, 1);
      expect(mockOrderService.lastMarkedDeliveredOrderId, 'ORD-101');
      expect(mockOrderService.lastMarkedDeliveredAgentId, 'agent_999');
    });

    testWidgets('Customer view of OrderDetailsScreen shows "Track Order" and NEVER "Delivered"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWith((ref) => MockUserNotifier(customerUser)),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(DeliveryAgent.empty(''))),
            orderServiceProvider.overrideWithValue(mockOrderService),
          ],
          child: MaterialApp(
            home: OrderDetailsScreen(order: testOrderActive),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Customer sees Track Order
      expect(find.text('Track Order'), findsOneWidget);
      // Customer must NOT see delivery completion button
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('Delivery staff view of OrderDetailsScreen shows "Delivered" and NEVER "Track Order"', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWith((ref) => MockUserNotifier(deliveryUser)),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(testDeliveryAgent)),
            orderServiceProvider.overrideWithValue(mockOrderService),
          ],
          child: MaterialApp(
            home: OrderDetailsScreen(order: testOrderActive),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delivery staff sees Delivered button
      expect(find.text('Delivered'), findsOneWidget);
      // Delivery staff must NOT see Track Order or Cancel Order
      expect(find.text('Track Order'), findsNothing);
      expect(find.text('Cancel Order'), findsNothing);
    });

    testWidgets('Tapping "Delivered" in OrderDetailsScreen calls markOrderDelivered', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed order in fake firestore
      await fakeFirestore.collection('orders').doc('ORD-101').set({
        'orderCode': 'SWD101',
        'userId': 'cust_111',
        'status': 'out_for_delivery',
        'assignedAgentId': 'agent_999',
        'assignedAgentName': 'Suresh Kumar',
        'totalAmount': 120.0,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWith((ref) => MockUserNotifier(deliveryUser)),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(testDeliveryAgent)),
            orderServiceProvider.overrideWithValue(mockOrderService),
          ],
          child: MaterialApp(
            home: OrderDetailsScreen(order: testOrderActive),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delivered'));
      await tester.pump();

      expect(mockOrderService.markDeliveredCallCount, 1);
      expect(mockOrderService.lastMarkedDeliveredOrderId, 'ORD-101');
      expect(mockOrderService.lastMarkedDeliveredAgentId, 'agent_999');
    });

    testWidgets('Already delivered order in OrderDetailsScreen displays delivered completion state and cannot be clicked again', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deliveredOrder = testOrderActive.copyWith(status: OrderStatus.delivered);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWith((ref) => MockUserNotifier(deliveryUser)),
            deliveryAgentProvider.overrideWith((ref) => MockDeliveryAgentNotifier(testDeliveryAgent)),
            orderServiceProvider.overrideWithValue(mockOrderService),
          ],
          child: MaterialApp(
            home: OrderDetailsScreen(order: deliveredOrder),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows Delivered status badge/banner
      expect(find.text('Delivered'), findsWidgets);
      // Completed banner contains check circle icon
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      // No action buttons like Track Order, Cancel Order, or submission button
      expect(find.text('Track Order'), findsNothing);
      expect(find.text('Cancel Order'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('3. Delivered Button Workflow, Security & State Transitions', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderService orderService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      orderService = OrderService(firestore: fakeFirestore);

      // Seed admin user
      await fakeFirestore.collection('users').doc('admin_1').set({
        'name': 'Super Admin',
        'role': 'superadmin',
        'email': 'admin@sawariya.com',
      });

      // Seed active order
      await fakeFirestore.collection('orders').doc('ORD-101').set({
        'orderCode': 'SWD101',
        'userId': 'cust_111',
        'status': 'out_for_delivery',
        'assignedAgentId': 'agent_999',
        'assignedAgentName': 'Suresh Kumar',
        'totalAmount': 120.0,
        'createdAt': DateTime(2026, 9, 28, 10, 0).toIso8601String(),
      });
    });

    test('Assigned delivery boy can mark order delivered and status updates in Firestore', () async {
      await orderService.markOrderDelivered(
        orderId: 'ORD-101',
        agentId: 'agent_999',
        agentName: 'Suresh Kumar',
      );

      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-101').get();
      expect(orderDoc.exists, isTrue);
      expect(orderDoc.data()!['status'], 'delivered');
      expect(orderDoc.data()!['deliveredAt'], isNotNull);
    });

    test('Unassigned delivery boy cannot mark order delivered', () async {
      expect(
        () => orderService.markOrderDelivered(
          orderId: 'ORD-101',
          agentId: 'agent_intruder',
          agentName: 'Intruder Agent',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not assigned to delivery agent'),
        )),
      );

      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-101').get();
      expect(orderDoc.data()!['status'], 'out_for_delivery');
    });

    test('Already delivered order cannot be delivered again', () async {
      // First delivery succeeds
      await orderService.markOrderDelivered(
        orderId: 'ORD-101',
        agentId: 'agent_999',
        agentName: 'Suresh Kumar',
      );

      // Second attempt must fail
      expect(
        () => orderService.markOrderDelivered(
          orderId: 'ORD-101',
          agentId: 'agent_999',
          agentName: 'Suresh Kumar',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already delivered'),
        )),
      );
    });

    test('Cancelled order cannot be marked delivered', () async {
      await fakeFirestore.collection('orders').doc('ORD-101').update({
        'status': 'cancelled',
      });

      expect(
        () => orderService.markOrderDelivered(
          orderId: 'ORD-101',
          agentId: 'agent_999',
          agentName: 'Suresh Kumar',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot deliver cancelled order'),
        )),
      );
    });
  });

  group('4. Notifications Flow & Deduplication Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late NotificationRepository notificationRepo;
    late OrderService orderService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      notificationRepo = NotificationRepository(firestore: fakeFirestore);
      orderService = OrderService(firestore: fakeFirestore);

      // Seed admin
      await fakeFirestore.collection('users').doc('admin_1').set({
        'name': 'Super Admin',
        'role': 'superadmin',
      });

      // Seed order
      await fakeFirestore.collection('orders').doc('ORD-101').set({
        'orderCode': 'SWD101',
        'userId': 'cust_111',
        'status': 'out_for_delivery',
        'assignedAgentId': 'agent_999',
        'assignedAgentName': 'Suresh Kumar',
        'totalAmount': 120.0,
      });
    });

    test('Customer and Admin receive exact required "Order Delivered" notifications', () async {
      await orderService.markOrderDelivered(
        orderId: 'ORD-101',
        agentId: 'agent_999',
        agentName: 'Suresh Kumar',
      );

      // Verify customer notification
      final custNotifDoc = await fakeFirestore
          .collection('users')
          .doc('cust_111')
          .collection('notifications')
          .doc('order_ORD-101_delivered')
          .get();

      expect(custNotifDoc.exists, isTrue);
      expect(custNotifDoc.data()!['title'], 'Order Delivered');
      expect(custNotifDoc.data()!['body'], 'Your order #SWD101 has been delivered.');
      expect(custNotifDoc.data()!['route'], '/orders/ORD-101');
      expect(custNotifDoc.data()!['orderId'], 'ORD-101');

      // Verify admin notification
      final adminNotifDoc = await fakeFirestore
          .collection('users')
          .doc('admin_1')
          .collection('notifications')
          .doc('delivery_ORD-101_deliveryConfirmed')
          .get();

      expect(adminNotifDoc.exists, isTrue);
      expect(adminNotifDoc.data()!['title'], 'Order Delivered');
      expect(adminNotifDoc.data()!['body'], 'Order #SWD101 has been delivered by Suresh Kumar.');
      expect(adminNotifDoc.data()!['route'], '/admin/orders');
      expect(adminNotifDoc.data()!['orderId'], 'ORD-101');
    });

    test('Notification retry with deterministic ID does NOT create duplicate notifications', () async {
      // Send customer notification first time
      await notificationRepo.sendNotificationToUser(
        targetUserId: 'cust_111',
        title: 'Order Delivered',
        body: 'Your order #SWD101 has been delivered.',
        type: NotificationType.order,
        createdBy: 'agent_999',
        orderId: 'ORD-101',
        route: '/orders/ORD-101',
        notificationId: 'order_ORD-101_delivered',
      );

      // Retry sending customer notification (e.g. on network timeout or retry loop)
      await notificationRepo.sendNotificationToUser(
        targetUserId: 'cust_111',
        title: 'Order Delivered',
        body: 'Your order #SWD101 has been delivered.',
        type: NotificationType.order,
        createdBy: 'agent_999',
        orderId: 'ORD-101',
        route: '/orders/ORD-101',
        notificationId: 'order_ORD-101_delivered',
      );

      final custNotifs = await fakeFirestore
          .collection('users')
          .doc('cust_111')
          .collection('notifications')
          .get();

      // Exactly 1 document exists, no duplicates!
      expect(custNotifs.docs.length, 1);
      expect(custNotifs.docs.first.id, 'order_ORD-101_delivered');

      // Retry sending admin notification
      await notificationRepo.sendNotificationToAdmins(
        title: 'Order Delivered',
        body: 'Order #SWD101 has been delivered by Suresh Kumar.',
        type: NotificationType.delivery,
        orderId: 'ORD-101',
        route: '/admin/orders',
        notificationId: 'delivery_ORD-101_deliveryConfirmed',
      );

      await notificationRepo.sendNotificationToAdmins(
        title: 'Order Delivered',
        body: 'Order #SWD101 has been delivered by Suresh Kumar.',
        type: NotificationType.delivery,
        orderId: 'ORD-101',
        route: '/admin/orders',
        notificationId: 'delivery_ORD-101_deliveryConfirmed',
      );

      final adminNotifs = await fakeFirestore
          .collection('users')
          .doc('admin_1')
          .collection('notifications')
          .get();

      // Exactly 1 document exists for admin, no duplicates!
      expect(adminNotifs.docs.length, 1);
      expect(adminNotifs.docs.first.id, 'delivery_ORD-101_deliveryConfirmed');
    });

    test('Customer and admin see Delivered status in their models', () async {
      await orderService.markOrderDelivered(
        orderId: 'ORD-101',
        agentId: 'agent_999',
        agentName: 'Suresh Kumar',
      );

      final orderSnap = await fakeFirestore.collection('orders').doc('ORD-101').get();
      final customerOrder = Order.fromFirestore(orderSnap.data()!, 'ORD-101');
      expect(customerOrder.status, OrderStatus.delivered);
    });
  });
}
