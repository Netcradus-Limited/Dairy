import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';
import 'order.dart';
import 'subscription.dart';

/// Represents a unified date-wise delivery or purchase record for a customer.
/// Can originate from a one-off order, a recurring subscription schedule,
/// or a dedicated Firestore record in `/users/{customerId}/delivery_records`.
class CustomerDeliveryRecord {
  final String id;
  final String customerId;
  final String? orderId;
  final String? orderCode;
  final String? subscriptionId;
  final String productId;
  final String productName;
  final String? productImage;
  final DateTime date;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;
  final String deliverySlot;
  final String
      deliveryStatus; // Delivered, Scheduled, Out for Delivery, Pending, Skipped, Cancelled, Failed
  final String paymentStatus; // Paid, Pending, COD, Wallet, Cancelled
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerDeliveryRecord({
    required this.id,
    required this.customerId,
    this.orderId,
    this.orderCode,
    this.subscriptionId,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.date,
    required this.quantity,
    this.unit = 'Litres',
    required this.unitPrice,
    required this.totalAmount,
    this.deliverySlot = 'Morning',
    this.deliveryStatus = 'Scheduled',
    this.paymentStatus = 'Pending',
    this.createdAt,
    this.updatedAt,
  });

  bool get isDelivered => deliveryStatus.toLowerCase() == 'delivered';
  bool get isSkipped => deliveryStatus.toLowerCase() == 'skipped';
  bool get isCancelled => deliveryStatus.toLowerCase() == 'cancelled';
  bool get isScheduled =>
      deliveryStatus.toLowerCase() == 'scheduled' ||
      deliveryStatus.toLowerCase() == 'pending' ||
      deliveryStatus.toLowerCase() == 'confirmed' ||
      deliveryStatus.toLowerCase() == 'outfordelivery' ||
      deliveryStatus.toLowerCase() == 'out for delivery';

  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedTimeSlot =>
      deliverySlot.isNotEmpty ? deliverySlot : 'Morning';

