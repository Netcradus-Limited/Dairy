import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Payment Model representing a Firestore document in the `payments` collection.
class DairyPayment {
  final String id;
  final String customerName;
  final String orderOrWalletId;
  final double amount;
  final String method; // 'Online (UPI)', 'Razorpay PG', 'Cash on Delivery', 'Prepaid Wallet'
  final String status; // 'Success', 'Pending', 'Failed', 'Cancelled'
  final String timestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? userId;
  final String? orderId;
  final String? orderCode;
  final String? customerPhone;
  final String? transactionId;

  const DairyPayment({
    required this.id,
    required this.customerName,
    required this.orderOrWalletId,
    required this.amount,
    required this.method,
    required this.status,
    required this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.orderId,
    this.orderCode,
    this.customerPhone,
    this.transactionId,
  });

  /// Factory constructor to safely deserialize from Firestore with resilient defaults
  factory DairyPayment.fromFirestore(Map<String, dynamic> data, String docId) {
    // Parse createdAt
    final created = data['createdAt'];
    DateTime? dt;
    if (created is Timestamp) {
      dt = created.toDate();
    } else if (created is String) {
      dt = DateTime.tryParse(created);
    }

    // Parse updatedAt
    final updated = data['updatedAt'];
    DateTime? updatedDt;
    if (updated is Timestamp) {
      updatedDt = updated.toDate();
    } else if (updated is String) {
      updatedDt = DateTime.tryParse(updated);
    }

    final dateStr = dt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(dt)
        : ((data['timestamp'] as String?)?.isNotEmpty == true
            ? data['timestamp'] as String
            : 'Recently');

    final rawAmount = data['amount'];
    final double amount = (rawAmount is num) ? rawAmount.toDouble() : 0.0;

    final rawName = (data['customerName'] as String?) ??
        (data['name'] as String?) ??
        (data['userName'] as String?) ??
        'Customer';

    final rawOrderCode = (data['orderCode'] as String?) ??
        (data['orderOrWalletId'] as String?) ??
        (data['orderId'] as String?) ??
        '#ORD';

    final orderOrWalletId = rawOrderCode.trim().startsWith('#')
        ? rawOrderCode.trim()
        : '#${rawOrderCode.trim()}';

    final rawMethod = (data['method'] as String?) ??
        (data['paymentMethod'] as String?) ??
        (data['paymentMode'] as String?) ??
        'Online Payment';

    final rawStatus = (data['status'] as String?) ??
        (data['paymentStatus'] as String?) ??
        'Success';

    final rawTxnId = (data['transactionId'] as String?) ??
        (data['txnId'] as String?) ??
        (data['razorpayPaymentId'] as String?);

    return DairyPayment(
      id: (data['id'] as String?)?.isNotEmpty == true
          ? (data['id'] as String)
          : (docId.startsWith('PAY_') || docId.startsWith('TXN-')
              ? docId
              : 'PAY_$docId'),
      customerName: rawName.trim().isNotEmpty ? rawName.trim() : 'Customer',
      orderOrWalletId: orderOrWalletId,
      amount: amount,
      method: rawMethod,
      status: normalizeStatus(rawStatus),
      timestamp: dateStr,
      createdAt: dt,
      updatedAt: updatedDt,
      userId: data['userId'] as String?,
      orderId: (data['orderId'] as String?) ?? (data['orderDocId'] as String?),
      orderCode: data['orderCode'] as String?,
      customerPhone: (data['customerPhone'] as String?) ??
          (data['phone'] as String?) ??
          (data['mobileNumber'] as String?),
      transactionId: rawTxnId,
    );
  }

  /// Normalizes status strings into standard TitleCase variants
  static String normalizeStatus(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'success' || s == 'completed' || s == 'paid' || s == 'delivered') {
      return 'Success';
    } else if (s == 'pending' || s == 'placed' || s == 'processing') {
      return 'Pending';
    } else if (s == 'cancelled' || s == 'canceled' || s == 'refunded') {
      return 'Cancelled';
    } else if (s == 'failed' || s == 'declined') {
      return 'Failed';
    }
    return 'Success';
  }

  /// Serializes to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'customerName': customerName,
      'orderOrWalletId': orderOrWalletId,
      'amount': amount,
      'method': method,
      'paymentMethod': method,
      'status': status,
      'paymentStatus': status,
      'timestamp': timestamp,
      if (userId != null) 'userId': userId,
      if (orderId != null) 'orderId': orderId,
      if (orderCode != null) 'orderCode': orderCode,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (transactionId != null) 'transactionId': transactionId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (updatedAt != null)
        'updatedAt': Timestamp.fromDate(updatedAt!)
      else
        'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DairyPayment copyWith({
    String? id,
    String? customerName,
    String? orderOrWalletId,
    double? amount,
    String? method,
    String? status,
    String? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? orderId,
    String? orderCode,
    String? customerPhone,
    String? transactionId,
  }) {
    return DairyPayment(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      orderOrWalletId: orderOrWalletId ?? this.orderOrWalletId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      orderCode: orderCode ?? this.orderCode,
      customerPhone: customerPhone ?? this.customerPhone,
      transactionId: transactionId ?? this.transactionId,
    );
  }
}
