import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';
import '../core/utils/retry_helper.dart';
import 'earnings_service.dart';

/// Creates and persists customer orders in Cloud Firestore.
///
/// A new order document is written to the `orders` collection with the user's
/// id, the delivery address, the cart line items, the computed totals, and a
/// status of 'Pending'.
class OrderService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Commission credited to the agent, as a fraction of the order subtotal,
  /// when an order is delivered. Tuned to 10% on the backend Cloud Function.
  static const double agentEarningRate = 0.10;

  OrderService({
    FirebaseFirestore? firestore,
    EarningsService? earningsService,
  }) : _customFirestore = firestore;

  /// Pricing rules (mirror the cart provider so the service is self-contained).
  static const double freeDeliveryThreshold = 500.0;
  static const double deliveryCharge = 30.0;
  static const double discountRate = 0.10;

  /// Computes subtotal, delivery charge, discount, and grand total for [items].
  ({double subtotal, double deliveryCharge, double discount, double total})
      computeTotals(List<CartItem> items) {
    final subtotal = items.fold(0.0, (acc, item) => acc + item.totalPrice);
    final delivery = subtotal == 0
        ? 0.0
        : (subtotal >= freeDeliveryThreshold ? 0.0 : deliveryCharge);
    final discount =
        subtotal >= freeDeliveryThreshold ? subtotal * discountRate : 0.0;
    final total = (subtotal + delivery - discount).clamp(0.0, double.infinity);
    return (
      subtotal: subtotal,
      deliveryCharge: delivery,
      discount: discount,
      total: total,
    );
  }

  /// Generates a unique 6-character customer-facing order code (LLLNNN).
  /// Verifies against Firestore to avoid duplicate order codes.
  Future<String> generateUniqueOrderCode() async {
    const maxAttempts = 10;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = Order.generateRandomOrderCode();
      try {
        final existing = await _firestore
            .collection('orders')
            .where('orderCode', isEqualTo: candidate)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) {
          return candidate;
        }
      } catch (_) {
        // If query fails (e.g. offline/mock testing), return candidate directly
        return candidate;
      }
    }
    return Order.formatFallbackOrderCode(
        DateTime.now().microsecondsSinceEpoch.toString());
  }

  /// Writes a new order to Firestore from the provided cart [items] and returns
  /// the created [Order] (with its generated id).
  Future<Order> placeOrder({
    String? userId,
    required List<CartItem> items,
    required Address deliveryAddress,
    String paymentMethod = 'Cash on Delivery',
  }) async {
    String? currentAuthUid;
    try {
      if (Firebase.apps.isNotEmpty) {
        currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      }
    } catch (_) {
      currentAuthUid = null;
    }
    final authoritativeUid =
        currentAuthUid ?? (userId != null && userId.isNotEmpty ? userId : null);
    if (authoritativeUid == null) {
      throw StateError(
          'User must be authenticated with Firebase to place an order.');
    }

    if (items.isEmpty) {
      throw ArgumentError('Cannot place an order with an empty cart.');
    }

    final totals = computeTotals(items);
    final docRef = _firestore.collection('orders').doc();
    final now = DateTime.now();
    final orderCode = await generateUniqueOrderCode();

    final order = Order(
      id: docRef.id,
      orderCode: orderCode,
      items: items,
      subtotal: totals.subtotal,
      deliveryCharge: totals.deliveryCharge,
      discount: totals.discount,
      totalAmount: totals.total,
      status: OrderStatus.placed,
      orderDate: now,
      deliveryDate: now,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
    );

    final resolvedCustomerName = deliveryAddress.fullName.trim().isNotEmpty
        ? deliveryAddress.fullName.trim()
        : 'Customer';
    final resolvedCustomerPhone = deliveryAddress.mobileNumber.trim();

    await docRef.set({
      'orderCode': orderCode,
      'userId': authoritativeUid,
      'customerName': resolvedCustomerName,
      'customerPhone': resolvedCustomerPhone,
      'status': 'Pending',
      'items': items
          .map((item) => {
                'productId': item.product.id,
                'title': item.product.title,
                'productName': item.product.title,
                'name': item.product.title,
                'unit': item.product.unit,
                'price': item.product.price,
                'quantity': item.quantity,
                'totalPrice': item.totalPrice,
                'imageUrl': item.product.resolvedImageUrl.isNotEmpty
                    ? item.product.resolvedImageUrl
                    : item.product.imageUrl,
                'image': item.product.resolvedImageUrl.isNotEmpty
                    ? item.product.resolvedImageUrl
                    : item.product.imageUrl,
                'categoryId': item.product.categoryId,
                'categoryName': item.product.categoryName,
              })
          .toList(),
      'subtotal': totals.subtotal,
      'deliveryCharge': totals.deliveryCharge,
      'discount': totals.discount,
      'totalAmount': totals.total,
      'deliveryAddress': {
        'fullName': deliveryAddress.fullName,
        'mobileNumber': deliveryAddress.mobileNumber,
        'houseFlat': deliveryAddress.houseFlat,
        'streetArea': deliveryAddress.streetArea,
        'city': deliveryAddress.city,
        'state': deliveryAddress.state,
        'pinCode': deliveryAddress.pinCode,
        'label': deliveryAddress.label,
        'fullAddressText': deliveryAddress.fullAddressText,
        if (deliveryAddress.latitude != null)
          'latitude': deliveryAddress.latitude,
        if (deliveryAddress.longitude != null)
          'longitude': deliveryAddress.longitude,
      },
      'paymentMethod': 'Cash on Delivery',
      'paymentStatus': 'Pending',
      'deliveryDate': Timestamp.fromDate(now),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create corresponding payment transaction record in payments collection
    final paymentDocId = 'PAY_${docRef.id}';
    if (kDebugMode) {
      debugPrint('[P0.1] order created: ${docRef.id}');
      debugPrint('[P0.1] attempting payment write: $paymentDocId');
    }

    try {
      await _firestore.collection('payments').doc(paymentDocId).set({
        'id': paymentDocId,
        'orderId': docRef.id,
        'orderCode': orderCode,
        'userId': authoritativeUid,
        'customerName': deliveryAddress.fullName.trim().isNotEmpty
            ? deliveryAddress.fullName.trim()
            : 'Customer',
        'customerPhone': deliveryAddress.mobileNumber,
        'amount': totals.total,
        'method': 'Cash on Delivery',
        'paymentMethod': 'Cash on Delivery',
        'status': 'Pending',
        'paymentStatus': 'Pending',
        'transactionId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('[P0.1] payment write success: $paymentDocId');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[P0.1] payment write FAILED');
        if (e is FirebaseException) {
          debugPrint('error code: ${e.code}');
          debugPrint('error message: ${e.message}');
        } else {
          debugPrint('error: $e');
        }
        debugPrint('stackTrace: $stack');
      }
    }

    // Dispatch real-time Admin notification for new order
    try {
      final notifRepo = NotificationRepository(firestore: _firestore);
      final paymentMode = paymentMethod.trim().isNotEmpty
          ? paymentMethod.trim()
          : 'Cash on Delivery';
      final formattedAmount = totals.total.toStringAsFixed(
          totals.total.truncateToDouble() == totals.total ? 0 : 2);
      final notifBody =
          'New Order #$orderCode from $resolvedCustomerName - ₹$formattedAmount ($paymentMode)';

      await notifRepo.sendNotificationToAdmins(
        title: 'New Order Received 🛒',
        body: notifBody,
        type: NotificationType.order,
        orderId: docRef.id,
        route: '/admin/orders',
        isActionable: true,
        metadata: {
          'source': 'order_created',
          'orderId': docRef.id,
          'orderCode': orderCode,
          'customerName': resolvedCustomerName,
          'customerPhone': resolvedCustomerPhone,
          'totalAmount': totals.total,
          'paymentMethod': paymentMode,
          'category': 'order',
        },
        senderUid: authoritativeUid,
        notificationId: 'order_${docRef.id}_created',
      );
      if (kDebugMode) {
        debugPrint(
            '[NOTIFY ADMIN] Dispatched new order notification for ${docRef.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[NOTIFY ADMIN ERROR] Failed to dispatch new order notification: $e');
      }
    }

    return order;
  }

  /// Fetches a single order by its document ID or [orderCode].
  /// Returns `null` if the document does not exist or if an error occurs.
  Future<Order?> getOrderById(String orderId) async {
    final cleanId = orderId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('orders').doc(cleanId).get();
      if (doc.exists && doc.data() != null) {
        return Order.fromFirestore(doc.data()!, doc.id);
      }

      // Fallback: check if the identifier passed was an orderCode
      final query = await _firestore
          .collection('orders')
          .where('orderCode', isEqualTo: cleanId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final match = query.docs.first;
        return Order.fromFirestore(match.data(), match.id);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Live stream of a user's orders, newest first.
  Stream<List<Order>> streamOrdersForUser(String userId) {
    try {
      return _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Order.fromFirestore(d.data(), d.id)).toList()
                ..sort((a, b) => b.orderDate.compareTo(a.orderDate)));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Updates an order's status in Firestore.
  /// Enforces strict sequential state machine:
  /// PENDING -> CONFIRMED -> ASSIGNED -> ACCEPTED -> PREPARING -> OUT_FOR_DELIVERY -> DELIVERED
  /// DELIVERED is permanently locked against any status changes.
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    bool callerIsAdmin = false,
  }) async {
    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');

    try {
      await retryOperation(() async {
        final docRef = _firestore.collection('orders').doc(cleanOrderId);
        final doc = await docRef.get();
        if (!doc.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final currentStatusStr =
            (doc.data()?['status'] as String?)?.toLowerCase() ?? '';
        final targetStatusStr = orderStatusToString(status).toLowerCase();

        // 1. Permanent terminal lock: DELIVERED and CANCELLED orders can never be modified
        if (currentStatusStr == 'delivered' || currentStatusStr == 'cancelled') {
          throw StateError(
              'Cannot change status of a terminal order ($currentStatusStr): $cleanOrderId.');
        }

        // 2. Prohibit Admin from forcing delivery-agent-only states
        if (callerIsAdmin &&
            (status == OrderStatus.outForDelivery || status == OrderStatus.delivered)) {
          throw StateError(
              'Admin cannot set ${orderStatusToString(status)}. Only the assigned delivery agent can perform this action.');
        }

        // 3. Strict state machine transitions (cannot skip required states)
        if (currentStatusStr != targetStatusStr) {
          switch (status) {
            case OrderStatus.placed:
              throw StateError('Cannot revert order to Pending.');
            case OrderStatus.confirmed:
              if (currentStatusStr != 'pending' && currentStatusStr != 'placed') {
                throw StateError(
                    'Order can only be confirmed from Pending status (current: $currentStatusStr).');
              }
              break;
            case OrderStatus.assigned:
              if (currentStatusStr != 'confirmed') {
                throw StateError(
                    'Order can only be assigned from Confirmed status (current: $currentStatusStr).');
              }
              break;
            case OrderStatus.preparing:
              final isAccepted = currentStatusStr == 'accepted' ||
                  (currentStatusStr == 'assigned' && doc.data()?['acceptedAt'] != null);
              if (!isAccepted) {
                throw StateError(
                    'Cannot set to Preparing: Order must be accepted by the delivery agent first (current status: $currentStatusStr).');
              }
              break;
            case OrderStatus.outForDelivery:
              if (currentStatusStr != 'preparing') {
                throw StateError(
                    'Cannot start delivery: Order must be in Preparing status (current status: $currentStatusStr).');
              }
              break;
            case OrderStatus.delivered:
              final normStatus = currentStatusStr.replaceAll('_', '').replaceAll(' ', '');
              if (normStatus != 'outfordelivery') {
                throw StateError(
                    'Cannot mark delivered: Order must be Out for Delivery (current status: $currentStatusStr).');
              }
              break;
            case OrderStatus.cancelled:
              final normStatus = currentStatusStr.replaceAll('_', '').replaceAll(' ', '');
              if (normStatus == 'outfordelivery' ||
                  normStatus == 'delivered' ||
                  normStatus == 'cancelled') {
                throw StateError('Cannot cancel order in $currentStatusStr status.');
              }
              break;
          }

          await docRef.update({
            'status': orderStatusToString(status),
            if (status == OrderStatus.confirmed && doc.data()?['approvedAt'] == null)
              'approvedAt': FieldValue.serverTimestamp(),
            if (status == OrderStatus.delivered)
              'deliveredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Sync payment status if order is delivered or cancelled
        try {
          final paymentDoc =
              _firestore.collection('payments').doc('PAY_$cleanOrderId');
          if (status == OrderStatus.delivered) {
            await paymentDoc.update({
              'status': 'Success',
              'paymentStatus': 'Success',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else if (status == OrderStatus.cancelled) {
            await paymentDoc.update({
              'status': 'Cancelled',
              'paymentStatus': 'Cancelled',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}

        // Notify Admin and Customer when order is out for delivery
        if (status == OrderStatus.outForDelivery && currentStatusStr != targetStatusStr) {
          try {
            final orderData = doc.data();
            final orderCode = (orderData?['orderCode'] as String?)?.trim();
            final displayCode = (orderCode != null && orderCode.isNotEmpty)
                ? orderCode
                : Order.formatFallbackOrderCode(cleanOrderId);
            final agentId =
                (orderData?['assignedAgentId'] as String?)?.trim() ?? '';
            final agentName =
                (orderData?['assignedAgentName'] as String?)?.trim() ?? '';
            final effectiveAgentName =
                agentName.isNotEmpty ? agentName : 'Delivery Agent';
            final customerId = (orderData?['userId'] as String?)?.trim();

            final notifRepo = NotificationRepository(firestore: _firestore);

            // 1. Notify Admin: "Order #XXXX is now out for delivery."
            await notifRepo.sendNotificationToAdmins(
              title: 'Out for Delivery 🚚',
              body:
                  'Order #$displayCode is now out for delivery by $effectiveAgentName.',
              type: NotificationType.delivery,
              orderId: cleanOrderId,
              assignedAgentId: agentId.isNotEmpty ? agentId : null,
              route: '/admin/orders',
              isActionable: true,
              metadata: {
                'source': 'delivery',
                'orderId': cleanOrderId,
                'orderCode': displayCode,
                'eventType': 'deliveryStarted',
                'agentId': agentId,
                'agentName': effectiveAgentName,
                'status': 'outForDelivery',
                'category': 'delivery',
              },
              senderUid: agentId.isNotEmpty ? agentId : 'system',
              notificationId: 'delivery_${cleanOrderId}_deliveryStarted',
            );

            // 2. Notify Customer: "Your order #XXXX is now out for delivery!"
            if (customerId != null && customerId.isNotEmpty) {
              await notifRepo.sendNotificationToUser(
                targetUserId: customerId,
                title: 'Order Out for Delivery 🚚',
                body: 'Your order #$displayCode is now out for delivery!',
                type: NotificationType.order,
                createdBy: agentId.isNotEmpty ? agentId : 'system',
                orderId: cleanOrderId,
                route: '/orders/$cleanOrderId',
                isActionable: true,
                trackInAdminHistory: false,
                notificationId: 'order_${cleanOrderId}_outForDelivery',
              );
            }
          } catch (e) {
            debugPrint('[OUT FOR DELIVERY NOTIFY ERROR] $e');
          }
        }
      });
    } catch (e) {
      if (e is StateError || e is ArgumentError) rethrow;
      throw Exception('Failed to update order status for $cleanOrderId: $e');
    }
  }

  /// Completes the delivery of an order by the assigned delivery agent.
  ///
  /// Enforces:
  /// - Order must exist in Firestore.
  /// - Order must not already be in terminal state ('delivered' / 'cancelled').
  /// - Logged-in delivery agent MUST be assigned to this order (`assignedAgentId == agentId`).
  /// - Updates status to 'delivered', sets 'deliveredAt' and 'updatedAt'.
  /// - Syncs payment status to 'Success'.
  /// - Dispatches 'Order Delivered' notification to the customer with route: '/orders/$cleanOrderId'.
  /// - Dispatches 'Order Delivered' notification to admins with route: '/admin/orders'.
  /// - Uses deterministic notification IDs to prevent duplicates on retries.
  Future<void> markOrderDelivered({
    required String orderId,
    required String agentId,
    String? agentName,
  }) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');
    if (cleanAgentId.isEmpty) throw ArgumentError('agentId cannot be empty');

    String? customerUid;
    String displayCode = '';
    String effectiveAgentName = (agentName != null && agentName.trim().isNotEmpty)
        ? agentName.trim()
        : 'Delivery Staff';
    bool statusUpdated = false;

    await retryOperation(() async {
      final docRef = _firestore.collection('orders').doc(cleanOrderId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final data = snapshot.data();
        final currentAssignedAgentId =
            (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase() ?? '';

        // Terminal state check
        if (currentStatus == 'delivered') {
          throw StateError('Order $cleanOrderId is already delivered.');
        }
        if (currentStatus == 'cancelled') {
          throw StateError('Cannot deliver cancelled order $cleanOrderId.');
        }

        // Security check: Must be assigned to this agent
        if (currentAssignedAgentId != cleanAgentId) {
          throw StateError(
              'Order $cleanOrderId is not assigned to delivery agent $cleanAgentId.');
        }

        // Strict state machine: must be out for delivery
        final normalizedStatus = currentStatus.replaceAll('_', '').replaceAll(' ', '');
        if (normalizedStatus != 'outfordelivery') {
          throw StateError(
              'Cannot mark delivered: Order $cleanOrderId must be Out for Delivery (current status: $currentStatus).');
        }

        customerUid = (data?['userId'] as String?)?.trim();
        final code = (data?['orderCode'] as String?)?.trim();
        displayCode = (code != null && code.isNotEmpty)
            ? code
            : Order.formatFallbackOrderCode(cleanOrderId);

        final existingAgentName =
            (data?['assignedAgentName'] as String?)?.trim();
        if (existingAgentName != null && existingAgentName.isNotEmpty) {
          effectiveAgentName = existingAgentName;
        }

        transaction.update(docRef, {
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        statusUpdated = true;
      });

      // Sync payment status to Success
      try {
        final paymentDoc =
            _firestore.collection('payments').doc('PAY_$cleanOrderId');
        final paymentSnap = await paymentDoc.get();
        if (paymentSnap.exists) {
          await paymentDoc.update({
            'status': 'Success',
            'paymentStatus': 'Success',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    });

    if (!statusUpdated) return;

    final notifRepo = NotificationRepository(firestore: _firestore);

    // 1. Notify Customer: "Your order #XXXX has been delivered."
    if (customerUid != null && customerUid!.isNotEmpty) {
      try {
        await notifRepo.sendNotificationToUser(
          targetUserId: customerUid!,
          title: 'Order Delivered',
          body: 'Your order #$displayCode has been delivered.',
          type: NotificationType.order,
          createdBy: cleanAgentId,
          orderId: cleanOrderId,
          route: '/orders/$cleanOrderId',
          isActionable: true,
          trackInAdminHistory: false,
          notificationId: 'order_${cleanOrderId}_delivered',
        );
      } catch (e) {
        debugPrint('[DELIVERED NOTIFY CUSTOMER ERROR] $e');
      }
    }

    // 2. Notify Admin: "Order #XXXX has been delivered by [delivery staff]."
    try {
      await notifRepo.sendNotificationToAdmins(
        title: 'Order Delivered',
        body: 'Order #$displayCode has been delivered by $effectiveAgentName.',
        type: NotificationType.delivery,
        orderId: cleanOrderId,
        assignedAgentId: cleanAgentId,
        route: '/admin/orders',
        isActionable: true,
        metadata: {
          'source': 'delivery_completion',
          'orderId': cleanOrderId,
          'agentId': cleanAgentId,
          'agentName': effectiveAgentName,
          'status': 'delivered',
          'eventType': 'deliveryConfirmed',
        },
        senderUid: cleanAgentId,
        notificationId: 'delivery_${cleanOrderId}_deliveryConfirmed',
      );
    } catch (e) {
      debugPrint('[DELIVERED NOTIFY ADMIN ERROR] $e');
    }
  }

  /// Cancels an order by setting its status to [OrderStatus.cancelled].
  Future<void> cancelOrder(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.cancelled);

  /// Fails / cancels delivery with a reason (e.g. 'Customer unavailable' or 'Unable to deliver')
  Future<void> failDelivery(String orderId, String reason) async {
    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');

    try {
      await retryOperation(() async {
        final docRef = _firestore.collection('orders').doc(cleanOrderId);
        final doc = await docRef.get();
        if (!doc.exists) throw StateError('Order not found: $cleanOrderId');

        final currentStatus = (doc.data()?['status'] as String?)?.toLowerCase();
        final currentReason = doc.data()?['cancellationReason'] as String?;
        if (currentStatus != 'cancelled' || currentReason != reason) {
          await docRef.update({
            'status': 'cancelled',
            'cancellationReason': reason,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        try {
          final paymentDoc =
              _firestore.collection('payments').doc('PAY_$cleanOrderId');
          await paymentDoc.update({
            'status': 'Cancelled',
            'paymentStatus': 'Cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      });
    } catch (e) {
      if (e is StateError || e is ArgumentError) rethrow;
      throw Exception(
          'Failed to record delivery failure for $cleanOrderId: $e');
    }
  }

  /// Live stream of active (accepted / in-progress) orders from the `orders`
  /// collection, used by the delivery panel Active tab and the tracking map.
  /// Orders that are still `Pending` (awaiting driver acceptance) are excluded
  /// here and handled by the Requests flow instead.
  ///
  /// Status filtering is done client-side to avoid requiring a composite index.
  Stream<List<Order>> streamActiveOrders() {
    try {
      const activeStatuses = {'confirmed', 'assigned', 'accepted', 'preparing', 'outForDelivery'};
      return _firestore.collection('orders').snapshots().map((snap) => snap.docs
          .map((d) => Order.fromFirestore(d.data(), d.id))
          .where((o) => activeStatuses.contains(orderStatusToString(o.status)))
          .toList()
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate)));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Live stream of ALL orders in the `orders` collection (every status),
  /// newest first. This is the single source of truth for the delivery panel:
  /// the Requests, Active and History tabs all derive their lists from it.
  Stream<List<Order>> streamAllDeliveryOrders() {
    try {
      if (Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      return _firestore.collection('orders').snapshots().map((snap) =>
          snap.docs.map((d) => Order.fromFirestore(d.data(), d.id)).toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate)));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Live stream of the orders assigned to [agentId].
  /// Delivery agents strictly access ONLY orders where assignedAgentId == agentId.
  /// Unassigned Pending orders are NEVER queried by delivery agents.
  Stream<List<Order>> streamDeliveryOrdersForAgent(String agentId) {
    final cleanAgentId = agentId.trim();
    if (cleanAgentId.isEmpty) {
      return Stream.value(const []);
    }
    try {
      if (Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      final query = _firestore
          .collection('orders')
          .where('assignedAgentId', isEqualTo: cleanAgentId);

      return query.snapshots().map((snap) =>
          snap.docs.map((d) => Order.fromFirestore(d.data(), d.id)).toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate)));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Accepts an order on behalf of a delivery agent. Persists the acceptance to
  /// Firestore as the single source of truth: the order moves from `assigned` to
  /// `accepted` and records the acceptance time.
  ///
  /// Concurrency protection & Security:
  /// - Agent may ONLY accept an order that has been assigned to that exact agent.
  /// - If the order is unassigned or assigned to someone else, it aborts with [StateError].
  /// - If the order was already accepted by this agent, it succeeds idempotently on retry.
  Future<void> acceptOrder(String orderId, String agentId) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');
    if (cleanAgentId.isEmpty) throw ArgumentError('agentId cannot be empty');

    await retryOperation(() async {
      final docRef = _firestore.collection('orders').doc(cleanOrderId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final data = snapshot.data();
        final currentAssignedAgentId =
            (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase();

        // Idempotent retry: if this agent already accepted this order, succeed cleanly
        if (currentAssignedAgentId == cleanAgentId &&
            currentStatus == 'accepted') {
          return;
        }

        // Terminal state check
        if (currentStatus == 'delivered' || currentStatus == 'cancelled') {
          throw StateError(
              'Cannot accept order in terminal state ($currentStatus): $cleanOrderId.');
        }

        // Security & Concurrency guard: order MUST be assigned to this exact agent
        if (currentAssignedAgentId == null ||
            currentAssignedAgentId.isEmpty ||
            currentAssignedAgentId != cleanAgentId) {
          throw StateError(
              'Order is not assigned to delivery agent $cleanAgentId.');
        }

        // Must be in assigned status
        if (currentStatus != 'assigned') {
          throw StateError(
              'Order must be in Assigned status to be accepted (current: $currentStatus).');
        }

        transaction.update(docRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });

    // Notify Admin: "Delivery agent accepted Order #XXXX."
    try {
      final doc = await _firestore.collection('orders').doc(cleanOrderId).get();
      final orderData = doc.data();
      final orderCode = (orderData?['orderCode'] as String?)?.trim();
      final displayCode = (orderCode != null && orderCode.isNotEmpty)
          ? orderCode
          : Order.formatFallbackOrderCode(cleanOrderId);

      String agentName =
          (orderData?['assignedAgentName'] as String?)?.trim() ?? '';
      if (agentName.isEmpty) {
        final agentDoc =
            await _firestore.collection('users').doc(cleanAgentId).get();
        if (agentDoc.exists) {
          agentName = (agentDoc.data()?['name'] as String?)?.trim() ?? '';
        }
      }
      final effectiveName = agentName.isNotEmpty ? agentName : 'Delivery agent';

      final notifRepo = NotificationRepository(firestore: _firestore);
      await notifRepo.sendNotificationToAdmins(
        title: 'Order Accepted 📦',
        body: 'Delivery agent $effectiveName accepted Order #$displayCode.',
        type: NotificationType.delivery,
        orderId: cleanOrderId,
        assignedAgentId: cleanAgentId,
        route: '/admin/orders',
        isActionable: true,
        metadata: {
          'source': 'delivery',
          'orderId': cleanOrderId,
          'orderCode': displayCode,
          'eventType': 'orderAccepted',
          'agentId': cleanAgentId,
          'agentName': effectiveName,
          'status': 'accepted',
          'category': 'delivery',
        },
        senderUid: cleanAgentId,
        notificationId: 'delivery_${cleanOrderId}_orderAccepted',
      );
    } catch (e) {
      debugPrint('[ACCEPT ORDER NOTIFY ADMIN ERROR] $e');
    }
  }

  /// Releases an order assigned to an agent: verifies ownership, clears the
  /// assignment, and returns it to `confirmed` so Admin can reassign it.
  ///
  /// Concurrency protection: If the order was reassigned to another agent in the
  /// interim, the decline operation aborts to prevent overwriting newer assignments.
  ///
  /// Idempotency: If already unassigned and in confirmed, retries succeed cleanly.
  Future<void> declineOrder(String orderId, String agentId) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty');
    }

    await retryOperation(() async {
      final docRef = _firestore.collection('orders').doc(cleanOrderId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final data = snapshot.data();
        final currentAssignedAgentId =
            (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase();

        // Idempotent retry: if already unassigned and back in confirmed, succeed cleanly
        if ((currentAssignedAgentId == null ||
                currentAssignedAgentId.isEmpty) &&
            currentStatus == 'confirmed') {
          return;
        }

        // Concurrency guard: If the order is not assigned to this agent, abort
        if (currentAssignedAgentId != cleanAgentId) {
          throw StateError(
              'Order is no longer assigned to delivery agent $cleanAgentId.');
        }

        // If assigned to this agent, clear the assignment and return to confirmed
        transaction.update(docRef, {
          'status': 'confirmed',
          'assignedAgentId': null,
          'assignedAgentName': null,
          'assignedAt': null,
          'acceptedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  /// Submits a delivery completion request for an order on behalf of the assigned delivery agent.
  /// Enforces state machine and ownership:
  /// - Agent must match the assignedAgentId.
  /// - Order must not already be in terminal state (delivered / cancelled).
  /// - Marks deliveryCompletionRequested: true, deliveryCompletionRequestedAt: now,
  ///   deliveryCompletionAgentId: agentId, deliveryCompletionStatus: 'awaitingAdminConfirmation',
  ///   deliveryCompletionRequestId: 'COMP_$orderId_$timestamp'.
  /// - Idempotent: If already requested with 'awaitingAdminConfirmation', succeeds cleanly.
  /// - Triggers notification creation to Admin and to Customer.
  Future<void> submitDeliveryCompletion({
    required String orderId,
    required String agentId,
    String? notes,
  }) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');
    if (cleanAgentId.isEmpty) throw ArgumentError('agentId cannot be empty');

    await retryOperation(() async {
      final docRef = _firestore.collection('orders').doc(cleanOrderId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final data = snapshot.data();
        final currentAssignedAgentId =
            (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase();
        final alreadyRequested = data?['deliveryCompletionRequested'] == true;

        // Idempotency: if already requested by this agent, succeed cleanly
        if (alreadyRequested && currentAssignedAgentId == cleanAgentId) {
          return;
        }

        // Security check: Must be assigned to this agent
        if (currentAssignedAgentId != cleanAgentId) {
          throw StateError(
              'Order is not assigned to delivery agent $cleanAgentId.');
        }

        // Terminal state check
        if (currentStatus == 'delivered' || currentStatus == 'cancelled') {
          throw StateError(
              'Cannot request completion on $currentStatus order: $cleanOrderId');
        }

        final completionRequestId =
            'COMP_${cleanOrderId}_${DateTime.now().millisecondsSinceEpoch}';

        transaction.update(docRef, {
          'deliveryCompletionRequested': true,
          'deliveryCompletionRequestedAt': FieldValue.serverTimestamp(),
          'deliveryCompletionAgentId': cleanAgentId,
          'deliveryCompletionStatus': 'awaitingAdminConfirmation',
          'deliveryCompletionRequestId': completionRequestId,
          if (notes != null && notes.trim().isNotEmpty)
            'deliveryNotes': notes.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });

    // Notify Admin via NotificationRepository
    try {
      final notifRepo = NotificationRepository(firestore: _firestore);
      await notifRepo.sendNotificationToAdmins(
        title: 'Delivery Completed — Confirmation Required 📋',
        body:
            'Agent reported delivery completed for order #$cleanOrderId. Confirmation required.',
        type: NotificationType.delivery,
        orderId: cleanOrderId,
        assignedAgentId: cleanAgentId,
        route: '/admin/orders',
        isActionable: true,
        metadata: {
          'source': 'delivery_completion_request',
          'orderId': cleanOrderId,
          'agentId': cleanAgentId,
          'status': 'awaitingAdminConfirmation',
        },
      );
    } catch (e) {
      debugPrint('[COMPLETION NOTIFY ADMIN ERROR] $e');
    }

    // Notify Customer that delivery was reported completed and is awaiting confirmation
    try {
      final orderDoc =
          await _firestore.collection('orders').doc(cleanOrderId).get();
      final customerUid = (orderDoc.data()?['userId'] as String?)?.trim();
      if (customerUid != null && customerUid.isNotEmpty) {
        final notifRepo = NotificationRepository(firestore: _firestore);
        await notifRepo.sendNotificationToUser(
          targetUserId: customerUid,
          title: 'Delivery Completed 📦',
          body:
              'Your delivery has been reported as completed and is awaiting confirmation.',
          type: NotificationType.delivery,
          createdBy: cleanAgentId,
          orderId: cleanOrderId,
          route: '/orders/$cleanOrderId',
          isActionable: true,
          trackInAdminHistory: false,
        );
      }
    } catch (e) {
      debugPrint('[COMPLETION NOTIFY CUSTOMER ERROR] $e');
    }
  }

  /// Approves an unconfirmed/pending order and assigns a delivery agent in sequence.
  Future<void> approveAndAssignOrder(
    String orderId,
    String agentId, {
    String? agentName,
    String? adminUid,
  }) async {
    final cleanOrderId = orderId.trim();
    final cleanAgentId = agentId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');
    if (cleanAgentId.isEmpty) throw ArgumentError('agentId cannot be empty');

    final docRef = _firestore.collection('orders').doc(cleanOrderId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Order not found: ');
    }
    final currentStatus = (snapshot.data()?['status'] as String?)?.toLowerCase() ?? '';
    if (currentStatus == 'pending' || currentStatus == 'placed') {
      await updateOrderStatus(cleanOrderId, OrderStatus.confirmed);
    }
    await assignDeliveryAgent(
      cleanOrderId,
      cleanAgentId,
      agentName: agentName,
      adminUid: adminUid,
    );
  }

  /// Assigns or unassigns a delivery agent to an order in Firestore.
  /// Enforces that an order MUST be confirmed/approved by Admin before assignment.
  /// Setting an agent transitions the order status to `assigned` and triggers
  /// the delivery assignment notification.
  Future<void> assignDeliveryAgent(
    String orderId,
    String? agentId, {
    String? agentName,
    String? adminUid,
  }) async {
    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');

    final cleanAgentId = agentId?.trim();
    final isAssigning = cleanAgentId != null && cleanAgentId.isNotEmpty;

    try {
      await retryOperation(() async {
        final docRef = _firestore.collection('orders').doc(cleanOrderId);
        final snapshot = await docRef.get();
        if (!snapshot.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }

        final data = snapshot.data();
        final currentStatus = (data?['status'] as String?)?.toLowerCase() ?? '';

        // Permanent terminal lock: DELIVERED and CANCELLED orders can never be modified or reassigned
        if (currentStatus == 'delivered' || currentStatus == 'cancelled') {
          throw StateError(
              'Cannot modify or reassign a $currentStatus order: order is permanently locked.');
        }

        if (isAssigning) {
          // Admin cannot assign an agent to an unapproved Pending order
          if (currentStatus == 'pending' || currentStatus == 'placed') {
            throw StateError(
                'Order must be confirmed by Admin before assigning a delivery agent.');
          }
          if (currentStatus != 'confirmed' && currentStatus != 'assigned') {
            throw StateError(
                'Order can only be assigned when in Confirmed or Assigned status (current: $currentStatus).');
          }

          // Enforce online-only assignment rule: fresh online-state check immediately before writing
          bool isAgentOnline = false;
          bool docFound = false;
          try {
            final agentDoc = await _firestore
                .collection('delivery_agents')
                .doc(cleanAgentId)
                .get();
            if (agentDoc.exists) {
              docFound = true;
              final agentData = agentDoc.data();
              isAgentOnline = agentData?['isOnline'] == true;
            } else {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(cleanAgentId)
                  .get();
              if (userDoc.exists) {
                docFound = true;
                final userData = userDoc.data();
                isAgentOnline = userData?['isOnline'] == true;
              }
            }
          } catch (e) {
            if (e is StateError) rethrow;
          }

          if (docFound && !isAgentOnline) {
            throw StateError(
                'Cannot assign order: Delivery agent is currently offline');
          }

          final Map<String, dynamic> updateData = {
            'assignedAgentId': cleanAgentId,
            'assignedAgentName': agentName,
            'assignedAt': FieldValue.serverTimestamp(),
            if (data?['approvedAt'] == null)
              'approvedAt': FieldValue.serverTimestamp(),
            'status': 'assigned',
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await docRef.update(updateData);

          // Trigger notification to the assigned delivery agent
          try {
            final orderCode = (data?['orderCode'] as String?)?.trim();
            final displayCode = (orderCode != null && orderCode.isNotEmpty)
                ? orderCode
                : Order.formatFallbackOrderCode(cleanOrderId);
            final customerName =
                (data?['customerName'] as String?)?.trim() ?? 'Customer';
            final deliveryAddr =
                (data?['deliveryAddress'] as Map<String, dynamic>?)?['streetArea'] ?? '';

            final notifRepo = NotificationRepository(firestore: _firestore);
            await notifRepo.sendNotificationToUser(
              targetUserId: cleanAgentId,
              title: 'New Delivery Assignment',
              body:
                  'You have been assigned order #$displayCode ($customerName${deliveryAddr.toString().isNotEmpty ? ', $deliveryAddr' : ''}) for delivery.',
              type: NotificationType.delivery,
              createdBy: adminUid ?? 'admin',
              orderId: cleanOrderId,
              assignedAgentId: cleanAgentId,
              route: '/delivery/orders/$cleanOrderId',
              isActionable: true,
              notificationId: 'delivery_${cleanOrderId}_assigned',
              metadata: {
                'source': 'delivery_assignment',
                'orderId': cleanOrderId,
                'orderCode': displayCode,
                'customerName': customerName,
                'category': 'delivery',
              },
            );
          } catch (notifErr) {
            debugPrint(
                'OrderService: Could not dispatch assignment notification: $notifErr');
          }
        } else {
          if (currentStatus != 'assigned') {
            throw StateError(
                'Order can only be unassigned when in Assigned status (current: $currentStatus).');
          }
          // Unassigning returns the order to confirmed state
          final Map<String, dynamic> updateData = {
            'assignedAgentId': null,
            'assignedAgentName': null,
            'assignedAt': null,
            'status': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await docRef.update(updateData);
        }
      });
    } catch (e) {
      if (e is StateError || e is ArgumentError) rethrow;
      throw Exception('Failed to assign delivery agent for $cleanOrderId: $e');
    }
  }

  /// Safely backfills existing Firestore order documents that lack an `orderCode`.
  /// Iterates through orders, derives a valid 6-character LLLNNN code deterministically
  /// from the document ID, and saves it permanently to Firestore.
  Future<int> backfillLegacyOrderCodes() async {
    int count = 0;
    try {
      final snap = await _firestore.collection('orders').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final existingCode = (data['orderCode'] as String?)?.trim() ?? '';
        final isValidFormat = existingCode.length == 6 &&
            RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(existingCode.toUpperCase());
        if (!isValidFormat) {
          final assignedCode = Order.formatFallbackOrderCode(doc.id);
          await doc.reference.update({'orderCode': assignedCode});
          count++;
        }
      }
    } catch (_) {
      // Handled gracefully for offline or security restricted environments
    }
    return count;
  }
}

/// Provides a singleton [OrderService], injecting the [EarningsService] so
/// deliveries automatically credit agent earnings.
final orderServiceProvider = Provider<OrderService>((ref) => OrderService(
      earningsService: ref.watch(earningsServiceProvider),
    ));
