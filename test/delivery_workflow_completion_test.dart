import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_app/models/address.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/order.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery Workflow Completion & Security Tests', () {
    const testAddress = Address(
      id: 'addr_1',
      label: 'Home',
      fullName: 'Vikram Joshi',
      mobileNumber: '9876543210',
      houseFlat: 'A-204',
      streetArea: 'Sector 62',
      city: 'Noida',
      state: 'Uttar Pradesh',
      pinCode: '201301',
      latitude: 28.6280,
      longitude: 77.3649,
    );

    test('1. Order model correctly serializes and deserializes delivery completion fields', () {
      final now = DateTime.now();
      final order = Order(
        id: 'ord_comp_001',
        orderCode: 'DLV123',
        items: const [],
        subtotal: 350.0,
        totalAmount: 350.0,
        status: OrderStatus.outForDelivery,
        orderDate: now,
        deliveryAddress: testAddress,
        assignedAgentId: 'agent_99',
        assignedAgentName: 'Ramesh Agent',
        deliveryCompletionRequested: true,
        deliveryCompletionRequestedAt: now,
        deliveryCompletionAgentId: 'agent_99',
        deliveryCompletionStatus: 'awaitingAdminConfirmation',
        deliveryCompletionRequestId: 'COMP_ord_comp_001_12345',
        deliveryNotes: 'Delivered to gate guard per customer instruction',
      );

      final firestoreMap = order.toFirestore();
      expect(firestoreMap['deliveryCompletionRequested'], isTrue);
      expect(firestoreMap['deliveryCompletionAgentId'], 'agent_99');
      expect(firestoreMap['deliveryCompletionStatus'], 'awaitingAdminConfirmation');
      expect(firestoreMap['deliveryCompletionRequestId'], 'COMP_ord_comp_001_12345');
      expect(firestoreMap['deliveryNotes'], 'Delivered to gate guard per customer instruction');

      final deserialized = Order.fromFirestore(firestoreMap, 'ord_comp_001');
      expect(deserialized.id, 'ord_comp_001');
      expect(deserialized.deliveryCompletionRequested, isTrue);
      expect(deserialized.deliveryCompletionAgentId, 'agent_99');
      expect(deserialized.deliveryCompletionStatus, 'awaitingAdminConfirmation');
      expect(deserialized.deliveryCompletionRequestId, 'COMP_ord_comp_001_12345');
      expect(deserialized.deliveryNotes, 'Delivered to gate guard per customer instruction');
    });

    test('2. deliveryOrderFromOrder maps to awaitingAdminConfirmation when completion requested and not yet delivered', () {
      final now = DateTime.now();
      final order = Order(
        id: 'ord_comp_002',
        orderCode: 'DLV456',
        items: const [],
        subtotal: 400.0,
        totalAmount: 400.0,
        status: OrderStatus.outForDelivery,
        orderDate: now,
        deliveryAddress: testAddress,
        assignedAgentId: 'agent_99',
        deliveryCompletionRequested: true,
        deliveryCompletionRequestedAt: now,
        deliveryCompletionAgentId: 'agent_99',
        deliveryCompletionStatus: 'awaitingAdminConfirmation',
      );

      final deliveryOrder = deliveryOrderFromOrder(order);
      expect(deliveryOrder.status, DeliveryOrderStatus.awaitingAdminConfirmation);
      expect(deliveryOrder.isAwaitingAdminConfirmation, isTrue);
      expect(deliveryOrder.deliveryCompletionRequested, isTrue);
      expect(deliveryOrder.deliveryCompletionAgentId, 'agent_99');
      expect(deliveryOrder.deliveryCompletionStatus, 'awaitingAdminConfirmation');
      expect(deliveryOrder.status.statusLabel, 'Awaiting Admin Confirmation');
    });

    test('3. When order is formally delivered by admin, status is delivered and not awaiting confirmation', () {
      final now = DateTime.now();
      final order = Order(
        id: 'ord_comp_003',
        orderCode: 'DLV789',
        items: const [],
        subtotal: 500.0,
        totalAmount: 500.0,
        status: OrderStatus.delivered,
        orderDate: now,
        deliveryAddress: testAddress,
        assignedAgentId: 'agent_99',
        deliveryCompletionRequested: true,
        deliveryCompletionRequestedAt: now,
        deliveryCompletionAgentId: 'agent_99',
        deliveryCompletionStatus: 'confirmedByAdmin',
      );

      final deliveryOrder = deliveryOrderFromOrder(order);
      expect(deliveryOrder.status, DeliveryOrderStatus.delivered);
      expect(deliveryOrder.isAwaitingAdminConfirmation, isFalse);
      expect(deliveryOrder.status.statusLabel, 'Delivered');
    });

    test('4. NotificationService.resolveNotificationRoute routes delivery agent directly to /delivery/orders/:orderId', () {
      const deliveryUser = User(
        id: 'agent_99',
        name: 'Ramesh Agent',
        phone: '9876543210',
        role: 'delivery',
      );

      final resolvedRoute = NotificationService.resolveNotificationRoute(
        user: deliveryUser,
        orderId: 'ORD-98765',
      );

      expect(resolvedRoute, '/delivery/orders/ORD-98765');
    });

    test('5. NotificationService.resolveNotificationRoute blocks delivery agent from admin screens', () {
      const deliveryUser = User(
        id: 'agent_99',
        name: 'Ramesh Agent',
        phone: '9876543210',
        role: 'delivery',
      );

      final resolvedRoute = NotificationService.resolveNotificationRoute(
        user: deliveryUser,
        explicitRoute: '/admin/orders',
      );

      expect(resolvedRoute, '/delivery');
    });

    test('6. DeliveryAgent.empty initializes offDuty and profile incomplete until login/set', () {
      final emptyAgent = DeliveryAgent.empty('test_agent_id');
      expect(emptyAgent.status, DeliveryStatus.offDuty);
      expect(emptyAgent.isProfileComplete, isFalse);
      expect(emptyAgent.totalDeliveriesToday, 0);
      expect(emptyAgent.completedDeliveriesToday, 0);
      expect(emptyAgent.earningsToday, 0.0);
    });

    test('7. DeliveryOrderStatus colors and labels are distinct and valid', () {
      expect(DeliveryOrderStatus.awaitingAdminConfirmation.statusColor, const Color(0xFFD97706));
      expect(DeliveryOrderStatus.outForDelivery.statusColor, const Color(0xFF0284C7));
      expect(DeliveryOrderStatus.delivered.statusColor, const Color(0xFF10B981));
      expect(DeliveryOrderStatus.cancelled.statusColor, const Color(0xFFE53935));
    });
  });
}
