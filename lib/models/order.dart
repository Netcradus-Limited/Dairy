import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import 'address.dart';
import 'cart_item.dart';
import 'product.dart';

enum OrderStatus {
  placed,
  confirmed,
  assigned,
  preparing,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.preparing:
        return 'Preparing Fresh';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get stepIndex {
    switch (this) {
      case OrderStatus.placed:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.assigned:
        return 2;
      case OrderStatus.preparing:
        return 3;
      case OrderStatus.outForDelivery:
        return 4;
      case OrderStatus.delivered:
        return 5;
      case OrderStatus.cancelled:
        return -1;
    }
  }
}

/// Order Model for Sawariya Dairy
class Order {
  final String id;
  final String orderCode;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double discount;
  final double totalAmount;
  final OrderStatus status;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final Address deliveryAddress;
  final String paymentMethod;
  final String estimatedDeliveryTime;
  final String? assignedAgentId;
  final String? assignedAgentName;
  final DateTime? assignedAt;
  final DateTime? approvedAt;
  final DateTime? acceptedAt;
  final String userId;
  final String? pickupLocation;
  final String? pickupPhone;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String orderType;
  final String? subscriptionId;
  final String? deliverySlot;
  final String? paymentStatus;
  final DateTime? deliveredAt;
  final String? cancellationReason;

  const Order({
    required this.id,
    this.orderCode = '',
    required this.items,
    required this.subtotal,
    this.deliveryCharge = 0.0,
    this.discount = 0.0,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    this.deliveryDate,
    required this.deliveryAddress,
    this.paymentMethod = 'Cash on Delivery',
    this.estimatedDeliveryTime = 'Today by 7:30 AM',
    this.assignedAgentId,
    this.assignedAgentName,
    this.assignedAt,
    this.approvedAt,
    this.acceptedAt,
    this.userId = '',
    this.pickupLocation,
    this.pickupPhone,
    this.pickupLatitude,
    this.pickupLongitude,
    this.orderType = 'normal',
    this.subscriptionId,
    this.deliverySlot,
    this.paymentStatus,
    this.deliveredAt,
    this.cancellationReason,
  });

  bool get isSubscription =>
      orderType.toLowerCase() == 'subscription' ||
      (subscriptionId != null && subscriptionId!.isNotEmpty);

  /// The customer-facing 6-character order code (e.g. "KRT482").
  /// Format: LLLNNN (3 uppercase letters + 3 digits).
  /// Falls back deterministically to a formatted 6-character code from [id]
  /// if not stored.
  String get displayOrderCode {
    final trimmed = orderCode.trim().toUpperCase();
    if (trimmed.length == 6 &&
        RegExp(r'^[A-Z]{3}[0-9]{3}$').hasMatch(trimmed)) {
      return trimmed;
    }
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return formatFallbackOrderCode(id);
  }

  bool get isUpcoming =>
      status == OrderStatus.placed ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.assigned ||
      status == OrderStatus.preparing ||
      status == OrderStatus.outForDelivery;

  bool get isCompleted => status == OrderStatus.delivered;

  bool get isCancelled => status == OrderStatus.cancelled;

  bool get canCancel =>
      status == OrderStatus.placed ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.assigned;

