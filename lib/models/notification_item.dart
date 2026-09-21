import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Notification type for Sawariya Dairy
enum NotificationType {
  order,
  delivery,
  promotional,
  subscription,
  system,
  customer,
  payment,
  support,
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
        return Icons.calendar_month_rounded;
      case NotificationType.system:
        return Icons.info_outline_rounded;
      case NotificationType.customer:
        return Icons.person_outline_rounded;
      case NotificationType.payment:
        return Icons.credit_card_rounded;
      case NotificationType.support:
        return Icons.support_agent_rounded;
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
      case NotificationType.customer:
        return 'customer';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.support:
        return 'support';
    }
  }

  static NotificationType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'order':
      case 'orders':
        return NotificationType.order;
      case 'delivery':
      case 'deliveries':
      case 'dispatch':
        return NotificationType.delivery;
      case 'promotional':
      case 'promotion':
      case 'promo':
      case 'offer':
      case 'marketing':
        return NotificationType.promotional;
      case 'subscription':
      case 'subscriptions':
        return NotificationType.subscription;
      case 'customer':
      case 'user':
      case 'account':
      case 'profile':
        return NotificationType.customer;
      case 'payment':
      case 'payments':
      case 'invoice':
      case 'billing':
        return NotificationType.payment;
      case 'support':
      case 'complaint':
      case 'ticket':
      case 'help':
        return NotificationType.support;
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

  /// Deserialize from a map and ID, tolerating variations in field naming and types.
  factory NotificationItem.fromMap(Map<String, dynamic> data, String id) {
    final rawTs = data['timestamp'] ??
        data['createdAt'] ??
        data['created_at'] ??
        data['date'] ??
        data['time'] ??
        data['updatedAt'];

    final DateTime parsedTime;
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is DateTime) {
      parsedTime = rawTs;
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      parsedTime = rawTs > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(rawTs)
          : DateTime.fromMillisecondsSinceEpoch(rawTs * 1000);
    } else {
      parsedTime = DateTime.now();
    }

    final rawType = (data['type'] ?? data['notificationType'] ?? data['category']) as String?;
    final title = (data['title'] ?? data['subject'] ?? data['heading'] ?? '') as String;
    final body = (data['body'] ??
        data['message'] ??
        data['description'] ??
        data['text'] ??
        data['content'] ??
        '') as String;

    final rawIsRead = data['isRead'] ?? data['read'] ?? data['is_read'] ?? data['seen'];
    final isRead = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead is String ? rawIsRead.toLowerCase() == 'true' : false);

    final rawActionable = data['isActionable'] ?? data['actionable'] ?? data['is_actionable'];
    final isActionable = rawActionable is bool
        ? rawActionable
        : (rawActionable is String ? rawActionable.toLowerCase() == 'true' : false);

    final orderId = (data['orderId'] ?? data['order_id'] ?? data['orderID'])?.toString();
    final assignedAgentId = (data['assignedAgentId'] ??
            data['assigned_agent_id'] ??
            data['agentId'] ??
            data['agent_id'])
        ?.toString();
    final route = (data['route'] ?? data['targetRoute'] ?? data['path'])?.toString();
    final createdBy = (data['createdBy'] ?? data['created_by'] ?? data['adminId'] ?? data['senderId'])?.toString();
    final userId = (data['userId'] ?? data['uid'] ?? data['user_id'] ?? data['recipientId'])?.toString();
    final metadata = data['metadata'] as Map<String, dynamic>?;

    return NotificationItem(
      id: id,
      type: NotificationTypeExtension.fromString(rawType),
      title: title,
      body: body,
      timestamp: parsedTime,
      orderId: orderId,
      assignedAgentId: assignedAgentId,
      route: route,
      isRead: isRead,
      isActionable: isActionable,
      createdBy: createdBy,
      userId: userId,
      metadata: metadata,
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
