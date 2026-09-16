import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_item.dart';

/// Repository for reading and writing user notifications stored in Firestore
/// under the path: `users/{userId}/notifications/{notifId}`.
///
/// This path is secured by the dedicated subcollection rule in firestore.rules:
///   - Admins can read/create/update/delete any user's notifications (e.g. broadcasts).
///   - Customers can read/create/update/delete only their own notifications (isOwnDoc(userId)).
class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns the notifications subcollection reference for a given [userId].
  CollectionReference<Map<String, dynamic>> _notifCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  // ─── Read ───────────────────────────────────────────────────────────────

  /// Streams all notifications for [userId], newest first.
  Stream<List<NotificationItem>> streamUserNotifications(String userId) {
    return _notifCol(userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(NotificationItem.fromFirestore).toList());
  }

  // ─── Mark read ──────────────────────────────────────────────────────────

  /// Marks a single notification as read.
  Future<void> markRead(String userId, String notifId) async {
    await _notifCol(userId).doc(notifId).update({'isRead': true});
  }

  /// Marks all provided notification IDs as read using a batch write.
  Future<void> markAllRead(String userId, List<String> notifIds) async {
    if (notifIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in notifIds) {
      batch.update(_notifCol(userId).doc(id), {'isRead': true});
    }
    await batch.commit();
  }

  // ─── Dismiss ────────────────────────────────────────────────────────────

  /// Deletes a single notification document from Firestore.
  Future<void> dismiss(String userId, String notifId) async {
    await _notifCol(userId).doc(notifId).delete();
  }

  /// Deletes all notification documents for [userId] using a batch write.
  Future<void> clearAll(String userId, List<String> notifIds) async {
    if (notifIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in notifIds) {
      batch.delete(_notifCol(userId).doc(id));
    }
    await batch.commit();
  }

  // ─── Write (Targeted & Admin) ──────────────────────────────────────────

  /// Writes a notification document directly to [targetUserId]'s subcollection.
  /// [createdBy] is the admin's or system's uid for audit trail.
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    required NotificationType type,
    required String createdBy,
    String? orderId,
    String? assignedAgentId,
    String? route,
    bool isActionable = false,
    Map<String, dynamic>? metadata,
    bool trackInAdminHistory = true,
  }) async {
    final cleanTargetUid = targetUserId.trim();
    if (cleanTargetUid.isEmpty) return;

    final docData = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type.value,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isActionable': isActionable,
      'createdBy': createdBy,
      'userId': cleanTargetUid,
      if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
      if (assignedAgentId != null && assignedAgentId.trim().isNotEmpty)
        'assignedAgentId': assignedAgentId.trim(),
      if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
      if (metadata != null) 'metadata': metadata,
    };

    await _notifCol(cleanTargetUid).add(docData);

    // If sent by an admin to a customer/agent, track in admin's own notification history as read
    if (trackInAdminHistory && createdBy.isNotEmpty && createdBy != cleanTargetUid) {
      try {
        await _notifCol(createdBy).add({
          ...docData,
          'isRead': true,
          'isSentHistory': true,
        });
      } catch (_) {}
    }
  }

  /// Fetches all UIDs from the `users` top-level collection.
  Future<List<String>> fetchAllUserIds() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches UIDs of all delivery agents (`role == 'delivery'`).
  Future<List<String>> fetchDeliveryAgentUserIds() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches UIDs of standard customers (`role == 'customer'`).
  Future<List<String>> fetchCustomerUserIds() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches UIDs of users with active subscriptions.
  Future<List<String>> fetchActiveSubscriberUserIds() async {
    final activeUids = <String>{};
    try {
      // 1. Try checking collectionGroup or querying users
      final userSnap = await _firestore.collection('users').get();
      for (final userDoc in userSnap.docs) {
        final uid = userDoc.id;
        try {
          final subDoc = await _firestore
              .collection('users')
              .doc(uid)
              .collection('subscription')
              .doc('current')
              .get();
          if (subDoc.exists) {
            final data = subDoc.data();
            final status = (data?['status'] as String?)?.toLowerCase();
            if (status == 'active') {
              activeUids.add(uid);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return activeUids.toList();
  }

  /// Commits a list of batch operations, splitting into chunks of 500
  /// to stay within Firestore's per-batch limit.
  Future<void> _commitInChunks(
      List<void Function(WriteBatch)> operations) async {
    const chunkSize = 500;
    for (int i = 0; i < operations.length; i += chunkSize) {
      final batch = _firestore.batch();
      final chunk = operations.sublist(
        i,
        (i + chunkSize) < operations.length
            ? (i + chunkSize)
            : operations.length,
      );
      for (final op in chunk) {
        op(batch);
      }
      await batch.commit();
    }
  }

  /// Sends a broadcast notification to the resolved recipient list.
  ///
  /// When [targetUserIds] is empty, defaults to all users in Firestore.
  /// The admin's own copy is marked `isRead: true` so it shows as sent-history.
  Future<void> sendBroadcast({
    required String adminUid,
    required String title,
    required String body,
    required NotificationType type,
    List<String> targetUserIds = const [],
    String? orderId,
    String? assignedAgentId,
    String? route,
    bool isActionable = false,
    Map<String, dynamic>? metadata,
  }) async {
    final List<String> recipients;
    if (targetUserIds.isNotEmpty) {
      recipients = {...targetUserIds, adminUid}.toList();
    } else {
      final allUserIds = await fetchAllUserIds();
      recipients = {...allUserIds, adminUid}.toList();
    }

    final operations = recipients.map<void Function(WriteBatch)>((uid) {
      return (WriteBatch batch) {
        final ref = _notifCol(uid).doc();
        batch.set(ref, {
          'title': title,
          'body': body,
          'type': type.value,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': uid == adminUid,
          'isActionable': isActionable,
          'createdBy': adminUid,
          'userId': uid,
          'isBroadcast': true,
          if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
          if (assignedAgentId != null && assignedAgentId.trim().isNotEmpty)
            'assignedAgentId': assignedAgentId.trim(),
          if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
          if (metadata != null) 'metadata': metadata,
        });
      };
    }).toList();

    await _commitInChunks(operations);
  }
}
