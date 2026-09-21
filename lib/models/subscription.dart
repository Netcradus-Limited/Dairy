import '../models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription delivery frequency for Sawariya Dairy
enum SubscriptionFrequency {
  daily,
  alternateDay,
  weekly,
}

extension SubscriptionFrequencyExtension on SubscriptionFrequency {
  String get label {
    switch (this) {
      case SubscriptionFrequency.daily:
        return 'Daily';
      case SubscriptionFrequency.alternateDay:
        return 'Alternate Day';
      case SubscriptionFrequency.weekly:
        return 'Weekly';
    }
  }

  /// Approximate number of deliveries per month
  int get deliveriesPerMonth {
    switch (this) {
      case SubscriptionFrequency.daily:
        return 30;
      case SubscriptionFrequency.alternateDay:
        return 15;
      case SubscriptionFrequency.weekly:
        return 4;
    }
  }
}

/// Subscription status
enum SubscriptionStatus { active, paused, cancelled }

extension SubscriptionStatusExtension on SubscriptionStatus {
  String get label {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.paused:
        return 'Paused';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Subscription Model for Sawariya Dairy (Phase 7+)
///
/// Represents a recurring dairy product delivery tied to a base product,
/// with Firestore persistence support via fromFirestore/toFirestore.
class Subscription {
  final String id;
  final Product product;
  final int quantity;
  final SubscriptionFrequency frequency;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? nextDeliveryDate;
  final DateTime? endDate;
  final String deliveryTimeSlot;
  final bool includeIcePack;
  final double discountRate;

  /// Firestore-backed subscription plan fields
  final String? userId;
  final String? planId;
  final String? planName;
  final bool? autoRenew;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.frequency = SubscriptionFrequency.daily,
    this.status = SubscriptionStatus.active,
    required this.startDate,
    this.nextDeliveryDate,
    this.endDate,
    this.deliveryTimeSlot = 'Morning (6:00 AM - 9:00 AM)',
    this.includeIcePack = true,
    this.discountRate = 0.10,
    this.userId,
    this.planId,
    this.planName,
    this.autoRenew,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == SubscriptionStatus.active;
  bool get isPaused => status == SubscriptionStatus.paused;
  bool get isCancelled => status == SubscriptionStatus.cancelled;

  /// Base price per delivery (before discount)
  double get pricePerDelivery => product.price * quantity;

  /// Discount amount per delivery
  double get discountPerDelivery => pricePerDelivery * discountRate;

  /// Price after discount per delivery
  double get priceAfterDiscountPerDelivery =>
      (pricePerDelivery - discountPerDelivery).clamp(0.0, double.infinity);

  /// Estimated monthly cost
  double get monthlyCost =>
      priceAfterDiscountPerDelivery * frequency.deliveriesPerMonth;

  /// Check if subscription is active (status active AND endDate in future)
  bool get isActiveAndValid =>
      (isActive && endDate == null) ||
      (endDate != null && endDate!.isAfter(DateTime.now()));

  factory Subscription.fromFirestore(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Subscription.fromMap(data, id: snapshot.id);
  }

  factory Subscription.fromMap(Map<String, dynamic> data, {String? id}) {
    final String freqLabel = (data['frequency'] as String?) ?? 'Daily';
    final SubscriptionFrequency freq = SubscriptionFrequency.values.firstWhere(
      (f) =>
          f.label.toLowerCase() == freqLabel.toLowerCase() ||
          (freqLabel.toLowerCase().startsWith('alternate') &&
              f == SubscriptionFrequency.alternateDay),
      orElse: () => SubscriptionFrequency.daily,
    );
    final String statusLabel = (data['status'] as String?) ?? 'Active';
    final SubscriptionStatus status = SubscriptionStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == statusLabel.toLowerCase(),
      orElse: () => SubscriptionStatus.active,
    );

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final productMap = data['product'] as Map<String, dynamic>?;
    final Product product = productMap != null
        ? Product(
            id: productMap['id'] ?? data['productId'] ?? '',
            title: productMap['title'] ?? data['productTitle'] ?? '',
            categoryId:
                productMap['categoryId'] ?? data['productCategoryId'] ?? '',
            categoryName:
                productMap['categoryName'] ?? data['productCategoryName'] ?? '',
            price: ((productMap['price'] ?? data['productPrice']) ?? 0.0)
                .toDouble(),
            originalPrice: ((productMap['originalPrice'] ??
                        data['productOriginalPrice']) ??
                    0.0)
                .toDouble(),
            unit: productMap['unit'] ?? data['productUnit'] ?? '500 ml',
            imageUrl: productMap['imageUrl'] ?? data['productImageUrl'] ?? '',
            description:
                productMap['description'] ?? data['productDescription'] ?? '',
            rating: ((productMap['rating'] ?? data['productRating']) ?? 5.0)
                .toDouble(),
            reviewCount:
                productMap['reviewCount'] ?? data['productReviewCount'] ?? 0,
            isA2CowMilk:
                productMap['isA2CowMilk'] ?? data['isA2CowMilk'] ?? false,
            isBestSeller:
                productMap['isBestSeller'] ?? data['isBestSeller'] ?? false,
            isFreshDeal:
                productMap['isFreshDeal'] ?? data['isFreshDeal'] ?? false,
          )
        : Product(
            id: data['productId'] ?? '',
            title: data['productTitle'] ?? '',
            categoryId: data['productCategoryId'] ?? '',
            categoryName: data['productCategoryName'] ?? '',
            price: (data['productPrice'] ?? 0.0).toDouble(),
            originalPrice: (data['productOriginalPrice'] ?? 0.0).toDouble(),
            unit: data['productUnit'] ?? '500 ml',
            imageUrl: data['productImageUrl'] ?? '',
            description: data['productDescription'] ?? '',
            rating: (data['productRating'] ?? 5.0).toDouble(),
            reviewCount: data['productReviewCount'] ?? 0,
            isA2CowMilk: data['isA2CowMilk'] ?? false,
            isBestSeller: data['isBestSeller'] ?? false,
            isFreshDeal: data['isFreshDeal'] ?? false,
          );

    final rawQty = data['quantity'];
    int parsedQuantity = 1;
    if (rawQty is num) {
      parsedQuantity = rawQty.toInt();
    } else if (rawQty is String) {
      parsedQuantity = int.tryParse(rawQty) ?? 1;
    }
    if (parsedQuantity < 1) parsedQuantity = 1;

    final userId = (data['userId'] as String?) ?? (data['uid'] as String?);

    return Subscription(
      id: id ?? (data['id'] as String?) ?? (data['subscriptionId'] as String?) ?? '',
      product: product,
      quantity: parsedQuantity,
      frequency: freq,
      status: status,
      startDate: parseDate(data['startDate']) ??
          parseDate(data['createdAt']) ??
          DateTime.now(),
      nextDeliveryDate: parseDate(data['nextDeliveryDate']),
      endDate: parseDate(data['endDate']),
      deliveryTimeSlot:
          data['deliveryTimeSlot'] ?? 'Morning (6:00 AM - 9:00 AM)',
      includeIcePack: data['includeIcePack'] ?? true,
      discountRate: (data['discountRate'] ?? 0.10).toDouble(),
      userId: userId,
      planId: data['planId'],
      planName: data['planName'],
      autoRenew: data['autoRenew'] ?? false,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'id': id,
      'subscriptionId': id,
      'userId': userId ?? '',
      'uid': userId ?? '',
      'product': product.toMap(),
      'productId': product.id,
      'productName': product.title,
      'productTitle': product.title,
      'productCategoryId': product.categoryId,
      'productCategoryName': product.categoryName,
      'productPrice': product.price,
      'productOriginalPrice': product.originalPrice,
      'productUnit': product.unit,
      'productImageUrl': product.imageUrl,
      'productDescription': product.description,
      'productRating': product.rating,
      'productReviewCount': product.reviewCount,
      'isA2CowMilk': product.isA2CowMilk,
      'isBestSeller': product.isBestSeller,
      'isFreshDeal': product.isFreshDeal,
      'quantity': quantity,
      'frequency': frequency.label,
      'status': status.label,
      'deliverySlot': deliveryTimeSlot,
      'deliveryTimeSlot': deliveryTimeSlot,
      'pricePerDelivery': priceAfterDiscountPerDelivery,
      'estimatedMonthlyPrice': monthlyCost,
      'startDate': Timestamp.fromDate(startDate),
      'includeIcePack': includeIcePack,
      'discountRate': discountRate,
      'planId': planId ?? 'plan_${product.id}',
      'planName': planName ?? '${product.title} Monthly Plan',
      'autoRenew': autoRenew ?? true,
    };
    if (nextDeliveryDate != null) {
      map['nextDeliveryDate'] = Timestamp.fromDate(nextDeliveryDate!);
    }
    if (endDate != null) {
      map['endDate'] = Timestamp.fromDate(endDate!);
    }
    if (createdAt != null) {
      map['createdAt'] = Timestamp.fromDate(createdAt!);
    } else {
      map['createdAt'] = Timestamp.fromDate(startDate);
    }
    if (updatedAt != null) {
      map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    } else {
      map['updatedAt'] = Timestamp.fromDate(startDate);
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'subscriptionId': id,
      'userId': userId ?? '',
      'uid': userId ?? '',
      'product': product.toMap(),
      'productId': product.id,
      'productTitle': product.title,
      'productPrice': product.price,
      'quantity': quantity,
      'frequency': frequency.label,
      'status': status.label,
      'startDate': startDate.toIso8601String(),
      'deliveryTimeSlot': deliveryTimeSlot,
      'includeIcePack': includeIcePack,
      'discountRate': discountRate,
      'planId': planId ?? 'plan_${product.id}',
      'planName': planName ?? '${product.title} Monthly Plan',
      'autoRenew': autoRenew ?? true,
    };
    if (nextDeliveryDate != null) {
      map['nextDeliveryDate'] = nextDeliveryDate!.toIso8601String();
    }
    if (endDate != null) {
      map['endDate'] = endDate!.toIso8601String();
    }
    if (createdAt != null) {
      map['createdAt'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      map['updatedAt'] = updatedAt!.toIso8601String();
    }
    return map;
  }

  Subscription copyWith({
    String? id,
    Product? product,
    int? quantity,
    SubscriptionFrequency? frequency,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? nextDeliveryDate,
    DateTime? endDate,
    String? deliveryTimeSlot,
    bool? includeIcePack,
    double? discountRate,
    String? userId,
    String? planId,
    String? planName,
    bool? autoRenew,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      nextDeliveryDate: nextDeliveryDate ?? this.nextDeliveryDate,
      endDate: endDate ?? this.endDate,
      deliveryTimeSlot: deliveryTimeSlot ?? this.deliveryTimeSlot,
      includeIcePack: includeIcePack ?? this.includeIcePack,
      discountRate: discountRate ?? this.discountRate,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      autoRenew: autoRenew ?? this.autoRenew,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
