import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Notification type for Sawariya Dairy
enum NotificationType {
  order,
  delivery,
  promotional,
  subscription,
  system,
}

extension NotificationTypeExtension on NotificationType {
  IconData get icon {
    switch (this) {
      case NotificationType.order:
        return Icons.receipt_long_rounded;
      case NotificationType.delivery:
        return Icons.local_shipping_outlined;
      case NotificationType.promotional:
        return Icons.local_offer_outlined;
      case NotificationType.subscription:
        return Icons.subscriptions_outlined;
      case NotificationType.system:
        return Icons.info_outline_rounded;
    }
  }

  String get value {
    switch (this) {
      case NotificationType.order:
        return 'order';
      case NotificationType.delivery:
        return 'delivery';
      case NotificationType.promotional:
        return 'promotional';
      case NotificationType.subscription:
        return 'subscription';
      case NotificationType.system:
        return 'system';
    }
  }

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'order':
        return NotificationType.order;
      case 'delivery':
        return NotificationType.delivery;
      case 'promotional':
        return NotificationType.promotional;
      case 'subscription':
        return NotificationType.subscription;
      default:
        return NotificationType.system;
    }
  }
}

/// Notification Model for Sawariya Dairy (Task 11 — Firestore-backed)
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? orderId;
  final String? assignedAgentId;
  final String? route;
  final bool isRead;
  final bool isActionable;

  /// Optional: uid of admin who created this notification (for broadcasts)
  final String? createdBy;

  /// Optional: recipient uid (stored on document for filtering)
  final String? userId;

  /// Optional: additional arbitrary metadata
  final Map<String, dynamic>? metadata;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.orderId,
    this.assignedAgentId,
    this.route,
    this.isRead = false,
    this.isActionable = false,
    this.createdBy,
    this.userId,
    this.metadata,
  });

  /// Deserialize from a map and ID.
  factory NotificationItem.fromMap(Map<String, dynamic> data, String id) {
    final ts = data['timestamp'];
    final DateTime parsedTime;
    if (ts is Timestamp) {
      parsedTime = ts.toDate();
    } else if (ts is DateTime) {
      parsedTime = ts;
    } else if (ts is String) {
      parsedTime = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }
    return NotificationItem(
      id: id,
      type: NotificationTypeExtension.fromString(data['type'] as String?),
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? (data['message'] as String?) ?? '',
      timestamp: parsedTime,
      orderId: (data['orderId'] ?? data['order_id']) as String?,
      assignedAgentId: (data['assignedAgentId'] ?? data['assigned_agent_id']) as String?,
      route: data['route'] as String?,
      isRead: (data['isRead'] as bool?) ?? false,
      isActionable: (data['isActionable'] as bool?) ?? false,
      createdBy: data['createdBy'] as String?,
      userId: data['userId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Deserialize from a Firestore [DocumentSnapshot].
  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationItem.fromMap(data, doc.id);
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      if (orderId != null) 'orderId': orderId,
      if (assignedAgentId != null) 'assignedAgentId': assignedAgentId,
      if (route != null) 'route': route,
      'isRead': isRead,
      'isActionable': isActionable,
      if (createdBy != null) 'createdBy': createdBy,
      if (userId != null) 'userId': userId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    DateTime? timestamp,
    String? orderId,
    String? assignedAgentId,
    String? route,
    bool? isRead,
    bool? isActionable,
    String? createdBy,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      orderId: orderId ?? this.orderId,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      route: route ?? this.route,
      isRead: isRead ?? this.isRead,
      isActionable: isActionable ?? this.isActionable,
      createdBy: createdBy ?? this.createdBy,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
    );
  }
}
