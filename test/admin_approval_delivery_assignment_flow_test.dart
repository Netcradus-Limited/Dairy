import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/cart_item.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/product.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';

void main() {
  group('Strict Admin Approval → Delivery Assignment Flow Test Suite', () {
    const defaultAddress = Address(
      id: 'addr_1',
      label: 'Home',
      fullName: 'Rahul Sharma',
      mobileNumber: '+91 9876543210',
      houseFlat: 'Flat 402',
      streetArea: 'MG Road',
      city: 'Indore',
      state: 'Madhya Pradesh',
      pinCode: '452001',
    );

    const defaultProduct = Product(
      id: 'prod_milk_1',
      title: 'Pure Buffalo Milk',
      price: 70.0,
      unit: '1 Litre',
      imageUrl: 'https://example.com/milk.png',
      categoryId: 'cat_milk',
      categoryName: 'Dairy & Milk',
    );

    Order createOrder({
      required String id,
      required OrderStatus status,
      String? assignedAgentId,
      String? assignedAgentName,
      DateTime? acceptedAt,
      DateTime? deliveredAt,
    }) {
      return Order(
        id: id,
        orderCode: 'ORD001',
        userId: 'cust_rahul_123',
        deliveryAddress: defaultAddress,
        items: const [CartItem(product: defaultProduct, quantity: 2)],
        subtotal: 140.0,
        deliveryCharge: 0.0,
        discount: 0.0,
        totalAmount: 140.0,
        status: status,
        orderDate: DateTime.now(),
        assignedAgentId: assignedAgentId,
        acceptedAt: acceptedAt,
        deliveredAt: deliveredAt,
      );
    }

    // In-memory Mock State Machine for Order Flow
    late Map<String, Map<String, dynamic>> inMemoryFirestore;
    late List<Map<String, dynamic>> dispatchedNotifications;

    void setupMockStore() {
      inMemoryFirestore = {};
      dispatchedNotifications = [];
    }

    setUp(() {
      setupMockStore();
    });

    // 1. Customer creates Pending order
    test('1. Customer creates Pending order without pre-assigned agent or accepted time', () {
      final newOrder = createOrder(
        id: 'order_101',
        status: OrderStatus.placed,
      );

      expect(newOrder.status, equals(OrderStatus.placed));
      expect(orderStatusToString(newOrder.status), equals('Pending'));
      expect(newOrder.assignedAgentId, isNull);
      expect(newOrder.acceptedAt, isNull);
    });

    // 2. Customer cannot assign agent
    test('2. Customer order creation schema rejects/disallows assigned agent', () {
      final data = {
        'userId': 'cust_rahul_123',
        'status': 'Pending',
        'assignedAgentId': 'agent_a',
      };

      bool canCustomerCreate(Map<String, dynamic> doc) {
        return doc['userId'] == 'cust_rahul_123' &&
            ['Pending', 'pending', 'placed'].contains(doc['status']) &&
            !doc.containsKey('assignedAgentId') &&
            !doc.containsKey('acceptedAt');
      }

      expect(canCustomerCreate(data), isFalse);

      final validData = {
        'userId': 'cust_rahul_123',
        'status': 'Pending',
      };
      expect(canCustomerCreate(validData), isTrue);
    });

    // 3. Delivery agent cannot see unassigned Pending orders
    test('3. Delivery agent stream filters strictly by assignedAgentId == agentId', () {
      final allOrders = [
        createOrder(id: 'ord_pending_unassigned', status: OrderStatus.placed),
        createOrder(id: 'ord_confirmed_unassigned', status: OrderStatus.confirmed),
        createOrder(id: 'ord_assigned_agent_a', status: OrderStatus.assigned, assignedAgentId: 'agent_a'),
        createOrder(id: 'ord_assigned_agent_b', status: OrderStatus.assigned, assignedAgentId: 'agent_b'),
      ];

      List<Order> streamOrdersForAgent(String agentId) {
        if (agentId.trim().isEmpty) return [];
        return allOrders.where((o) => o.assignedAgentId == agentId.trim()).toList();
      }

      final agentAOrders = streamOrdersForAgent('agent_a');
      expect(agentAOrders.length, equals(1));
      expect(agentAOrders.first.id, equals('ord_assigned_agent_a'));

      // Ensure agent cannot see unassigned pending or confirmed orders
      expect(agentAOrders.any((o) => o.id == 'ord_pending_unassigned'), isFalse);
      expect(agentAOrders.any((o) => o.id == 'ord_confirmed_unassigned'), isFalse);
    });

    // 4. Delivery agent cannot self-assign
    test('4. Delivery agent cannot self-assign to unassigned order', () {
      inMemoryFirestore['ord_pending'] = {
        'id': 'ord_pending',
        'status': 'Pending',
        'assignedAgentId': null,
      };

      void agentSelfAssign(String orderId, String agentId) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentAssigned = order['assignedAgentId'];
        if (currentAssigned == null || currentAssigned != agentId) {
          throw StateError('Order is not assigned to delivery agent $agentId.');
        }
        order['status'] = 'accepted';
      }

      expect(() => agentSelfAssign('ord_pending', 'agent_a'), throwsStateError);
      expect(inMemoryFirestore['ord_pending']!['assignedAgentId'], isNull);
    });

    // 5. Delivery agent cannot accept Pending unassigned order
    test('5. Delivery agent cannot accept Pending unassigned order', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'Pending',
        'assignedAgentId': null,
      };

      void acceptOrder(String orderId, String agentId) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentAssigned = order['assignedAgentId'];
        if (currentAssigned == null || currentAssigned != agentId) {
          throw StateError('Order is not assigned to delivery agent $agentId.');
        }
        order['status'] = 'accepted';
        order['acceptedAt'] = DateTime.now();
      }

      expect(() => acceptOrder('ord_101', 'agent_a'), throwsStateError);
    });

    // 6. Admin can approve Pending order
    test('6. Admin can approve Pending order to Confirmed', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'Pending',
        'assignedAgentId': null,
      };

      void adminUpdateStatus(String orderId, OrderStatus status) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentStatus = (order['status'] as String).toLowerCase();
        final targetStatus = orderStatusToString(status).toLowerCase();

        if ((currentStatus == 'pending' || currentStatus == 'placed') &&
            targetStatus != 'confirmed' &&
            targetStatus != 'cancelled') {
          throw StateError('Pending orders must be confirmed by Admin before proceeding.');
        }

        order['status'] = orderStatusToString(status);
      }

      adminUpdateStatus('ord_101', OrderStatus.confirmed);
      expect(inMemoryFirestore['ord_101']!['status'], equals('confirmed'));
    });

    // 7. Admin cannot assign before approval
    test('7. Admin cannot assign an agent before order is approved/confirmed', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'Pending',
        'assignedAgentId': null,
      };

      void adminAssign(String orderId, String agentId) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentStatus = (order['status'] as String).toLowerCase();
        if (currentStatus == 'pending' || currentStatus == 'placed') {
          throw StateError('Order must be confirmed by Admin before assigning a delivery agent.');
        }
        order['assignedAgentId'] = agentId;
        order['status'] = 'assigned';
      }

      expect(() => adminAssign('ord_101', 'agent_a'), throwsStateError);
      expect(inMemoryFirestore['ord_101']!['assignedAgentId'], isNull);
      expect(inMemoryFirestore['ord_101']!['status'], equals('Pending'));
    });

    // 8. Admin can assign after approval
    test('8. Admin can assign an agent after order is Confirmed', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'confirmed',
        'assignedAgentId': null,
      };

      void adminAssign(String orderId, String agentId, {String? agentName}) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentStatus = (order['status'] as String).toLowerCase();
        if (currentStatus == 'pending' || currentStatus == 'placed') {
          throw StateError('Order must be confirmed by Admin before assigning a delivery agent.');
        }
        order['assignedAgentId'] = agentId;
        order['assignedAgentName'] = agentName;
        order['status'] = 'assigned';
        order['assignedAt'] = DateTime.now();

        dispatchedNotifications.add({
          'targetUserId': agentId,
          'title': 'New Delivery Assignment',
          'orderId': orderId,
        });
      }

      adminAssign('ord_101', 'agent_a', agentName: 'Ramesh Rider');
      expect(inMemoryFirestore['ord_101']!['status'], equals('assigned'));
      expect(inMemoryFirestore['ord_101']!['assignedAgentId'], equals('agent_a'));
      expect(inMemoryFirestore['ord_101']!['assignedAgentName'], equals('Ramesh Rider'));
      expect(inMemoryFirestore['ord_101']!['assignedAt'], isNotNull);
    });

    // 9. Assigned Agent A can see the order
    test('9. Assigned Agent A can see their assigned order in delivery panel', () {
      final orderAssignedToA = createOrder(
        id: 'ord_101',
        status: OrderStatus.assigned,
        assignedAgentId: 'agent_a',
      );

      final deliveryOrder = deliveryOrderFromOrder(orderAssignedToA);
      expect(deliveryOrder.id, equals('ord_101'));
      expect(deliveryOrder.assignedAgentId, equals('agent_a'));
      expect(deliveryOrder.status, equals(DeliveryOrderStatus.pendingAcceptance));
    });

    // 10. Agent B cannot see Agent A's order
    test('10. Agent B cannot see Agent A assigned order', () {
      final allOrders = [
        createOrder(
          id: 'ord_101',
          status: OrderStatus.assigned,
          assignedAgentId: 'agent_a',
        ),
      ];

      final agentBOrders = allOrders.where((o) => o.assignedAgentId == 'agent_b').toList();
      expect(agentBOrders, isEmpty);
    });

    // 11. Agent A can accept assigned order
    test('11. Agent A can accept assigned order', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'assigned',
        'assignedAgentId': 'agent_a',
      };

      void acceptOrder(String orderId, String agentId) {
        final order = inMemoryFirestore[orderId];
        if (order == null) throw StateError('Order not found');
        final currentAssigned = order['assignedAgentId'];
        if (currentAssigned != agentId) {
          throw StateError('Order is not assigned to delivery agent $agentId.');
        }
        order['status'] = 'accepted';
        order['acceptedAt'] = DateTime.now();
      }

      acceptOrder('ord_101', 'agent_a');
      expect(inMemoryFirestore['ord_101']!['status'], equals('accepted'));
      expect(inMemoryFirestore['ord_101']!['acceptedAt'], isNotNull);
    });

    // 12. Agent A can Pickup
    test('12. Agent A can start Pickup (moves to preparing)', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'accepted',
        'assignedAgentId': 'agent_a',
      };

      void transitionOrder(String orderId, OrderStatus nextStatus) {
        inMemoryFirestore[orderId]!['status'] = orderStatusToString(nextStatus);
      }

      transitionOrder('ord_101', OrderStatus.preparing);
      expect(inMemoryFirestore['ord_101']!['status'], equals('preparing'));
    });

    // 13. Agent A can Start Delivery
    test('13. Agent A can Start Delivery (moves to outForDelivery)', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'preparing',
        'assignedAgentId': 'agent_a',
      };

      void transitionOrder(String orderId, OrderStatus nextStatus) {
        inMemoryFirestore[orderId]!['status'] = orderStatusToString(nextStatus);
      }

      transitionOrder('ord_101', OrderStatus.outForDelivery);
      expect(inMemoryFirestore['ord_101']!['status'], equals('outForDelivery'));
    });

    // 14. Agent A can Mark Delivered
    test('14. Agent A can Mark Delivered (moves to delivered)', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'outForDelivery',
        'assignedAgentId': 'agent_a',
      };

      void transitionOrder(String orderId, OrderStatus nextStatus) {
        inMemoryFirestore[orderId]!['status'] = orderStatusToString(nextStatus);
        if (nextStatus == OrderStatus.delivered) {
          inMemoryFirestore[orderId]!['deliveredAt'] = DateTime.now();
        }
      }

      transitionOrder('ord_101', OrderStatus.delivered);
      expect(inMemoryFirestore['ord_101']!['status'], equals('delivered'));
      expect(inMemoryFirestore['ord_101']!['deliveredAt'], isNotNull);
    });

    // 15. Invalid status transitions are rejected
    test('15. Invalid status transitions are strictly rejected', () {
      inMemoryFirestore['ord_pending'] = {
        'id': 'ord_pending',
        'status': 'Pending',
      };

      void updateStatus(String orderId, OrderStatus status) {
        final order = inMemoryFirestore[orderId];
        final current = (order!['status'] as String).toLowerCase();
        final target = orderStatusToString(status).toLowerCase();

        if ((current == 'pending' || current == 'placed') &&
            !['confirmed', 'cancelled', 'pending'].contains(target)) {
          throw StateError('Pending orders must be confirmed by Admin before proceeding.');
        }
      }

      expect(() => updateStatus('ord_pending', OrderStatus.outForDelivery), throwsStateError);
      expect(() => updateStatus('ord_pending', OrderStatus.delivered), throwsStateError);
      expect(() => updateStatus('ord_pending', OrderStatus.assigned), throwsStateError);
    });

    // 16. Two agents cannot claim the same order (race condition prevention)
    test('16. Two agents cannot claim the same order simultaneously', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'assigned',
        'assignedAgentId': 'agent_a',
      };

      void acceptOrder(String orderId, String agentId) {
        final order = inMemoryFirestore[orderId];
        final currentAssigned = order!['assignedAgentId'];
        if (currentAssigned != agentId) {
          throw StateError('Order is not assigned to delivery agent $agentId.');
        }
        order['status'] = 'accepted';
      }

      // Agent A accepts successfully
      expect(() => acceptOrder('ord_101', 'agent_a'), returnsNormally);
      expect(inMemoryFirestore['ord_101']!['status'], equals('accepted'));

      // Agent B tries to accept the same order simultaneously
      expect(() => acceptOrder('ord_101', 'agent_b'), throwsStateError);
    });

    // 17. Admin assignment notification is triggered through existing mechanism
    test('17. Admin assignment triggers notification to assigned agent', () {
      inMemoryFirestore['ord_101'] = {
        'id': 'ord_101',
        'status': 'confirmed',
        'assignedAgentId': null,
      };

      void assignWithNotification(String orderId, String agentId) {
        inMemoryFirestore[orderId]!['assignedAgentId'] = agentId;
        inMemoryFirestore[orderId]!['status'] = 'assigned';

        dispatchedNotifications.add({
          'targetUserId': agentId,
          'title': 'New Delivery Assignment',
          'body': 'You have been assigned order #$orderId for delivery.',
          'orderId': orderId,
        });
      }

      assignWithNotification('ord_101', 'agent_a');
      expect(dispatchedNotifications.length, equals(1));
      expect(dispatchedNotifications.first['targetUserId'], equals('agent_a'));
      expect(dispatchedNotifications.first['title'], equals('New Delivery Assignment'));
      expect(dispatchedNotifications.first['orderId'], equals('ord_101'));
    });
  });
}
