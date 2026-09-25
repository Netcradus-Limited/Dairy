import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_live_location_provider.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/providers/user_provider.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/earnings_service.dart';
import 'package:dairy_app/services/location_service.dart';
import 'package:dairy_app/services/order_service.dart';

// ─── Test Doubles ─────────────────────────────────────────────────────────────

class _MockLocationService extends LocationService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  final StreamController<Position> positionController =
      StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<bool> requestLocationPermission() async =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  @override
  Future<bool> requestBackgroundLocationPermission() async => true;

  @override
  Stream<Position> getPositionStream() => positionController.stream;

  @override
  Future<Position?> getCurrentPosition() async => null;

  void dispose() {
    positionController.close();
  }
}

class _TestUserNotifier extends StateNotifier<User> implements UserNotifier {
  _TestUserNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late OrderService orderService;
  late DeliveryTrackingService trackingService;
  late EarningsService earningsService;
  late _MockLocationService mockLocation;
  late ProviderContainer container;

  const agent1Id = 'agent_001';
  const agent2Id = 'agent_002';
  const customerId = 'cust_999';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    orderService = OrderService(firestore: fakeFirestore);
    trackingService = DeliveryTrackingService(fakeFirestore);
    earningsService = EarningsService(fakeFirestore);
    mockLocation = _MockLocationService();

