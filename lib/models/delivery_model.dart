import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a delivery dispatch batch in Cloud Firestore (`delivery_batches/{batchId}`).
class DeliveryBatch {
  final String id;
  final String name;
  final String deliveryId;
  final DateTime? deliveryDate;
  final String? agentId;
  final String staffName;
  final String status;
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final String? routeId;
  final String zone;
  final List<String> orderIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeliveryBatch({
    required this.id,
    this.name = '',
    this.deliveryId = '',
    this.deliveryDate,
    this.agentId,
    required this.staffName,
    this.status = 'Pending',
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.pendingOrders = 0,
    this.routeId,
    this.zone = 'Standard Zone',
    this.orderIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Backward-compatibility getters for existing UI
  int get assignedCount => totalOrders;
  int get completedCount => completedOrders;
  String get agentName => staffName;

  double get completionPercentage => assignedCount == 0
      ? 0.0
      : (completedCount / assignedCount).clamp(0.0, 1.0);

  factory DeliveryBatch.fromFirestore(Map<String, dynamic> data, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final id = (data['id'] as String?)?.trim().isNotEmpty == true
        ? (data['id'] as String).trim()
        : docId;

    final name = (data['name'] as String?)?.trim() ??
        (data['deliveryId'] as String?)?.trim() ??
        (data['title'] as String?)?.trim() ??
        '';

    final deliveryId = (data['deliveryId'] as String?)?.trim().isNotEmpty == true
        ? (data['deliveryId'] as String).trim()
        : (name.isNotEmpty ? name : id);

    final agentName = (data['agentName'] as String?)?.trim() ??
        (data['staffName'] as String?)?.trim() ??
        (data['riderName'] as String?)?.trim() ??
        'Delivery Partner';

    final total = (data['totalOrders'] as num?)?.toInt() ??
        (data['assignedCount'] as num?)?.toInt() ??
        0;

    final completed = (data['completedOrders'] as num?)?.toInt() ??
        (data['completedCount'] as num?)?.toInt() ??
        0;

    final pending = (data['pendingOrders'] as num?)?.toInt() ??
        (total - completed).clamp(0, 999999);

    final rawOrderIds = data['orderIds'];
    final List<String> orderIds = (rawOrderIds is List)
        ? rawOrderIds
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : [];

    return DeliveryBatch(
      id: id,
      name: name,
      deliveryId: deliveryId,
      deliveryDate: parseDate(data['deliveryDate']),
      agentId: (data['agentId'] as String?)?.trim(),
      staffName: agentName,
      status: (data['status'] as String?)?.trim() ?? 'Pending',
      totalOrders: total,
      completedOrders: completed,
      pendingOrders: pending,
      routeId: (data['routeId'] as String?)?.trim(),
      zone: (data['zone'] as String?)?.trim() ??
          (data['corridorName'] as String?)?.trim() ??
          (data['area'] as String?)?.trim() ??
          'Standard Zone',
      orderIds: orderIds,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name.isNotEmpty ? name : deliveryId,
      'deliveryId': deliveryId,
      if (deliveryDate != null)
        'deliveryDate': Timestamp.fromDate(deliveryDate!),
      if (agentId != null) 'agentId': agentId,
      'agentName': staffName,
      'staffName': staffName,
      'status': status,
      'totalOrders': totalOrders,
      'assignedCount': totalOrders,
      'completedOrders': completedOrders,
      'completedCount': completedOrders,
      'pendingOrders': pendingOrders,
      if (routeId != null) 'routeId': routeId,
      'zone': zone,
      'orderIds': orderIds,
      if (createdAt != null)
        'createdAt': Timestamp.fromDate(createdAt!)
      else
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DeliveryBatch copyWith({
    String? id,
    String? name,
    String? deliveryId,
    DateTime? deliveryDate,
    String? agentId,
    String? staffName,
    String? status,
    int? totalOrders,
    int? completedOrders,
    int? pendingOrders,
    String? routeId,
    String? zone,
    List<String>? orderIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      agentId: agentId ?? this.agentId,
      staffName: staffName ?? this.staffName,
      status: status ?? this.status,
      totalOrders: totalOrders ?? this.totalOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      routeId: routeId ?? this.routeId,
      zone: zone ?? this.zone,
      orderIds: orderIds ?? this.orderIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an active delivery route / corridor in Cloud Firestore (`delivery_routes/{routeId}`).
class DeliveryCorridor {
  final String id;
  final String routeName;
  final String zone;
  final String riderName;
  final String? agentId;
  final int subscribersCount;
  final int completedOrders;
  final String timing;
  final String vehicleType;
  final String status;
  final List<String> orderIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeliveryCorridor({
    this.id = '',
    required this.routeName,
    required this.zone,
    required this.riderName,
    this.agentId,
    required this.subscribersCount,
    this.completedOrders = 0,
    this.timing = '05:00 AM - 07:00 AM',
    this.vehicleType = 'Delivery Vehicle',
    this.status = 'Active',
    this.orderIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Compatibility alias
  int get totalOrders => subscribersCount;

  factory DeliveryCorridor.fromFirestore(
      Map<String, dynamic> data, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final routeName = (data['routeName'] as String?)?.trim() ??
        (data['name'] as String?)?.trim() ??
        docId;

    final zone = (data['zone'] as String?)?.trim() ??
        (data['corridorName'] as String?)?.trim() ??
        (data['area'] as String?)?.trim() ??
        'Standard Zone';

    final riderName = (data['riderName'] as String?)?.trim() ??
        (data['agentName'] as String?)?.trim() ??
        'Unassigned';

    final subCount = (data['subscribersCount'] as num?)?.toInt() ??
        (data['totalOrders'] as num?)?.toInt() ??
        ((data['orderIds'] is List) ? (data['orderIds'] as List).length : 0);

    final completed = (data['completedOrders'] as num?)?.toInt() ?? 0;

    final rawOrderIds = data['orderIds'];
    final List<String> orderIds = (rawOrderIds is List)
        ? rawOrderIds
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : [];

    return DeliveryCorridor(
      id: docId,
      routeName: routeName,
      zone: zone,
      riderName: riderName,
      agentId: (data['agentId'] as String?)?.trim(),
      subscribersCount: subCount,
      completedOrders: completed,
      timing: (data['timing'] as String?)?.trim() ?? '05:00 AM - 07:00 AM',
      vehicleType: (data['vehicleType'] as String?)?.trim() ??
          (data['vehicle'] as String?)?.trim() ??
          'Delivery Vehicle',
      status: (data['status'] as String?)?.trim() ?? 'Active',
      orderIds: orderIds,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id.isNotEmpty ? id : routeName,
      'name': routeName,
      'routeName': routeName,
      'corridorName': zone,
      'area': zone,
      'zone': zone,
      if (agentId != null) 'agentId': agentId,
      'agentName': riderName,
      'riderName': riderName,
      'subscribersCount': subscribersCount,
      'totalOrders': subscribersCount,
      'completedOrders': completedOrders,
      'timing': timing,
      'vehicleType': vehicleType,
      'vehicle': vehicleType,
      'status': status,
      'orderIds': orderIds,
      if (createdAt != null)
        'createdAt': Timestamp.fromDate(createdAt!)
      else
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DeliveryCorridor copyWith({
    String? id,
    String? routeName,
    String? zone,
    String? riderName,
    String? agentId,
    int? subscribersCount,
    int? completedOrders,
    String? timing,
    String? vehicleType,
    String? status,
    List<String>? orderIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryCorridor(
      id: id ?? this.id,
      routeName: routeName ?? this.routeName,
      zone: zone ?? this.zone,
      riderName: riderName ?? this.riderName,
      agentId: agentId ?? this.agentId,
      subscribersCount: subscribersCount ?? this.subscribersCount,
      completedOrders: completedOrders ?? this.completedOrders,
      timing: timing ?? this.timing,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      orderIds: orderIds ?? this.orderIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Real-time metrics model for Today's Delivery Progress calculated from Firestore orders.
class TodaysDeliveryProgress {
  final int total;
  final int completed;
  final int pending;
  final int cancelled;
  final double completionPercentage;

  const TodaysDeliveryProgress({
    this.total = 0,
    this.completed = 0,
    this.pending = 0,
    this.cancelled = 0,
    this.completionPercentage = 0.0,
  });

  static const TodaysDeliveryProgress empty = TodaysDeliveryProgress();

  double get progressFraction =>
      total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodaysDeliveryProgress &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          completed == other.completed &&
          pending == other.pending &&
          cancelled == other.cancelled &&
          completionPercentage == other.completionPercentage;

  @override
  int get hashCode =>
      total.hashCode ^
      completed.hashCode ^
      pending.hashCode ^
      cancelled.hashCode ^
      completionPercentage.hashCode;
}
