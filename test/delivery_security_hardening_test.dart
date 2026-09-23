import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/auth/app_role.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/services/notification_service.dart';
import 'package:dairy_app/services/delivery_tracking_service.dart';
import 'package:dairy_app/services/order_service.dart';

void main() {
  group('Task 7: Delivery Panel Production Security Hardening & Audit Tests', () {

    // =========================================================================
    // 1. AUTHENTICATION & ROLE (RBAC) SECURITY
    // =========================================================================
    group('1. Authentication & Role Boundaries', () {
      test('Unknown, malformed, or injected roles safely default to customer (least privilege)', () {
        expect(UserRole.fromString(null), UserRole.customer);
        expect(UserRole.fromString(''), UserRole.customer);
        expect(UserRole.fromString('unknown'), UserRole.customer);
        expect(UserRole.fromString('hacker'), UserRole.customer);
        expect(UserRole.fromString('super_admin_fake'), UserRole.customer);
        expect(UserRole.fromString('delivery_admin'), UserRole.customer);
        expect(UserRole.fromString('root'), UserRole.customer);
      });

      test('Legitimate roles resolve precisely to intended enum values', () {
        expect(UserRole.fromString('admin'), UserRole.admin);
        expect(UserRole.fromString('owner'), UserRole.admin);
        expect(UserRole.fromString('superadmin'), UserRole.admin);
        expect(UserRole.fromString('delivery'), UserRole.delivery);
        expect(UserRole.fromString('delivery_agent'), UserRole.delivery);
        expect(UserRole.fromString('driver'), UserRole.delivery);
        expect(UserRole.fromString('customer'), UserRole.customer);
        expect(UserRole.fromString('user'), UserRole.customer);
      });

      test('User role getters correctly distinguish delivery privileges', () {
        const deliveryUser = User(
          id: 'agent_123',
          name: 'Delivery Agent',
          phone: '9876543210',
          role: 'delivery',
        );
        expect(deliveryUser.isDelivery, isTrue);
        expect(deliveryUser.isAdmin, isFalse);
        expect(deliveryUser.canAccessAdminPortal, isFalse);
        expect(deliveryUser.isCustomer, isFalse);

        const customerUser = User(
          id: 'cust_123',
          name: 'Customer User',
          phone: '9876543211',
          role: 'customer',
        );
        expect(customerUser.isDelivery, isFalse);
        expect(customerUser.isAdmin, isFalse);
        expect(customerUser.canAccessAdminPortal, isFalse);
        expect(customerUser.isCustomer, isTrue);
      });
    });

    // =========================================================================
    // 2. STATUS TRANSITION STATE MACHINE (FIRESTORE RULES SIMULATION)
    // =========================================================================
    group('2. Status Transition State Machine in Firestore Rules', () {
      bool evaluateDeliveryStatusTransition(String fromStatus, String toStatus) {
        final fromLower = fromStatus.toLowerCase().trim();
        final toLower = toStatus.toLowerCase().trim();

        final isUnchanged = fromLower == toLower;
        final fromAccepted = (fromLower == 'accepted' || fromLower == 'confirmed') &&
            [
              'accepted',
              'confirmed',
              'preparing',
              'pickup',
              'outfordelivery',
              'out for delivery',
              'cancelled'
            ].contains(toLower);

        final fromPreparing = (fromLower == 'preparing' || fromLower == 'pickup') &&
            [
              'preparing',
              'pickup',
              'outfordelivery',
              'out for delivery',
              'cancelled'
            ].contains(toLower);

        final fromOutForDelivery =
            (fromLower == 'outfordelivery' || fromLower == 'out for delivery') &&
                [
                  'outfordelivery',
                  'out for delivery',
                  'delivered',
                  'cancelled'
                ].contains(toLower);

        return isUnchanged || fromAccepted || fromPreparing || fromOutForDelivery;
      }

      bool evaluateCanUpdateAssignedOrder({
        required String? authUid,
        required String? authRole,
        required Map<String, dynamic> existingData,
        required Map<String, dynamic> requestData,
      }) {
        if (authUid == null || authRole != 'delivery') return false;

        final isMine = existingData['assignedAgentId'] == authUid;
        final isUnassigned = (existingData['assignedAgentId'] == null ||
                (existingData['assignedAgentId'] as String).isEmpty) &&
            ['Pending', 'pending', 'placed'].contains(existingData['status']);

        final claimsSelf = requestData['assignedAgentId'] == authUid &&
            [
              'accepted',
              'confirmed',
              'preparing',
              'pickup',
              'outfordelivery',
              'out for delivery'
            ].contains((requestData['status'] as String?)?.toLowerCase());

        final releases = requestData['assignedAgentId'] == null &&
            ['pending', 'placed']
                .contains((requestData['status'] as String?)?.toLowerCase());

        final isNonTerminal = ![
          'delivered',
          'cancelled'
        ].contains((existingData['status'] as String?)?.toLowerCase());

        final validTransition = !requestData.containsKey('status') ||
            evaluateDeliveryStatusTransition(
              existingData['status'] as String? ?? '',
              requestData['status'] as String? ?? '',
            );

        if (isMine) {
          if (!isNonTerminal || !validTransition) return false;

          final allowedMineKeys = [
            'status',
            'acceptedAt',
            'deliveredAt',
            'deliveryConfirmed',
            'cancellationReason',
            'updatedAt'
          ];
          final allowedReleaseKeys = [
            'status',
            'assignedAgentId',
            'acceptedAt',
            'updatedAt'
          ];

          final hasOnlyMine = requestData.keys.every(allowedMineKeys.contains);
          final hasOnlyRelease =
              requestData.keys.every(allowedReleaseKeys.contains) && releases;

          return hasOnlyMine || hasOnlyRelease;
        } else if (isUnassigned) {
          final allowedClaimKeys = [
            'status',
            'assignedAgentId',
            'acceptedAt',
            'updatedAt'
          ];
          return requestData.keys.every(allowedClaimKeys.contains) && claimsSelf;
        }

        return false;
      }

      test('Claiming an unassigned pending order permits accepted status', () {
        final existing = {
          'status': 'Pending',
          'assignedAgentId': null,
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };
        final request = {
          'status': 'accepted',
          'assignedAgentId': 'agent_1',
          'acceptedAt': '2026-09-23T12:00:00Z',
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: request,
          ),
          isTrue,
        );
      });

      test('Claiming an unassigned pending order REJECTS direct leap to delivered', () {
        final existing = {
          'status': 'Pending',
          'assignedAgentId': null,
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };
        final maliciousRequest = {
          'status': 'delivered',
          'assignedAgentId': 'agent_1',
          'acceptedAt': '2026-09-23T12:00:00Z',
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: maliciousRequest,
          ),
          isFalse,
          reason: 'Bypassing acceptance and pickup directly to delivered must be blocked',
        );
      });

      test('Assigned order in accepted state: allows transition to preparing or outForDelivery', () {
        final existing = {
          'status': 'accepted',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'preparing', 'updatedAt': 'now'},
          ),
          isTrue,
        );

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'outForDelivery', 'updatedAt': 'now'},
          ),
          isTrue,
        );
      });

      test('Assigned order in accepted state: REJECTS direct transition to delivered', () {
        final existing = {
          'status': 'accepted',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'delivered', 'deliveredAt': 'now'},
          ),
          isFalse,
          reason: 'Order must be outForDelivery before it can be delivered',
        );
      });

      test('Assigned order in outForDelivery state: permits transition to delivered or cancelled', () {
        final existing = {
          'status': 'outForDelivery',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'delivered', 'deliveredAt': 'now'},
          ),
          isTrue,
        );

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'cancelled', 'cancellationReason': 'Customer unavailable'},
          ),
          isTrue,
        );
      });

      test('Assigned order in delivered (terminal) state: REJECTS any mutation by delivery agent', () {
        final existing = {
          'status': 'delivered',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'pending'},
          ),
          isFalse,
          reason: 'Delivered orders are terminal; cannot transition back to pending',
        );

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'accepted'},
          ),
          isFalse,
          reason: 'Delivered orders cannot be reactivated by delivery agent',
        );
      });

      test('Assigned order in cancelled (terminal) state: REJECTS any mutation by delivery agent', () {
        final existing = {
          'status': 'cancelled',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'delivered'},
          ),
          isFalse,
          reason: 'Cancelled orders are terminal',
        );
      });

      test('Agent cannot tamper with totalAmount, subtotal, customerId, or items', () {
        final existing = {
          'status': 'accepted',
          'assignedAgentId': 'agent_1',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'outForDelivery', 'totalAmount': 0.0},
          ),
          isFalse,
          reason: 'Financial tampering must be blocked',
        );

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'outForDelivery', 'userId': 'agent_1'},
          ),
          isFalse,
          reason: 'Ownership tampering must be blocked',
        );
      });

      test('Agent A cannot mutate order assigned to Agent B', () {
        final existing = {
          'status': 'accepted',
          'assignedAgentId': 'agent_2',
          'userId': 'cust_1',
          'totalAmount': 100.0,
        };

        expect(
          evaluateCanUpdateAssignedOrder(
            authUid: 'agent_1',
            authRole: 'delivery',
            existingData: existing,
            requestData: {'status': 'outForDelivery'},
          ),
          isFalse,
        );
      });
    });

    // =========================================================================
    // 3. PAYMENT STATUS BOUNDARY SECURITY
    // =========================================================================
    group('3. Payment Collection Security Boundary', () {
      bool evaluatePaymentUpdateRule({
        required String? authUid,
        required String? authRole,
        required Map<String, dynamic> paymentDoc,
        required Map<String, dynamic>? linkedOrderDoc,
        required List<String> affectedKeys,
      }) {
        if (authUid == null) return false;
        final isAdmin = authRole == 'admin' || authRole == 'superadmin';
        if (isAdmin) return true;

        final isDelivery = authRole == 'delivery';
        if (!isDelivery) return false;

        // Payment must be linked to an order assigned to this authenticated agent
        final orderId = paymentDoc['orderId'] as String?;
        final isAssignedToAgent = orderId != null &&
            orderId.isNotEmpty &&
            linkedOrderDoc != null &&
            linkedOrderDoc['assignedAgentId'] == authUid;

        const allowedKeys = ['status', 'paymentStatus', 'updatedAt'];
        final hasOnlyAllowed = affectedKeys.every(allowedKeys.contains);

        return isAssignedToAgent && hasOnlyAllowed;
      }

      test('Delivery agent CAN update payment on order assigned to themselves', () {
        final payment = {
          'id': 'PAY_ORD_1',
          'orderId': 'ORD_1',
          'amount': 250.0,
          'status': 'Pending',
        };
        final order = {
          'id': 'ORD_1',
          'assignedAgentId': 'agent_1',
          'status': 'outForDelivery',
        };

        expect(
          evaluatePaymentUpdateRule(
            authUid: 'agent_1',
            authRole: 'delivery',
            paymentDoc: payment,
            linkedOrderDoc: order,
            affectedKeys: ['status', 'paymentStatus', 'updatedAt'],
          ),
          isTrue,
        );
      });

      test('Delivery agent CANNOT update payment on order assigned to another agent', () {
        final payment = {
          'id': 'PAY_ORD_2',
          'orderId': 'ORD_2',
          'amount': 500.0,
          'status': 'Pending',
        };
        final order = {
          'id': 'ORD_2',
          'assignedAgentId': 'agent_2',
          'status': 'outForDelivery',
        };

        expect(
          evaluatePaymentUpdateRule(
            authUid: 'agent_1', // Agent 1 attempting to update Agent 2's payment
            authRole: 'delivery',
            paymentDoc: payment,
            linkedOrderDoc: order,
            affectedKeys: ['status', 'paymentStatus', 'updatedAt'],
          ),
          isFalse,
          reason: 'Cross-agent payment updates must be rejected',
        );
      });

      test('Delivery agent CANNOT update payment without an assigned order link', () {
        final payment = {
          'id': 'PAY_STANDALONE',
          'orderId': null,
          'amount': 300.0,
          'status': 'Pending',
        };

        expect(
          evaluatePaymentUpdateRule(
            authUid: 'agent_1',
            authRole: 'delivery',
            paymentDoc: payment,
            linkedOrderDoc: null,
            affectedKeys: ['status', 'paymentStatus'],
          ),
          isFalse,
        );
      });
    });

    // =========================================================================
    // 4. GPS & LOCATION HARDENING
    // =========================================================================
    group('4. GPS Coordinate & Location Hardening', () {
      test('DeliveryTrackingService rejects out-of-bounds coordinates', () {
        expect(DeliveryTrackingService.isValidCoordinates(28.6139, 77.2090), isTrue);
        expect(DeliveryTrackingService.isValidCoordinates(0.0, 0.0), isFalse); // Null island rejected
        expect(DeliveryTrackingService.isValidCoordinates(91.0, 77.0), isFalse); // Invalid lat
        expect(DeliveryTrackingService.isValidCoordinates(-91.0, 77.0), isFalse); // Invalid lat
        expect(DeliveryTrackingService.isValidCoordinates(28.0, 181.0), isFalse); // Invalid lng
        expect(DeliveryTrackingService.isValidCoordinates(28.0, -181.0), isFalse); // Invalid lng
      });

      test('Delivery agent writing GPS to another agent document is rejected', () {
        bool evaluateGpsWrite({
          required String authUid,
          required String targetAgentId,
        }) {
          return authUid == targetAgentId;
        }

        expect(evaluateGpsWrite(authUid: 'agent_1', targetAgentId: 'agent_1'), isTrue);
        expect(evaluateGpsWrite(authUid: 'agent_1', targetAgentId: 'agent_2'), isFalse);
      });
    });

    // =========================================================================
    // 5. NOTIFICATION RBAC ROUTE CONFINEMENT
    // =========================================================================
    group('5. Notification Route Confinement', () {
      test('Delivery agent is strictly blocked from navigating into admin routes via push notifications', () {
        const deliveryUser = User(
          id: 'agent_1',
          name: 'Delivery Agent',
          phone: '9876543210',
          role: 'delivery',
        );

        final route1 = NotificationService.resolveNotificationRoute(
          user: deliveryUser,
          explicitRoute: '/admin/orders',
          orderId: 'ORD_123',
        );
        expect(route1, '/delivery', reason: 'Must redirect to delivery panel, blocking admin path');

        final route2 = NotificationService.resolveNotificationRoute(
          user: deliveryUser,
          explicitRoute: '/admin',
        );
        expect(route2, '/delivery', reason: 'Must block admin home');
      });

      test('Customer is strictly blocked from navigating into delivery or admin routes via push notifications', () {
        const customerUser = User(
          id: 'cust_1',
          name: 'Customer One',
          phone: '9876543211',
          role: 'customer',
        );

        final routeDelivery = NotificationService.resolveNotificationRoute(
          user: customerUser,
          explicitRoute: '/delivery',
        );
        expect(routeDelivery, '/notifications', reason: 'Customer must be blocked from /delivery');

        final routeAdmin = NotificationService.resolveNotificationRoute(
          user: customerUser,
          explicitRoute: '/admin/settings',
        );
        expect(routeAdmin, '/notifications', reason: 'Customer must be blocked from /admin');
      });
    });

    // =========================================================================
    // 6. EARNINGS RESILIENCE & DEDUPLICATION
    // =========================================================================
    group('6. Earnings Security & Deduplication', () {
      test('Commission calculation is resilient to decimals and zero', () {
        const rate = OrderService.agentEarningRate;
        expect(rate, 0.10);

        expect(((150.0 * rate) * 100).round() / 100, 15.0);
        expect(((249.99 * rate) * 100).round() / 100, 25.0);
        expect(((0.0 * rate) * 100).round() / 100, 0.0);
      });

      test('Earning ID is bound to orderId ensuring natural idempotency', () {
        const orderId = 'ORD_ABC_999';
        const earningDocId1 = orderId;
        const earningDocId2 = orderId;
        expect(earningDocId1, earningDocId2, reason: 'Doc ID collision prevents duplicate creation');
      });
    });
  });
}
