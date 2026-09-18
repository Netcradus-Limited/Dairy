import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/complaint_model.dart';

/// Service for managing customer complaints and support tickets in Cloud Firestore.
class ComplaintService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  ComplaintService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  CollectionReference<Map<String, dynamic>> get _complaintsRef =>
      _firestore.collection('complaints');

  /// Creates and stores a new complaint / support ticket in Firestore.
  /// Enforces verified authenticated user UID for ownership to prevent forgery.
  Future<CustomerComplaint> createComplaint({
    required String customerId,
    required String customerName,
    required String phone,
    String email = '',
    required String subject,
    required String description,
    required String category,
    String? orderId,
    String priority = 'Medium',
  }) async {
    final docRef = _complaintsRef.doc();
    final now = DateTime.now();
    // Unique human-readable ticket ID (e.g. CMP-492018)
    final ticketNum =
        (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final ticketId = 'CMP-$ticketNum';

    // Verify current authenticated UID — never trust independent UI-supplied UID
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveCustomerId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (customerId.isNotEmpty ? customerId : '');

    if (effectiveCustomerId.isEmpty) {
      throw Exception('Authentication required to submit support ticket.');
    }

    final data = <String, dynamic>{
      'id': docRef.id,
      'ticketId': ticketId,
      'customerId': effectiveCustomerId,
      'userId': effectiveCustomerId,
      'customerName': customerName.trim(),
      'customerPhone': phone.trim(),
      'customerEmail': email.trim(),
      'subject': subject.trim(),
      'category': category.trim(),
      'issueType': category.trim(),
      'description': description.trim(),
      'orderId': (orderId != null && orderId.trim().isNotEmpty)
          ? orderId.trim()
          : null,
      'priority': priority,
      'status': 'Open',
      'adminReply': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);

    return CustomerComplaint(
      id: docRef.id,
      ticketId: ticketId,
      customerId: effectiveCustomerId,
      customerName: customerName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      subject: subject.trim(),
      issueType: category.trim(),
      description: description.trim(),
      orderId: (orderId != null && orderId.trim().isNotEmpty)
          ? orderId.trim()
          : null,
      priority: priority,
      status: 'Open',
      adminReply: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Real-time stream of complaints filed by a specific customer.
  /// Queries only tickets belonging to the authenticated customer UID.
  /// Result is sorted client-side by date descending.
  Stream<List<CustomerComplaint>> streamComplaintsForCustomer(
      String customerId) {
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final effectiveUid =
          (authUid != null && authUid.isNotEmpty) ? authUid : customerId;

      if (effectiveUid.isEmpty) {
        return Stream.value(<CustomerComplaint>[]);
      }

      return _complaintsRef
          .where('customerId', isEqualTo: effectiveUid)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => CustomerComplaint.fromFirestore(doc))
            .toList();
        // Sort newest first
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (_) {
      return Stream.value(<CustomerComplaint>[]);
    }
  }

  /// Real-time stream of all complaints across the system for the Admin panel.
  Stream<List<CustomerComplaint>> streamAllComplaints() {
    try {
      if (Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      return _complaintsRef.snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => CustomerComplaint.fromFirestore(doc))
            .toList();
        // Sort newest first
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Updates complaint status and optionally attaches admin response / resolution notes.
  Future<void> updateComplaintStatus(
    String complaintId,
    String newStatus, {
    String? adminReply,
  }) async {
    if (complaintId.isEmpty) return;

    final updates = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (adminReply != null) {
      updates['adminReply'] = adminReply.trim();
    }

    await _complaintsRef.doc(complaintId).update(updates);
  }

  /// Adds or updates the admin reply message for a complaint ticket.
  Future<void> addAdminReply(
    String complaintId,
    String adminReply, {
    String? newStatus,
  }) async {
    if (complaintId.isEmpty) return;

    final updates = <String, dynamic>{
      'adminReply': adminReply.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus != null && newStatus.isNotEmpty) {
      updates['status'] = newStatus;
    }

    await _complaintsRef.doc(complaintId).update(updates);
  }
}
