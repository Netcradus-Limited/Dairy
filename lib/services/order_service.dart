import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/address.dart';
import '../models/cart_item.dart';
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
    final authoritativeUid = currentAuthUid ??
        (userId != null && userId.isNotEmpty ? userId : null);
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

  /// Updates an order's status in Firestore. When the status becomes
  /// [OrderStatus.delivered], the trusted backend Cloud Function handles
  /// calculating and creating the delivery earning server-side.
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) throw ArgumentError('orderId cannot be empty');

    try {
      await retryOperation(() async {
        final docRef = _firestore.collection('orders').doc(cleanOrderId);
        final doc = await docRef.get();
        if (!doc.exists) {
          throw StateError('Order not found: $cleanOrderId');
        }
        final currentStatusStr = (doc.data()?['status'] as String?)?.toLowerCase();
        final targetStatusStr = orderStatusToString(status).toLowerCase();

        // Idempotent check: if already in the target status, skip redundant update
        if (currentStatusStr != targetStatusStr) {
          await docRef.update({'status': orderStatusToString(status)});
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
      });
    } catch (e) {
      if (e is StateError || e is ArgumentError) rethrow;
      throw Exception('Failed to update order status for $cleanOrderId: $e');
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
      throw Exception('Failed to record delivery failure for $cleanOrderId: $e');
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
      const activeStatuses = {'confirmed', 'preparing', 'outForDelivery'};
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

  /// Live stream of the orders relevant to a delivery agent: any order that is
  /// still `Pending` (awaiting acceptance) OR already assigned to [agentId].
  /// Uses a Firestore query filter to ensure compliance with Security Rules.
  Stream<List<Order>> streamDeliveryOrdersForAgent(String agentId) {
    try {
      if (Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      final Query<Map<String, dynamic>> query;
      if (agentId.isEmpty) {
        query = _firestore
            .collection('orders')
            .where('status', isEqualTo: 'Pending');
      } else {
        query = _firestore.collection('orders').where(
              Filter.or(
                Filter('status', isEqualTo: 'Pending'),
                Filter('assignedAgentId', isEqualTo: agentId),
              ),
            );
      }

      return query.snapshots().map((snap) =>
          snap.docs.map((d) => Order.fromFirestore(d.data(), d.id)).toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate)));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Accepts an order on behalf of a delivery agent. Persists the acceptance to
  /// Firestore as the single source of truth: the order moves from `pending` to
  /// `accepted`, is bound to [agentId], and records the acceptance time.
  ///
  /// Concurrency protection & Idempotency:
  /// - If the order was already accepted by this agent, it succeeds idempotently on retry.
  /// - If the order was claimed by another agent in the interim, it aborts with [StateError]
  ///   to prevent race conditions.
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
        final currentAssignedAgentId = (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase();

        // Idempotent retry: if this agent already accepted this order, succeed cleanly
        if (currentAssignedAgentId == cleanAgentId && currentStatus == 'accepted') {
          return;
        }

        // Concurrency guard: if another agent has already claimed this order
        if (currentAssignedAgentId != null &&
            currentAssignedAgentId.isNotEmpty &&
            currentAssignedAgentId != cleanAgentId) {
          throw StateError('Order is already claimed by another agent.');
        }

        transaction.update(docRef, {
          'status': 'accepted',
          'assignedAgentId': cleanAgentId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  /// Releases an order assigned to or accepted by an agent: verifies ownership,
  /// clears the assignment, and returns it to `Pending` so it can be picked up
  /// by another agent or reassigned by an admin.
  ///
  /// Concurrency protection: If the order was reassigned to another agent in the
  /// interim, the decline operation aborts to prevent overwriting newer assignments.
  ///
  /// Idempotency: If already unassigned and in Pending, retries succeed cleanly.
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
        final currentAssignedAgentId = (data?['assignedAgentId'] as String?)?.trim();
        final currentStatus = (data?['status'] as String?)?.toLowerCase();

        // Idempotent retry: if already unassigned and back in Pending, succeed cleanly
        if ((currentAssignedAgentId == null || currentAssignedAgentId.isEmpty) &&
            currentStatus == 'pending') {
          return;
        }

        // Concurrency guard: If the order is currently assigned to another agent,
        // prevent this agent from blindly wiping out the newer assignment.
        if (currentAssignedAgentId != null &&
            currentAssignedAgentId.isNotEmpty &&
            currentAssignedAgentId != cleanAgentId) {
          throw StateError(
              'Order is no longer assigned to delivery agent $cleanAgentId.');
        }

        // If assigned to this agent, clear the assignment and return to Pending
        if (currentAssignedAgentId != null &&
            currentAssignedAgentId.isNotEmpty &&
            currentAssignedAgentId == cleanAgentId) {
          transaction.update(docRef, {
            'status': 'Pending',
            'assignedAgentId': null,
            'acceptedAt': null,
          });
        }
      });
    });
  }

  /// Assigns or unassigns a delivery agent to an order in Firestore.
  /// Preserves the existing status of the order.
  Future<void> assignDeliveryAgent(
    String orderId,
    String? agentId, {
    String? agentName,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'assignedAgentId': agentId,
        'assignedAgentName': agentName,
        'assignedAt': agentId != null ? FieldValue.serverTimestamp() : null,
      };
      await _firestore.collection('orders').doc(orderId).update(updateData);
    } catch (e) {
      throw Exception('Failed to assign delivery agent for $orderId: $e');
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
