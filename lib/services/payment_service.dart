import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';

/// Riverpod provider for PaymentService
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Service for managing payments & transaction records in Cloud Firestore.
class PaymentService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  PaymentService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  CollectionReference<Map<String, dynamic>> get _paymentsRef =>
      _firestore.collection('payments');

  /// Real-time stream of all payment records in Firestore, newest first.
  Stream<List<DairyPayment>> streamAllPayments() {
    try {
      return _paymentsRef.snapshots().map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return DairyPayment.fromFirestore(doc.data(), doc.id);
        }).toList();

        // Sort by createdAt descending, fallback to doc ID
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

  /// Real-time stream of payment records for a specific customer UID.
  Stream<List<DairyPayment>> streamPaymentsForUser(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.value(<DairyPayment>[]);
    }
    try {
      return _paymentsRef
          .where('userId', isEqualTo: userId.trim())
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return DairyPayment.fromFirestore(doc.data(), doc.id);
        }).toList();

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
      return Stream.value(<DairyPayment>[]);
    }
  }

  /// Fetches a single payment record by its document ID or orderId.
  Future<DairyPayment?> getPaymentById(String paymentId) async {
    final cleanId = paymentId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final doc = await _paymentsRef.doc(cleanId).get();
      if (doc.exists && doc.data() != null) {
        return DairyPayment.fromFirestore(doc.data()!, doc.id);
      }

      // Check with PAY_ prefix if not present
      if (!cleanId.startsWith('PAY_')) {
        final payDoc = await _paymentsRef.doc('PAY_$cleanId').get();
        if (payDoc.exists && payDoc.data() != null) {
          return DairyPayment.fromFirestore(payDoc.data()!, payDoc.id);
        }
      }

      // Query by orderId
      final query =
          await _paymentsRef.where('orderId', isEqualTo: cleanId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final match = query.docs.first;
        return DairyPayment.fromFirestore(match.data(), match.id);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Creates or updates a payment record in Firestore.
  Future<void> createOrUpdatePayment(DairyPayment payment) async {
    final docId = payment.id.isNotEmpty ? payment.id : 'PAY_${payment.orderId ?? DateTime.now().millisecondsSinceEpoch}';
    await _paymentsRef.doc(docId).set(
          payment.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Updates the status and optional transaction ID for a payment record.
  Future<void> updatePaymentStatus(
    String paymentId,
    String status, {
    String? transactionId,
  }) async {
    final cleanId = paymentId.trim();
    if (cleanId.isEmpty) return;

    final normalized = DairyPayment.normalizeStatus(status);
    final updates = <String, dynamic>{
      'status': normalized,
      'paymentStatus': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (transactionId != null && transactionId.trim().isNotEmpty) {
      updates['transactionId'] = transactionId.trim();
    }

    try {
      await _paymentsRef.doc(cleanId).update(updates);
    } catch (primaryError) {
      if (!cleanId.startsWith('PAY_')) {
        try {
          await _paymentsRef.doc('PAY_$cleanId').update(updates);
          return;
        } catch (_) {
          // Fall through to rethrow primary error
        }
      }
      rethrow;
    }
  }

  /// One-time fetch of all payment records.
  Future<List<DairyPayment>> fetchAllPayments() async {
    try {
      final snapshot = await _paymentsRef.get();
      final list = snapshot.docs.map((doc) {
        return DairyPayment.fromFirestore(doc.data(), doc.id);
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
}