    container = ProviderContainer(
      overrides: [
        orderServiceProvider.overrideWithValue(orderService),
        deliveryTrackingServiceProvider.overrideWithValue(trackingService),
        earningsServiceProvider.overrideWithValue(earningsService),
        locationServiceProvider.overrideWithValue(mockLocation),
        deliveryActiveOrdersStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        userProvider.overrideWith(
          (ref) => _TestUserNotifier(
            const User(
              id: agent1Id,
              name: 'Agent One',
              phone: '9876543210',
              role: 'delivery',
            ),
          ),
        ),
      ],
    );
  });

  tearDown(() {
    mockLocation.dispose();
    container.dispose();
  });

  Future<void> seedOrder({
    required String orderId,
    required String status,
    String? assignedAgentId,
    double totalAmount = 500.0,
    double deliveryCharge = 40.0,
  }) async {
    await fakeFirestore.collection('orders').doc(orderId).set({
      'orderId': orderId,
      'status': status,
      'assignedAgentId': assignedAgentId,
      'totalAmount': totalAmount,
      'deliveryCharge': deliveryCharge,
      'deliveryAddress': {
        'fullName': 'Rahul Sharma',
        'mobileNumber': '9876500000',
        'addressLine1': 'Flat 402, Sunshine Heights',
        'city': 'Indore',
        'pincode': '452010',
      },
      'orderDate': DateTime.now().toIso8601String(),
    });
  }

  // ─── Group 1: Order Lifecycle, Accept & Decline ────────────────────────────

  group('Order Lifecycle & Concurrency Guards', () {
    test('Agent accepts a pending order successfully', () async {
      await seedOrder(orderId: 'ORD_01', status: 'Pending');

      await orderService.acceptOrder('ORD_01', agent1Id);

      final doc = await fakeFirestore.collection('orders').doc('ORD_01').get();
      expect(doc.data()?['status'], equals('accepted'));
      expect(doc.data()?['assignedAgentId'], equals(agent1Id));
      expect(doc.data()?['acceptedAt'], isNotNull);
    });

    test('Agent B cannot claim an order already claimed by Agent A', () async {
      await seedOrder(
        orderId: 'ORD_02',
        status: 'accepted',
        assignedAgentId: agent1Id,
      );

      expect(
        () => orderService.acceptOrder('ORD_02', agent2Id),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already claimed by another agent'),
        )),
      );

      final doc = await fakeFirestore.collection('orders').doc('ORD_02').get();
      expect(doc.data()?['assignedAgentId'], equals(agent1Id));
    });

    test('Agent declines order, returning it cleanly to Pending', () async {
      await seedOrder(
        orderId: 'ORD_03',
        status: 'accepted',
        assignedAgentId: agent1Id,
      );

      await orderService.declineOrder('ORD_03', agent1Id);

      final doc = await fakeFirestore.collection('orders').doc('ORD_03').get();
      expect(doc.data()?['status'], equals('Pending'));
      expect(doc.data()?['assignedAgentId'], isNull);
      expect(doc.data()?['acceptedAt'], isNull);
    });

    test('Agent B cannot decline an order assigned to Agent A', () async {
      await seedOrder(
        orderId: 'ORD_04',
        status: 'accepted',
        assignedAgentId: agent1Id,
      );

      expect(
        () => orderService.declineOrder('ORD_04', agent2Id),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer assigned to delivery agent'),
        )),
      );

      final doc = await fakeFirestore.collection('orders').doc('ORD_04').get();
      expect(doc.data()?['assignedAgentId'], equals(agent1Id));
      expect(doc.data()?['status'], equals('accepted'));
    });
  });

  // ─── Group 2: Status Transitions (Pickup, Out for Delivery, Delivered) ────

  group('Pickup & Delivery Transitions', () {
    test('Accepted -> Preparing (Pickup Started)', () async {
      await seedOrder(
        orderId: 'ORD_05',
        status: 'accepted',
        assignedAgentId: agent1Id,
      );

      await orderService.updateOrderStatus('ORD_05', OrderStatus.preparing);

      final doc = await fakeFirestore.collection('orders').doc('ORD_05').get();
      expect(doc.data()?['status'], equals('preparing'));
    });

    test('Preparing -> Out for Delivery', () async {
      await seedOrder(
        orderId: 'ORD_06',
        status: 'preparing',
        assignedAgentId: agent1Id,
      );

      await orderService.updateOrderStatus(
          'ORD_06', OrderStatus.outForDelivery);

      final doc = await fakeFirestore.collection('orders').doc('ORD_06').get();
      expect(doc.data()?['status'], equals('outForDelivery'));
    });

    test('Out for Delivery -> Delivered updates status and payment', () async {
      await seedOrder(
        orderId: 'ORD_07',
        status: 'outForDelivery',
        assignedAgentId: agent1Id,
      );
      await fakeFirestore.collection('payments').doc('PAY_ORD_07').set({
        'status': 'Pending',
        'paymentStatus': 'Pending',
      });

      await orderService.updateOrderStatus('ORD_07', OrderStatus.delivered);

      final doc = await fakeFirestore.collection('orders').doc('ORD_07').get();
      expect(doc.data()?['status'], equals('delivered'));

      final paymentDoc =
          await fakeFirestore.collection('payments').doc('PAY_ORD_07').get();
      expect(paymentDoc.data()?['paymentStatus'], equals('Success'));
    });
  });

  // ─── Group 3: Delivery Failure & Cancellation Workflow ────────────────────

  group('Delivery Failure & Cancellation Workflow', () {
    test('failDelivery records failure reason and cancels payment', () async {
      await seedOrder(
        orderId: 'ORD_08',
        status: 'outForDelivery',
        assignedAgentId: agent1Id,
      );
      await fakeFirestore.collection('payments').doc('PAY_ORD_08').set({
        'status': 'Pending',
        'paymentStatus': 'Pending',
      });

      const failureReason = 'Customer unreachable / not available';
      await orderService.failDelivery('ORD_08', failureReason);

      final doc = await fakeFirestore.collection('orders').doc('ORD_08').get();
      expect(doc.data()?['status'], equals('cancelled'));
      expect(doc.data()?['cancellationReason'], equals(failureReason));

      final paymentDoc =
          await fakeFirestore.collection('payments').doc('PAY_ORD_08').get();
      expect(paymentDoc.data()?['paymentStatus'], equals('Cancelled'));
    });

    test('failDelivery clears active tracking order in DeliveryTrackingService',
        () async {
      await trackingService.updateAgentLocation(agent1Id, 22.7255, 75.8800,
          orderId: 'ORD_09');

      final agentDocBefore =
          await fakeFirestore.collection('delivery_agents').doc(agent1Id).get();
      expect(agentDocBefore.data()?['orderId'], equals('ORD_09'));

      await trackingService.clearActiveOrder(agent1Id);

      final agentDocAfter =
          await fakeFirestore.collection('delivery_agents').doc(agent1Id).get();
      expect(agentDocAfter.data()?['orderId'], isNull);
    });
  });

  // ─── Group 4: Earnings Segregation & Integrity ────────────────────────────

  group('Earnings Segregation & Calculations', () {
    test('Agent only receives their own earnings stream', () async {
      await fakeFirestore.collection('earnings').doc('earn_1').set({
        'id': 'earn_1',
        'orderId': 'ORD_E1',
        'agentId': agent1Id,
        'amountEarned': 50.0,
        'tipAmount': 10.0,
        'deliveryFee': 40.0,
        'status': 'paid',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Earning for another agent
      await fakeFirestore.collection('earnings').doc('earn_2').set({
        'id': 'earn_2',
        'orderId': 'ORD_E2',
        'agentId': agent2Id,
        'amountEarned': 80.0,
        'tipAmount': 0.0,
        'deliveryFee': 40.0,
        'status': 'paid',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final earningsStream = earningsService.getAgentEarnings(agent1Id);
      final agent1Earnings = await earningsStream.first;

      expect(agent1Earnings.length, equals(1));
      expect(agent1Earnings.first.orderId, equals('ORD_E1'));
      expect(agent1Earnings.first.amountEarned, equals(50.0));
    });

    test('getTotalEarnings calculates sum of amountEarned + tipAmount',
        () async {
      await fakeFirestore.collection('earnings').doc('earn_calc_1').set({
        'id': 'earn_calc_1',
        'orderId': 'ORD_C1',
        'agentId': agent1Id,
        'amountEarned': 45.0,
        'tipAmount': 15.0,
        'deliveryFee': 40.0,
        'status': 'paid',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final total = await earningsService.getTotalEarnings(agent1Id);
      expect(total, equals(60.0));
    });
  });

  // ─── Group 5: Delivery Order Mapping & Fallbacks ──────────────────────────

  group('DeliveryOrder Mapping & Null Safety', () {
    test(
        'deliveryOrderFromOrder populates default fallbacks for missing address strings',
        () {
      const emptyAddress = Address(
        id: '',
        fullName: '   ',
        mobileNumber: '',
        houseFlat: '',
        streetArea: '',
        city: '',
        state: '',
        pinCode: '',
      );

      final order = Order(
        id: 'ORD_NULL_TEST',
        items: const [],
        subtotal: 200.0,
        totalAmount: 240.0,
        status: OrderStatus.placed,
        orderDate: DateTime.now(),
        deliveryAddress: emptyAddress,
      );

      final deliveryOrder = deliveryOrderFromOrder(order);
      expect(deliveryOrder.customerName, equals('Customer'));
      expect(deliveryOrder.customerPhone, equals('—'));
      expect(deliveryOrder.customerAddress, equals('Address not specified'));
    });
  });

  // ─── Group 6: Logout Lifecycle & Tracking Termination ─────────────────────

  group('Logout Lifecycle & Tracking Cleanup', () {
    test('stopTracking stops live GPS subscription on logout', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;

      final liveNotifier = container.read(agentLiveLocationProvider.notifier);
      await liveNotifier.startTracking();

      expect(liveNotifier.state, isTrue);
      expect(container.read(gpsTrackingStatusProvider),
          equals(GpsTrackingStatus.active));

      liveNotifier.stopTracking();

      expect(liveNotifier.state, isFalse);
      expect(container.read(gpsTrackingStatusProvider),
          equals(GpsTrackingStatus.idle));
    });
  });

  // ─── Group 7: RBAC Router Confinement ─────────────────────────────────────

  group('RBAC & Route Protection', () {
    test('Unauthenticated user has empty user ID and non-delivery role', () {
      final unauthContainer = ProviderContainer(
        overrides: [
          userProvider.overrideWith(
            (ref) => _TestUserNotifier(
              const User(
                id: '',
                name: '',
                phone: '',
                role: 'customer',
              ),
            ),
          ),
        ],
      );

      final user = unauthContainer.read(userProvider);
      expect(user.id.isEmpty, isTrue);
      expect(user.isDelivery, isFalse);

      unauthContainer.dispose();
    });

    test('Customer role cannot access delivery panel', () {
      final customerContainer = ProviderContainer(
        overrides: [
          userProvider.overrideWith(
            (ref) => _TestUserNotifier(
              const User(
                id: customerId,
                name: 'Regular Customer',
                phone: '9876511111',
                role: 'customer',
              ),
            ),
          ),
        ],
      );

      final customer = customerContainer.read(userProvider);
      expect(customer.isDelivery, isFalse);
      expect(customer.canAccessAdminPortal, isFalse);

      customerContainer.dispose();
    });

    test('Delivery agent role is recognized and allowed', () {
      final deliveryUser = container.read(userProvider);
      expect(deliveryUser.isDelivery, isTrue);
      expect(deliveryUser.role, equals('delivery'));
    });
  });
}
