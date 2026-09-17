import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_model.dart';
import '../models/order.dart';

/// Riverpod provider for DeliveryManagementService
final deliveryManagementServiceProvider =
    Provider<DeliveryManagementService>((ref) {
  return DeliveryManagementService();
});

/// Service for managing delivery batches (`delivery_batches`) and routes (`delivery_routes`) in Cloud Firestore.
class DeliveryManagementService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  DeliveryManagementService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  CollectionReference<Map<String, dynamic>> get _batchesRef =>
      _firestore.collection('delivery_batches');

  CollectionReference<Map<String, dynamic>> get _routesRef =>
      _firestore.collection('delivery_routes');

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  /// Calculates real-time delivery progress metrics for [orders] on [targetDate] (defaults to local today).
  static TodaysDeliveryProgress calculateTodaysProgress(
    List<Order> orders, {
    DateTime? targetDate,
  }) {
    final now = targetDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);

    int completed = 0;
    int pending = 0;
    int cancelled = 0;

    for (final o in orders) {
      final date = o.deliveryDate ?? o.orderDate;
      if (date.isBefore(todayStart) || !date.isBefore(tomorrowStart)) {
        continue;
      }

      switch (o.status) {
        case OrderStatus.delivered:
          completed++;
          break;
        case OrderStatus.cancelled:
          cancelled++;
          break;
        case OrderStatus.placed:
        case OrderStatus.confirmed:
        case OrderStatus.preparing:
        case OrderStatus.outForDelivery:
          pending++;
          break;
      }
    }

    final total = completed + pending;
    final completionPercentage =
        total == 0 ? 0.0 : ((completed / total) * 100.0);

    return TodaysDeliveryProgress(
      total: total,
      completed: completed,
      pending: pending,
      cancelled: cancelled,
      completionPercentage: completionPercentage,
    );
  }

  /// Real-time stream of today's delivery progress calculated from the `orders` collection in Firestore.
  Stream<TodaysDeliveryProgress> streamTodaysDeliveryProgress({
    DateTime? targetDate,
  }) {
    try {
      return _ordersRef.snapshots().map((snapshot) {
        final orders = snapshot.docs
            .map((doc) => Order.fromFirestore(doc.data(), doc.id))
            .toList();
        return calculateTodaysProgress(orders, targetDate: targetDate);
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Real-time stream of all delivery batches in Firestore.
  Stream<List<DeliveryBatch>> streamBatches() {
    try {
      return _batchesRef.snapshots().map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return DeliveryBatch.fromFirestore(doc.data(), doc.id);
        }).toList();

        // Sort by createdAt descending, fallback to id
        list.sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            return b.createdAt!.compareTo(a.createdAt!);
          }
          if (a.createdAt != null) return -1;
          if (b.createdAt != null) return 1;
          return b.id.compareTo(a.id);
        });

        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Real-time stream of all delivery routes / corridors in Firestore.
  Stream<List<DeliveryCorridor>> streamRoutes() {
    try {
      return _routesRef.snapshots().map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return DeliveryCorridor.fromFirestore(doc.data(), doc.id);
        }).toList();

        // Sort by routeName / name
        list.sort((a, b) => a.routeName.compareTo(b.routeName));

        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// One-time fetch of all delivery batches.
  Future<List<DeliveryBatch>> fetchBatches() async {
    try {
      final snapshot = await _batchesRef.get();
      final list = snapshot.docs.map((doc) {
        return DeliveryBatch.fromFirestore(doc.data(), doc.id);
      }).toList();

      list.sort((a, b) {
        if (a.createdAt != null && b.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return b.id.compareTo(a.id);
      });

      return list;
    } catch (_) {
      return [];
    }
  }

  /// One-time fetch of all delivery routes.
  Future<List<DeliveryCorridor>> fetchRoutes() async {
    try {
      final snapshot = await _routesRef.get();
      final list = snapshot.docs.map((doc) {
        return DeliveryCorridor.fromFirestore(doc.data(), doc.id);
      }).toList();

      list.sort((a, b) => a.routeName.compareTo(b.routeName));

      return list;
    } catch (_) {
      return [];
    }
  }

  /// Creates or updates a delivery batch record in Firestore.
  Future<void> createOrUpdateBatch(DeliveryBatch batch) async {
    final docId = batch.id.isNotEmpty
        ? batch.id
        : (batch.deliveryId.isNotEmpty
            ? batch.deliveryId
            : 'BATCH_${DateTime.now().millisecondsSinceEpoch}');
    await _batchesRef.doc(docId).set(
          batch.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Creates or updates a delivery route / corridor record in Firestore.
  Future<void> createOrUpdateRoute(DeliveryCorridor route) async {
    final docId = route.id.isNotEmpty
        ? route.id
        : (route.routeName.isNotEmpty
            ? route.routeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
            : 'ROUTE_${DateTime.now().millisecondsSinceEpoch}');
    await _routesRef.doc(docId).set(
          route.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Updates status for a delivery batch record in Firestore.
  Future<void> updateBatchStatus(
    String batchId,
    String status, {
    int? completedOrders,
    int? pendingOrders,
  }) async {
    final cleanId = batchId.trim();
    if (cleanId.isEmpty) return;

    final updates = <String, dynamic>{
      'status': status,
      if (completedOrders != null) 'completedOrders': completedOrders,
      if (completedOrders != null) 'completedCount': completedOrders,
      if (pendingOrders != null) 'pendingOrders': pendingOrders,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _batchesRef.doc(cleanId).update(updates);
    } catch (_) {
      if (!cleanId.startsWith('BATCH_')) {
        try {
          await _batchesRef.doc('BATCH_$cleanId').update(updates);
        } catch (_) {}
      }
    }
  }

  /// Updates status for a delivery route in Firestore.
  Future<void> updateRouteStatus(
    String routeId,
    String status, {
    int? completedOrders,
  }) async {
    final cleanId = routeId.trim();
    if (cleanId.isEmpty) return;

    final updates = <String, dynamic>{
      'status': status,
      if (completedOrders != null) 'completedOrders': completedOrders,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _routesRef.doc(cleanId).update(updates);
    } catch (_) {}
  }
}
