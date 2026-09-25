import 'package:flutter/material.dart';

enum DeliveryStatus {
  available,
  onDuty,
  offDuty,
  breakTime,
}

enum DeliveryOrderStatus {
  pendingAcceptance,
  accepted,
  pickup,
  outForDelivery,
  delivered,
  cancelled,
  declined;

  String get statusLabel {
    switch (this) {
      case DeliveryOrderStatus.pendingAcceptance:
        return 'Pending Acceptance';
      case DeliveryOrderStatus.accepted:
        return 'Accepted';
      case DeliveryOrderStatus.pickup:
        return 'Pickup';
      case DeliveryOrderStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryOrderStatus.delivered:
        return 'Delivered';
      case DeliveryOrderStatus.cancelled:
        return 'Cancelled';
      case DeliveryOrderStatus.declined:
        return 'Declined';
    }
  }

  Color get statusColor {
    switch (this) {
      case DeliveryOrderStatus.pendingAcceptance:
        return const Color(0xFFF59E0B);
      case DeliveryOrderStatus.accepted:
        return const Color(0xFF3D7FE8);
      case DeliveryOrderStatus.pickup:
        return const Color(0xFFA855F7);
      case DeliveryOrderStatus.outForDelivery:
        return const Color(0xFF0284C7);
      case DeliveryOrderStatus.delivered:
        return const Color(0xFF10B981);
      case DeliveryOrderStatus.cancelled:
      case DeliveryOrderStatus.declined:
        return const Color(0xFFE53935);
    }
  }
}

enum DeliveryRequestStatus {
  pending,
  accepted,
  declined,
  expired,
}

class DeliveryAgent {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String vehicle;
  final String vehicleNumber;
  final String assignedZone;
  final DeliveryStatus status;
  final int totalDeliveriesToday;
  final int completedDeliveriesToday;
  final double earningsToday;
  final double? rating;
  final String? profileImageUrl;
  final bool isLoaded;

  const DeliveryAgent({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.vehicle,
    required this.vehicleNumber,
    required this.assignedZone,
    required this.status,
    required this.totalDeliveriesToday,
    required this.completedDeliveriesToday,
    required this.earningsToday,
    this.rating,
    this.profileImageUrl,
    this.isLoaded = true,
  });

  /// Factory for an uninitialized / empty profile without any fake mock data.
  factory DeliveryAgent.empty([String id = '']) => DeliveryAgent(
        id: id,
        name: '',
        phone: '',
        email: null,
        vehicle: '',
        vehicleNumber: '',
        assignedZone: '',
        status: DeliveryStatus.offDuty,
        totalDeliveriesToday: 0,
        completedDeliveriesToday: 0,
        earningsToday: 0.0,
        rating: null,
        profileImageUrl: null,
        isLoaded: false,
      );

  /// Creates a DeliveryAgent directly from a Firestore document map.
  factory DeliveryAgent.fromMap(Map<String, dynamic> map, String id) {
    final rawName = (map['name'] as String?)?.trim() ?? '';
    final rawPhone = (map['phone'] as String?)?.trim() ?? '';
    final rawVehicle =
        ((map['vehicle'] ?? map['vehicleType']) as String?)?.trim() ?? '';
    final rawVehicleNumber = (map['vehicleNumber'] as String?)?.trim() ?? '';
    final rawZone =
        ((map['assignedZone'] ?? map['zone']) as String?)?.trim() ?? '';
    final rawImage = ((map['profileImageUrl'] ??
            map['photoUrl'] ??
            map['photoURL']) as String?)
        ?.trim();
    final rawEmail = (map['email'] as String?)?.trim();

    final isOnline = map['isOnline'] == true || map['isOnDuty'] == true;

    return DeliveryAgent(
      id: id,
      name: rawName,
      phone: rawPhone,
      email: rawEmail?.isNotEmpty == true ? rawEmail : null,
      vehicle: rawVehicle,
      vehicleNumber: rawVehicleNumber,
      assignedZone: rawZone,
      status: isOnline ? DeliveryStatus.onDuty : DeliveryStatus.offDuty,
      totalDeliveriesToday: ((map['totalDeliveriesToday'] ?? 0) as num).toInt(),
      completedDeliveriesToday:
          ((map['completedDeliveriesToday'] ?? 0) as num).toInt(),
      earningsToday: ((map['earningsToday'] ?? 0.0) as num).toDouble(),
      rating: (map['rating'] as num?)?.toDouble(),
      profileImageUrl:
          (rawImage != null && rawImage.isNotEmpty) ? rawImage : null,
      isLoaded: true,
    );
  }