  Order copyWith({
    String? id,
    String? orderCode,
    List<CartItem>? items,
    double? subtotal,
    double? deliveryCharge,
    double? discount,
    double? totalAmount,
    OrderStatus? status,
    DateTime? orderDate,
    DateTime? deliveryDate,
    Address? deliveryAddress,
    String? paymentMethod,
    String? estimatedDeliveryTime,
    String? assignedAgentId,
    String? assignedAgentName,
    DateTime? assignedAt,
    DateTime? approvedAt,
    DateTime? acceptedAt,
    String? userId,
    String? pickupLocation,
    String? pickupPhone,
    double? pickupLatitude,
    double? pickupLongitude,
    String? orderType,
    String? subscriptionId,
    String? deliverySlot,
    String? paymentStatus,
    DateTime? deliveredAt,
    String? cancellationReason,
  }) {
    return Order(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      assignedAgentName: assignedAgentName ?? this.assignedAgentName,
      assignedAt: assignedAt ?? this.assignedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      userId: userId ?? this.userId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      orderType: orderType ?? this.orderType,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  /// Generates a random 6-character customer-facing order code (LLLNNN).
  /// 3 uppercase English letters A-Z followed by 3 digits 0-9.
  static String generateRandomOrderCode([Random? random]) {
    final rng = random ?? Random();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';

    final l1 = letters[rng.nextInt(letters.length)];
    final l2 = letters[rng.nextInt(letters.length)];
    final l3 = letters[rng.nextInt(letters.length)];
    final d1 = digits[rng.nextInt(digits.length)];
    final d2 = digits[rng.nextInt(digits.length)];
    final d3 = digits[rng.nextInt(digits.length)];

    return '$l1$l2$l3$d1$d2$d3';
  }

  /// Deterministically derives a 6-character code (3 uppercase letters + 3 digits)
  /// from any input string (e.g. Firestore docId), ensuring consistent display
  /// across app restarts for existing legacy orders that lacked an orderCode.
  static String formatFallbackOrderCode(String docId) {
    if (docId.trim().isEmpty) return 'ORD000';
    final cleanDocId = docId.trim();
    int hash = 0;
    for (int i = 0; i < cleanDocId.length; i++) {
      hash = (hash * 31 + cleanDocId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final l1 = letters[hash % 26];
    final l2 = letters[(hash ~/ 26) % 26];
    final l3 = letters[(hash ~/ (26 * 26)) % 26];
    final numPart =
        ((hash ~/ (26 * 26 * 26)) % 1000).toString().padLeft(3, '0');
    return '$l1$l2$l3$numPart';
  }

  /// Creates an [Order] from a Firestore document map.
  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    final itemsData = (data['items'] as List?) ?? [];
    final items = itemsData.map((raw) {
      final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final pMap = m['product'] is Map<String, dynamic>
          ? m['product'] as Map<String, dynamic>
          : null;
      final rawImg = (m['imageUrl'] ??
              m['image'] ??
              m['productImage'] ??
              m['imagePath'] ??
              m['productImageUrl'] ??
              m['image_url'] ??
              m['photoUrl'] ??
              m['imageURL'] ??
              pMap?['imageUrl'] ??
              pMap?['image'] ??
              pMap?['productImage'] ??
              pMap?['imagePath'] ??
              pMap?['productImageUrl'] ??
              pMap?['photoUrl']) as String? ??
          '';

      final prodId = (m['productId'] as String?) ??
          (pMap?['id'] as String?) ??
          (m['id'] as String?) ??
          '';
      final prodTitle = (m['title'] as String?) ??
          (m['productName'] as String?) ??
          (m['name'] as String?) ??
          (pMap?['title'] as String?) ??
          (pMap?['name'] as String?) ??
          '';
      final catId = (m['categoryId'] as String?) ??
          (m['category'] as String?) ??
          (pMap?['categoryId'] as String?) ??
          (pMap?['category'] as String?) ??
          '';
      final catName = (m['categoryName'] as String?) ??
          (m['category'] as String?) ??
          (pMap?['categoryName'] as String?) ??
          '';
      final price = (m['price'] as num?)?.toDouble() ??
          (pMap?['price'] as num?)?.toDouble() ??
          0.0;
      final unit = (m['unit'] as String?) ??
          (pMap?['unit'] as String?) ??
          '';

      final product = Product(
        id: prodId,
        title: prodTitle,
        categoryId: catId,
        categoryName: catName,
        price: price,
        unit: unit,
        imageUrl: rawImg.trim(),
      );
      return CartItem(
        product: product,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    final addr = data['deliveryAddress'] as Map<String, dynamic>?;
    Address deliveryAddress = addr == null
        ? const Address(
            id: '',
            label: 'Home',
            fullName: 'Customer',
            mobileNumber: '',
            houseFlat: '',
            streetArea: '',
            city: '',
            state: '',
            pinCode: '',
          )
        : Address.fromMap(addr, (addr['id'] as String?) ?? '');

    // If deliveryAddress did not carry coordinates, check top-level order doc fields
    if (!deliveryAddress.hasCoordinates) {
      final topLoc = data['location'];
      double? topLat;
      double? topLng;
      if (topLoc is List && topLoc.length >= 2) {
        topLat = (topLoc[0] as num?)?.toDouble();
        topLng = (topLoc[1] as num?)?.toDouble();
      } else if (topLoc is GeoPoint) {
        topLat = topLoc.latitude;
        topLng = topLoc.longitude;
      } else if (topLoc is Map) {
        topLat = ((topLoc['latitude'] ?? topLoc['lat']) as num?)?.toDouble();
        topLng =
            ((topLoc['longitude'] ?? topLoc['lng'] ?? topLoc['lon']) as num?)
                ?.toDouble();
      } else {
        topLat = ((data['latitude'] ?? data['lat'] ?? data['customerLatitude'])
                as num?)
            ?.toDouble();
        topLng = ((data['longitude'] ??
                data['lng'] ??
                data['customerLongitude']) as num?)
            ?.toDouble();
      }
      if (topLat != null &&
          topLng != null &&
          !topLat.isNaN &&
          !topLng.isNaN &&
          topLat >= -90.0 &&
          topLat <= 90.0 &&
          topLng >= -180.0 &&
          topLng <= 180.0 &&
          !(topLat == 0.0 && topLng == 0.0)) {
        deliveryAddress =
            deliveryAddress.copyWith(latitude: topLat, longitude: topLng);
      }
    }

    final created = data['createdAt'];
    final orderDate = created is Timestamp
        ? created.toDate()
        : (created is String
            ? DateTime.tryParse(created) ?? DateTime.now()
            : DateTime.now());

    final rawDeliveryDate = data['deliveryDate'];
    final deliveryDate = rawDeliveryDate is Timestamp
        ? rawDeliveryDate.toDate()
        : (rawDeliveryDate is String
            ? DateTime.tryParse(rawDeliveryDate)
            : null);

    final assigned = data['assignedAt'];
    final assignedAt = assigned is Timestamp
        ? assigned.toDate()
        : (assigned is String ? DateTime.tryParse(assigned) : null);

    final approved = data['approvedAt'];
    final approvedAt = approved is Timestamp
        ? approved.toDate()
        : (approved is String ? DateTime.tryParse(approved) : null);

    final assignedAgentName = (data['assignedAgentName'] ??
            data['deliveryAgentName'] ??
            data['agentName'])
        as String?;

    final accepted = data['acceptedAt'];
    final acceptedAt = accepted is Timestamp
        ? accepted.toDate()
        : (accepted is String ? DateTime.tryParse(accepted) : null);

    final delivered = data['deliveredAt'];
    final deliveredAt = delivered is Timestamp
        ? delivered.toDate()
        : (delivered is String ? DateTime.tryParse(delivered) : null);

    final rawOrderCode = (data['orderCode'] as String?)?.trim() ?? '';
    final resolvedOrderCode = rawOrderCode.isNotEmpty
        ? rawOrderCode
        : Order.formatFallbackOrderCode(id);

    // Pickup / Store / Hub information extraction
    String? pickupLocation;
    String? pickupPhone;
    double? pickupLatitude;
    double? pickupLongitude;

    // 1. Check nested map: 'pickup', 'store', or 'hub'
    final pickupMap = (data['pickup'] is Map)
        ? (data['pickup'] as Map)
        : ((data['store'] is Map)
            ? (data['store'] as Map)
            : ((data['hub'] is Map) ? (data['hub'] as Map) : null));

    if (pickupMap != null) {
      final loc = (pickupMap['address'] ??
              pickupMap['location'] ??
              pickupMap['name'] ??
              pickupMap['title'])
          ?.toString()
          .trim();
      if (loc != null && loc.isNotEmpty) {
        pickupLocation = loc;
      }
      final phone = (pickupMap['phone'] ??
              pickupMap['phoneNumber'] ??
              pickupMap['mobile'])
          ?.toString()
          .trim();
      if (phone != null && phone.isNotEmpty) {
        pickupPhone = phone;
      }
      final lat =
          ((pickupMap['latitude'] ?? pickupMap['lat']) as num?)?.toDouble();
      final lng = ((pickupMap['longitude'] ??
              pickupMap['lng'] ??
              pickupMap['lon']) as num?)
          ?.toDouble();
      if (lat != null &&
          lng != null &&
          !lat.isNaN &&
          !lng.isNaN &&
          lat >= -90.0 &&
          lat <= 90.0 &&
          lng >= -180.0 &&
          lng <= 180.0 &&
          !(lat == 0.0 && lng == 0.0)) {
        pickupLatitude = lat;
        pickupLongitude = lng;
      }
    }

    // 2. Check top-level fields
    if (data['pickupLocation'] is Map) {
      final pMap = data['pickupLocation'] as Map;
      final loc =
          (pMap['address'] ?? pMap['location'] ?? pMap['name'] ?? pMap['title'])
              ?.toString()
              .trim();
      if (loc != null && loc.isNotEmpty) {
        pickupLocation = loc;
      }
      final phone = (pMap['phone'] ?? pMap['phoneNumber'] ?? pMap['mobile'])
          ?.toString()
          .trim();
      if (phone != null && phone.isNotEmpty) {
        pickupPhone = phone;
      }
      final lat = ((pMap['latitude'] ?? pMap['lat']) as num?)?.toDouble();
      final lng = ((pMap['longitude'] ?? pMap['lng'] ?? pMap['lon']) as num?)
          ?.toDouble();
      if (lat != null &&
          lng != null &&
          !lat.isNaN &&
          !lng.isNaN &&
          lat >= -90.0 &&
          lat <= 90.0 &&
          lng >= -180.0 &&
          lng <= 180.0 &&
          !(lat == 0.0 && lng == 0.0)) {
        pickupLatitude = lat;
        pickupLongitude = lng;
      }
    } else if (data['pickupLocation'] is String) {
      pickupLocation = data['pickupLocation'] as String;
    }

    if (pickupLocation == null) {
      final alt = (data['pickupAddress'] ??
          data['storeAddress'] ??
          data['hubAddress'] ??
          data['pickupName'] ??
          data['storeName'] ??
          data['hubName'] ??
          data['pickupHub']);
      if (alt is String) {
        pickupLocation = alt;
      }
    }

    if (pickupPhone == null) {
      final phone =
          (data['pickupPhone'] ?? data['storePhone'] ?? data['hubPhone']);
      if (phone is String) {
        pickupPhone = phone;
      }
    }

    if (pickupLatitude == null || pickupLongitude == null) {
      final pLat =
          ((data['pickupLatitude'] ?? data['pickupLat']) as num?)?.toDouble();
      final pLng = ((data['pickupLongitude'] ??
              data['pickupLng'] ??
              data['pickupLon']) as num?)
          ?.toDouble();
      if (pLat != null &&
          pLng != null &&
          !pLat.isNaN &&
          !pLng.isNaN &&
          pLat >= -90.0 &&
          pLat <= 90.0 &&
          pLng >= -180.0 &&
          pLng <= 180.0 &&
          !(pLat == 0.0 && pLng == 0.0)) {
        pickupLatitude = pLat;
        pickupLongitude = pLng;
      }
    }

    return Order(
      id: id,
      orderCode: resolvedOrderCode,
      items: items,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (data['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: orderStatusFromString((data['status'] as String?) ?? 'Pending'),
      orderDate: orderDate,
      deliveryDate: deliveryDate,
      deliveryAddress: deliveryAddress,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'Cash on Delivery',
      estimatedDeliveryTime: (data['estimatedDeliveryTime'] as String?) ?? '',
      assignedAgentId: (data['assignedAgentId'] ??
              data['deliveryAgentId'] ??
              data['agentId'] ??
              data['assignedDeliveryAgentId'] ??
              data['assignedTo']) as String?,
      assignedAgentName: assignedAgentName,
      assignedAt: assignedAt,
      approvedAt: approvedAt,
      acceptedAt: acceptedAt,
      userId: (data['userId'] as String?) ?? '',
      pickupLocation: pickupLocation,
      pickupPhone: pickupPhone,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      orderType: (data['orderType'] as String?) ?? 'normal',
      subscriptionId: (data['subscriptionId'] as String?),
      deliverySlot: (data['deliverySlot'] as String?),
      paymentStatus: (data['paymentStatus'] as String?),
      deliveredAt: deliveredAt,
      cancellationReason: (data['cancellationReason'] as String?),
    );
  }

  /// Serializes this [Order] for writing to Firestore.
  Map<String, dynamic> toFirestore() => {
        'orderCode': orderCode.isNotEmpty ? orderCode : displayOrderCode,
        'status': orderStatusToString(status),
        'customerName': deliveryAddress.fullName.trim().isNotEmpty
            ? deliveryAddress.fullName.trim()
            : 'Customer',
        'customerPhone': deliveryAddress.mobileNumber.trim(),
        if (userId.isNotEmpty) 'userId': userId,
        'orderType': orderType,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        if (deliverySlot != null) 'deliverySlot': deliverySlot,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (deliveredAt != null)
          'deliveredAt': Timestamp.fromDate(deliveredAt!),
        if (cancellationReason != null)
          'cancellationReason': cancellationReason,
        'items': items
            .map((item) => {
                  'productId': item.product.id,
                  'title': item.product.title,
                  'productName': item.product.title,
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
        'subtotal': subtotal,
        'deliveryCharge': deliveryCharge,
        'discount': discount,
        'totalAmount': totalAmount,
        'deliveryAddress': deliveryAddress.toMap(),
        'paymentMethod': paymentMethod,
        'estimatedDeliveryTime': estimatedDeliveryTime,
        if (deliveryDate != null)
          'deliveryDate': Timestamp.fromDate(deliveryDate!),
        if (assignedAgentId != null && assignedAgentId!.trim().isNotEmpty)
          'assignedAgentId': assignedAgentId!.trim(),
        if (assignedAgentName != null && assignedAgentName!.trim().isNotEmpty)
          'assignedAgentName': assignedAgentName!.trim(),
        if (assignedAt != null)
          'assignedAt': Timestamp.fromDate(assignedAt!),
        if (approvedAt != null)
          'approvedAt': Timestamp.fromDate(approvedAt!),
        if (acceptedAt != null) 'acceptedAt': acceptedAt,
        if (pickupLocation != null) 'pickupLocation': pickupLocation,
        if (pickupPhone != null) 'pickupPhone': pickupPhone,
        if (pickupLatitude != null) 'pickupLatitude': pickupLatitude,
        if (pickupLongitude != null) 'pickupLongitude': pickupLongitude,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderCode': orderCode.isNotEmpty ? orderCode : displayOrderCode,
        ...toFirestore(),
        'orderDate': orderDate.toIso8601String(),
        if (deliveryDate != null)
          'deliveryDate': Timestamp.fromDate(deliveryDate!),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> map, String id) =>
      Order.fromFirestore(map, id);
}

/// Maps a stored status string to an [OrderStatus].
OrderStatus orderStatusFromString(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
    case 'placed':
      return OrderStatus.placed;
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'assigned':
      return OrderStatus.assigned;
    case 'accepted':
    case 'preparing':
    case 'pickup':
      return OrderStatus.preparing;
    case 'out for delivery':
    case 'outfordelivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.placed;
  }
}

/// Maps an [OrderStatus] to the string stored in Firestore.
String orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.placed:
      return 'Pending';
    case OrderStatus.confirmed:
      return 'confirmed';
    case OrderStatus.assigned:
      return 'assigned';
    case OrderStatus.preparing:
      return 'preparing';
    case OrderStatus.outForDelivery:
      return 'outForDelivery';
    case OrderStatus.delivered:
      return 'delivered';
    case OrderStatus.cancelled:
      return 'cancelled';
  }
}