  CustomerDeliveryRecord copyWith({
    String? id,
    String? customerId,
    String? orderId,
    String? orderCode,
    String? subscriptionId,
    String? productId,
    String? productName,
    String? productImage,
    DateTime? date,
    int? quantity,
    String? unit,
    double? unitPrice,
    double? totalAmount,
    String? deliverySlot,
    String? deliveryStatus,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerDeliveryRecord(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      orderCode: orderCode ?? this.orderCode,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CustomerDeliveryRecord.fromFirestore(
      Map<String, dynamic> data, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback ?? DateTime.now();
    }

    final double uPrice = (data['unitPrice'] is num)
        ? (data['unitPrice'] as num).toDouble()
        : 0.0;
    final int qty =
        (data['quantity'] is num) ? (data['quantity'] as num).toInt() : 1;
    final double tAmount = (data['totalAmount'] is num)
        ? (data['totalAmount'] as num).toDouble()
        : (uPrice * qty);

    return CustomerDeliveryRecord(
      id: docId,
      customerId: (data['customerId'] as String?) ?? '',
      orderId: data['orderId'] as String?,
      orderCode: data['orderCode'] as String?,
      subscriptionId: data['subscriptionId'] as String?,
      productId: (data['productId'] as String?) ?? '',
      productName: (data['productName'] as String?) ?? 'Dairy Product',
      productImage: data['productImage'] as String?,
      date: parseDate(data['date']),
      quantity: qty,
      unit: (data['unit'] as String?) ?? 'Litres',
      unitPrice: uPrice,
      totalAmount: tAmount,
      deliverySlot: (data['deliverySlot'] as String?) ?? 'Morning',
      deliveryStatus: (data['deliveryStatus'] as String?) ?? 'Scheduled',
      paymentStatus: (data['paymentStatus'] as String?) ?? 'Pending',
      createdAt:
          data['createdAt'] != null ? parseDate(data['createdAt']) : null,
      updatedAt:
          data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      if (orderId != null) 'orderId': orderId,
      if (orderCode != null) 'orderCode': orderCode,
      if (subscriptionId != null) 'subscriptionId': subscriptionId,
      'productId': productId,
      'productName': productName,
      if (productImage != null) 'productImage': productImage,
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'deliverySlot': deliverySlot,
      'deliveryStatus': deliveryStatus,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Converts an [Order] item to a [CustomerDeliveryRecord]
  static List<CustomerDeliveryRecord> fromOrder(Order order) {
    final orderDate = order.deliveryDate ?? order.orderDate;
    final String statusStr = _mapOrderStatus(order.status);
    final String payStatus =
        (order.paymentMethod.toLowerCase().contains('cash') ||
                order.paymentMethod.toLowerCase().contains('cod'))
            ? (order.status == OrderStatus.delivered ? 'Paid' : 'COD')
            : (order.status == OrderStatus.cancelled ? 'Cancelled' : 'Paid');

    final String slot =
        order.estimatedDeliveryTime.toLowerCase().contains('evening')
            ? 'Evening'
            : 'Morning';

    if (order.items.isEmpty) {
      return [
        CustomerDeliveryRecord(
          id: '${order.id}_item_0',
          customerId: order.userId,
          orderId: order.id,
          orderCode: order.displayOrderCode,
          productId: 'prod_general',
          productName: 'Dairy Order (${order.displayOrderCode})',
          productImage: null,
          date: orderDate,
          quantity: 1,
          unit: 'Order',
          unitPrice: order.totalAmount,
          totalAmount: order.totalAmount,
          deliverySlot: slot,
          deliveryStatus: statusStr,
          paymentStatus: payStatus,
          createdAt: order.orderDate,
        )
      ];
    }

    return order.items.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      return CustomerDeliveryRecord(
        id: '${order.id}_item_$idx',
        customerId: order.userId,
        orderId: order.id,
        orderCode: order.displayOrderCode,
        productId: item.product.id,
        productName: item.product.title,
        productImage: item.product.imageUrl,
        date: orderDate,
        quantity: item.quantity,
        unit: item.product.unit,
        unitPrice: item.product.price,
        totalAmount: item.totalPrice,
        deliverySlot: slot,
        deliveryStatus: statusStr,
        paymentStatus: payStatus,
        createdAt: order.orderDate,
      );
    }).toList();
  }

  /// Generates scheduled / delivered records for a [Subscription] on a specific [targetDate]
  static CustomerDeliveryRecord? fromSubscriptionForDate({
    required Subscription subscription,
    required String customerId,
    required DateTime targetDate,
    List<DateTime> skippedDates = const [],
    DateTime? referenceDate,
  }) {
    final normalizedTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedStart = DateTime(subscription.startDate.year,
        subscription.startDate.month, subscription.startDate.day);

    if (normalizedTarget.isBefore(normalizedStart)) {
      return null;
    }

    if (subscription.endDate != null) {
      final normalizedEnd = DateTime(subscription.endDate!.year,
          subscription.endDate!.month, subscription.endDate!.day);
      if (normalizedTarget.isAfter(normalizedEnd)) {
        return null;
      }
    }

    // Check frequency match
    bool isScheduledOnDate = false;
    switch (subscription.frequency) {
      case SubscriptionFrequency.daily:
        isScheduledOnDate = true;
        break;
      case SubscriptionFrequency.alternateDay:
        final diffDays = normalizedTarget.difference(normalizedStart).inDays;
        isScheduledOnDate = (diffDays % 2 == 0);
        break;
      case SubscriptionFrequency.weekly:
        isScheduledOnDate =
            (normalizedTarget.weekday == normalizedStart.weekday);
        break;
    }

    if (!isScheduledOnDate) return null;

    // Check if skipped
    final isSkipped = skippedDates.any((d) =>
        d.year == targetDate.year &&
        d.month == targetDate.month &&
        d.day == targetDate.day);

    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    String status;
    String payStatus;

    if (subscription.status == SubscriptionStatus.cancelled) {
      status = 'Cancelled';
      payStatus = 'Cancelled';
    } else if (subscription.status == SubscriptionStatus.paused) {
      status = 'Paused';
      payStatus = 'Pending';
    } else if (isSkipped) {
      status = 'Skipped';
      payStatus = 'Skipped';
    } else if (normalizedTarget.isBefore(today)) {
      status = 'Delivered';
      payStatus = 'Paid';
    } else if (normalizedTarget.isAtSameMomentAs(today)) {
      status = 'Delivered'; // or Scheduled if before 9 AM
      payStatus = 'Paid';
    } else {
      status = 'Scheduled';
      payStatus = 'Pending';
    }

    final slot = subscription.deliveryTimeSlot.toLowerCase().contains('evening')
        ? 'Evening'
        : 'Morning';

    final dateKey = DateFormat('yyyyMMdd').format(targetDate);
    final id = 'SUB_${subscription.id}_$dateKey';

    return CustomerDeliveryRecord(
      id: id,
      customerId: customerId,
      subscriptionId: subscription.id,
      productId: subscription.product.id,
      productName: subscription.product.title,
      productImage: subscription.product.imageUrl,
      date: targetDate,
      quantity: subscription.quantity,
      unit: subscription.product.unit,
      unitPrice: subscription.product.price,
      totalAmount: subscription.priceAfterDiscountPerDelivery,
      deliverySlot: slot,
      deliveryStatus: status,
      paymentStatus: payStatus,
      createdAt: subscription.createdAt,
      updatedAt: subscription.updatedAt,
    );
  }

  static String _mapOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
      case OrderStatus.confirmed:
        return 'Scheduled';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
