enum OrderStatus {
  pending,
  confirmed,
  assigned,
  preparing,
  outForDelivery,
  delivered,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
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

class DairyOrder {
  final String id;
  final String orderCode;
  final String customerName;
  final String customerPhone;
  final String itemsSummary;
  final double amount;
  final OrderStatus status;
  final String deliverySlot;
  final String address;
  final String time;
  final String paymentMode;
  final String? assignedAgentId;
  final String? assignedAgentName;
  final String orderType;
  final String? subscriptionId;

  const DairyOrder({
    required this.id,
    this.orderCode = '',
    required this.customerName,
    required this.customerPhone,
    required this.itemsSummary,
    required this.amount,
    required this.status,
    required this.deliverySlot,
    required this.address,
    required this.time,
    required this.paymentMode,
    this.assignedAgentId,
    this.assignedAgentName,
    this.orderType = 'normal',
    this.subscriptionId,
  });

  bool get isSubscription =>
      orderType.toLowerCase() == 'subscription' ||
      (subscriptionId != null && subscriptionId!.isNotEmpty);

  /// The customer-facing 6-character order code (e.g. "KRT482").
  String get displayCode => orderCode.isNotEmpty ? orderCode : id;

  /// Whether this order currently has a delivery agent assigned.
  bool get isAssigned =>
      assignedAgentId != null && assignedAgentId!.trim().isNotEmpty;

  static const Object _sentinel = Object();

  DairyOrder copyWith({
    String? id,
    String? orderCode,
    String? customerName,
    String? customerPhone,
    String? itemsSummary,
    double? amount,
    OrderStatus? status,
    String? deliverySlot,
    String? address,
    String? time,
    String? paymentMode,
    Object? assignedAgentId = _sentinel,
    Object? assignedAgentName = _sentinel,
    String? orderType,
    String? subscriptionId,
  }) {
    return DairyOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      address: address ?? this.address,
      time: time ?? this.time,
      paymentMode: paymentMode ?? this.paymentMode,
      assignedAgentId: identical(assignedAgentId, _sentinel)
          ? this.assignedAgentId
          : assignedAgentId as String?,
      assignedAgentName: identical(assignedAgentName, _sentinel)
          ? this.assignedAgentName
          : assignedAgentName as String?,
      orderType: orderType ?? this.orderType,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }
}