  bool get isProfileComplete =>
      name.trim().isNotEmpty && phone.trim().isNotEmpty;

  DeliveryAgent copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? vehicle,
    String? vehicleNumber,
    String? assignedZone,
    DeliveryStatus? status,
    int? totalDeliveriesToday,
    int? completedDeliveriesToday,
    double? earningsToday,
    double? rating,
    String? profileImageUrl,
    bool? isLoaded,
  }) {
    return DeliveryAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicle: vehicle ?? this.vehicle,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      assignedZone: assignedZone ?? this.assignedZone,
      status: status ?? this.status,
      totalDeliveriesToday: totalDeliveriesToday ?? this.totalDeliveriesToday,
      completedDeliveriesToday:
          completedDeliveriesToday ?? this.completedDeliveriesToday,
      earningsToday: earningsToday ?? this.earningsToday,
      rating: rating ?? this.rating,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class DeliveryOrder {
  final String id;
  final String orderId;
  final String orderCode;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String pickupLocation;
  final String pickupPhone;
  final List<String> items;
  final double amount;
  final double deliveryFee;
  final DeliveryOrderStatus status;
  final DateTime orderTime;
  final DateTime? acceptedTime;
  final DateTime? pickupTime;
  final DateTime? deliveredTime;
  final String distance;
  final String estimatedTime;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? assignedAgentId;
  final String orderType;
  final String? subscriptionId;
  final DateTime? deliveryDate;
  final String? deliverySlot;
  final String paymentMethod;
  final String? paymentStatus;
  final String? productImageUrl;
  final String? cancellationReason;

  const DeliveryOrder({
    required this.id,
    required this.orderId,
    this.orderCode = '',
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.pickupLocation,
    required this.pickupPhone,
    required this.items,
    required this.amount,
    required this.deliveryFee,
    required this.status,
    required this.orderTime,
    this.acceptedTime,
    this.pickupTime,
    this.deliveredTime,
    required this.distance,
    required this.estimatedTime,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.assignedAgentId,
    this.orderType = 'normal',
    this.subscriptionId,
    this.deliveryDate,
    this.deliverySlot,
    this.paymentMethod = 'Cash on Delivery',
    this.paymentStatus,
    this.productImageUrl,
    this.cancellationReason,
    this.orderItemDetails = const [],
  });

  final List<DeliveryOrderItem> orderItemDetails;

  bool get isSubscription =>
      orderType.toLowerCase() == 'subscription' ||
      (subscriptionId != null && subscriptionId!.isNotEmpty);

  /// The customer-facing 6-character order code (e.g. "KRT482").
  String get displayCode => orderCode.isNotEmpty ? orderCode : orderId;

  /// Returns true if valid, non-zero geographic coordinates are present.
  bool get hasValidCoordinates {
    if (latitude == null || longitude == null) return false;
    if (latitude!.isNaN ||
        longitude!.isNaN ||
        latitude!.isInfinite ||
        longitude!.isInfinite) return false;
    if (latitude! < -90.0 || latitude! > 90.0) return false;
    if (longitude! < -180.0 || longitude! > 180.0) return false;
    if (latitude! == 0.0 && longitude! == 0.0) return false;
    return true;
  }

  /// Returns true if valid, non-zero geographic pickup coordinates are present.
  bool get hasValidPickupCoordinates {
    if (pickupLatitude == null || pickupLongitude == null) {
      return false;
    }
    if (pickupLatitude!.isNaN ||
        pickupLongitude!.isNaN ||
        pickupLatitude!.isInfinite ||
        pickupLongitude!.isInfinite) {
      return false;
    }
    if (pickupLatitude! < -90.0 || pickupLatitude! > 90.0) {
      return false;
    }
    if (pickupLongitude! < -180.0 || pickupLongitude! > 180.0) {
      return false;
    }
    if (pickupLatitude! == 0.0 && pickupLongitude! == 0.0) {
      return false;
    }
    return true;
  }

  static const Object _sentinel = Object();

  DeliveryOrder copyWith({
    String? id,
    String? orderId,
    String? orderCode,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? pickupLocation,
    String? pickupPhone,
    List<String>? items,
    double? amount,
    double? deliveryFee,
    DeliveryOrderStatus? status,
    DateTime? orderTime,
    DateTime? acceptedTime,
    DateTime? pickupTime,
    DateTime? deliveredTime,
    String? distance,
    String? estimatedTime,
    double? distanceKm,
    double? latitude,
    double? longitude,
    double? pickupLatitude,
    double? pickupLongitude,
    Object? assignedAgentId = _sentinel,
    String? orderType,
    String? subscriptionId,
    DateTime? deliveryDate,
    String? deliverySlot,
    String? paymentMethod,
    String? paymentStatus,
    String? productImageUrl,
    String? cancellationReason,
    List<DeliveryOrderItem>? orderItemDetails,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderCode: orderCode ?? this.orderCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      items: items ?? this.items,
      amount: amount ?? this.amount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      status: status ?? this.status,
      orderTime: orderTime ?? this.orderTime,
      acceptedTime: acceptedTime ?? this.acceptedTime,
      pickupTime: pickupTime ?? this.pickupTime,
      deliveredTime: deliveredTime ?? this.deliveredTime,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      distanceKm: distanceKm ?? this.distanceKm,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      assignedAgentId: identical(assignedAgentId, _sentinel)
          ? this.assignedAgentId
          : assignedAgentId as String?,
      orderType: orderType ?? this.orderType,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      orderItemDetails: orderItemDetails ?? this.orderItemDetails,
    );
  }
}

class DeliveryOrderItem {
  final String name;
  final String unit;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String? productId;
  final String? categoryKey;

  const DeliveryOrderItem({
    required this.name,
    this.unit = '',
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.productId,
    this.categoryKey,
  });
}

class DeliveryRequest {
  final String id;
  final String orderId;
  final String orderCode;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String pickupLocation;
  final String pickupPhone;
  final List<String> items;
  final double amount;
  final double deliveryFee;
  final String distance;
  final String estimatedTime;
  final DateTime requestTime;
  final int countdownSeconds;
  final DeliveryRequestStatus status;
  final String orderType;
  final String? subscriptionId;
  final DateTime? deliveryDate;
  final String? deliverySlot;
  final String paymentMethod;
  final String? paymentStatus;
  final String? productImageUrl;

  const DeliveryRequest({
    required this.id,
    required this.orderId,
    this.orderCode = '',
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.pickupLocation,
    required this.pickupPhone,
    required this.items,
    required this.amount,
    required this.deliveryFee,
    required this.distance,
    required this.estimatedTime,
    required this.requestTime,
    required this.countdownSeconds,
    this.status = DeliveryRequestStatus.pending,
    this.orderType = 'normal',
    this.subscriptionId,
    this.deliveryDate,
    this.deliverySlot,
    this.paymentMethod = 'Cash on Delivery',
    this.paymentStatus,
    this.productImageUrl,
  });

  bool get isSubscription =>
      orderType.toLowerCase() == 'subscription' ||
      (subscriptionId != null && subscriptionId!.isNotEmpty);

  /// The customer-facing 6-character order code (e.g. "KRT482").
  String get displayCode => orderCode.isNotEmpty ? orderCode : orderId;

  DeliveryRequest copyWith({
    String? id,
    String? orderId,
    String? orderCode,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? pickupLocation,
    String? pickupPhone,
    List<String>? items,
    double? amount,
    double? deliveryFee,
    String? distance,
    String? estimatedTime,
    DateTime? requestTime,
    int? countdownSeconds,
    DeliveryRequestStatus? status,
    String? orderType,
    String? subscriptionId,
    DateTime? deliveryDate,
    String? deliverySlot,
    String? paymentMethod,
    String? paymentStatus,
    String? productImageUrl,
  }) {
    return DeliveryRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderCode: orderCode ?? this.orderCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      items: items ?? this.items,
      amount: amount ?? this.amount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      requestTime: requestTime ?? this.requestTime,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      status: status ?? this.status,
      orderType: orderType ?? this.orderType,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      productImageUrl: productImageUrl ?? this.productImageUrl,
    );
  }
}

class DeliveryEarnings {
  final DateTime date;
  final double baseEarnings;
  final double tips;
  final double bonuses;
  final int deliveriesCount;
  final double total;

  const DeliveryEarnings({
    required this.date,
    required this.baseEarnings,
    required this.tips,
    required this.bonuses,
    required this.deliveriesCount,
    required this.total,
  });
}

class DeliveryHistoryItem {
  final String orderId;
  final String orderCode;
  final String customerName;
  final String status;
  final double earnings;
  final DateTime date;
  final String distance;

  const DeliveryHistoryItem({
    required this.orderId,
    this.orderCode = '',
    required this.customerName,
    required this.status,
    required this.earnings,
    required this.date,
    required this.distance,
  });

  /// The customer-facing 6-character order code (e.g. "KRT482").
  String get displayCode => orderCode.isNotEmpty ? orderCode : orderId;
}
