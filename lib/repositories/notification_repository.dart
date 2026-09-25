import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/notification_item.dart';

/// Repository for reading and writing user notifications stored in Firestore
/// under the path: `users/{userId}/notifications/{notifId}`.
///
/// This path is secured by the dedicated subcollection rule in firestore.rules:
///   - Admins can read/create/update/delete any user's notifications (e.g. broadcasts).
///   - Customers can read/create/update/delete only their own notifications (isOwnDoc(userId)).
class NotificationRepository {
  final FirebaseFirestore? _customFirestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the notifications subcollection reference for a given [userId].
  CollectionReference<Map<String, dynamic>>? _notifCol(String userId) =>
      _firestore?.collection('users').doc(userId).collection('notifications');

  // ─── Read ───────────────────────────────────────────────────────────────

  /// Streams all notifications for [userId], newest first.
  /// Tolerates schema differences, logs debug metrics, and preserves document visibility.
  Stream<List<NotificationItem>> streamUserNotifications(String userId) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) {
      debugPrint('[NOTIFICATION DEBUG] currentUid is empty!');
      return Stream.value(const []);
    }

    final col = _notifCol(cleanUid);
    if (col == null) {
      return Stream.value(const []);
    }

    final firestorePath = 'users/$cleanUid/notifications';
    debugPrint('[NOTIFICATION DEBUG] currentUid=$cleanUid');
    debugPrint('[NOTIFICATION DEBUG] firestorePath=$firestorePath');

    try {
      return col.snapshots().map((snapshot) {
        debugPrint('[NOTIFICATION DEBUG] snapshotDocs=${snapshot.docs.length}');
        final items = <NotificationItem>[];
        for (final doc in snapshot.docs) {
          try {
            final item = NotificationItem.fromFirestore(doc);
            items.add(item);
          } catch (parseErr) {
            debugPrint(
                '[NOTIFICATION DEBUG] Model parsing error on doc ${doc.id}: $parseErr');
          }
        }

        // Sort in memory by timestamp descending (newest first)
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final unreadCount = items.where((n) => !n.isRead).length;
        debugPrint('[NOTIFICATION DEBUG] unreadCount=$unreadCount');
        return items;
      }).handleError((error, stackTrace) {
        debugPrint('[NOTIFICATION DEBUG] Firestore error: $error');
        throw error;
      });
    } catch (e) {
      debugPrint('[NOTIFICATION DEBUG] Firestore error: $e');
      return Stream.error(e);
    }
  }

  // ─── Mark read ──────────────────────────────────────────────────────────

  /// Marks a single notification as read in Firestore: `users/{userId}/notifications/{notifId}`.
  Future<void> markAsRead(String userId, String notifId) async {
    final cleanUid = userId.trim();
    final cleanNotifId = notifId.trim();
    if (cleanUid.isEmpty || cleanNotifId.isEmpty) {
      debugPrint(
          '[NOTIFICATION READ ERROR] Cannot mark as read with empty uid ($cleanUid) or notifId ($cleanNotifId)');
      return;
    }

    final firestorePath = 'users/$cleanUid/notifications/$cleanNotifId';
    debugPrint('[NOTIFICATION READ] uid=$cleanUid');
    debugPrint('[NOTIFICATION READ] notificationId=$cleanNotifId');
    debugPrint('[NOTIFICATION READ] path=$firestorePath');

    final col = _notifCol(cleanUid);
    if (col == null) {
      debugPrint(
          '[NOTIFICATION READ ERROR] Firestore collection reference is null for path $firestorePath');
      return;
    }

    try {
      await col.doc(cleanNotifId).update({'isRead': true});
      debugPrint('[NOTIFICATION READ] success');
    } catch (e) {
      debugPrint('[NOTIFICATION READ ERROR] $e');
      rethrow;
    }
  }

  /// Backward-compatible alias for [markAsRead].
  Future<void> markRead(String userId, String notifId) =>
      markAsRead(userId, notifId);

  /// Marks all provided notification IDs as read using a batch write.
  Future<void> markAllRead(String userId, List<String> notifIds) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty || notifIds.isEmpty) return;

    final fs = _firestore;
    final col = _notifCol(cleanUid);
    if (fs == null || col == null) return;

    final operations = notifIds.map<void Function(WriteBatch)>((id) {
      return (WriteBatch batch) {
        batch.update(col.doc(id.trim()), {'isRead': true});
      };
    }).toList();

    try {
      await _commitInChunks(operations);
      debugPrint(
          '[NOTIFICATION READ] markAllRead success for ${notifIds.length} items');
    } catch (e) {
      debugPrint('[NOTIFICATION READ ERROR] markAllRead failed: $e');
      rethrow;
    }
  }

  // ─── Dismiss ────────────────────────────────────────────────────────────

  /// Deletes a single notification document from Firestore.
  Future<void> dismiss(String userId, String notifId) async {
    final col = _notifCol(userId);
    if (col == null) return;
    await col.doc(notifId).delete();
  }

  /// Deletes all notification documents for [userId] using a batch write.
  Future<void> clearAll(String userId, List<String> notifIds) async {
    final fs = _firestore;
    final col = _notifCol(userId);
    if (fs == null || col == null || notifIds.isEmpty) return;
    final batch = fs.batch();
    for (final id in notifIds) {
      batch.delete(col.doc(id));
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
    final col = _notifCol(cleanTargetUid);
    if (cleanTargetUid.isEmpty || col == null) return;

    final docData = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type.value,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isActionable': isActionable,
      'createdBy': createdBy,
      'userId': cleanTargetUid,
      if (orderId != null && orderId.trim().isNotEmpty)
        'orderId': orderId.trim(),
      if (assignedAgentId != null && assignedAgentId.trim().isNotEmpty)
        'assignedAgentId': assignedAgentId.trim(),
      if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
      if (metadata != null) 'metadata': metadata,
    };

    await col.add(docData);

    // If sent by an admin to a customer/agent, track in admin's own notification history as read
    if (trackInAdminHistory &&
        createdBy.isNotEmpty &&
        createdBy != cleanTargetUid) {
      try {
        await _notifCol(createdBy)?.add({
          ...docData,
          'isRead': true,
          'isSentHistory': true,
        });
      } catch (_) {}
    }
  }

  /// Fetches all UIDs from the `users` top-level collection.
  Future<List<String>> fetchAllUserIds() async {
    final fs = _firestore;
    if (fs == null) return [];
    try {
      final snapshot = await fs.collection('users').get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches UIDs of all admin users (`role in ['admin', 'owner', 'superadmin']`).
  Future<List<String>> fetchAdminUserIds() async {
    final fs = _firestore;
    if (fs == null) return [];
    try {
      debugPrint('[ADMIN NOTIFY] Looking up admins');
      final uids = <String>{};

      // 1. Primary query: users where role in ['admin', 'owner', 'superadmin']
      try {
        final snapshot = await fs.collection('users').where('role', whereIn: [
          'admin',
          'Admin',
          'ADMIN',
          'owner',
          'Owner',
          'superadmin',
          'Superadmin'
        ]).get();
        for (final d in snapshot.docs) {
          uids.add(d.id);
        }
      } catch (e) {
        debugPrint('[ADMIN NOTIFY ERROR] users role query failed: $e');
      }

      // 2. Fallback query: users where isAdmin == true (if present)
      try {
        final isAdminSnap = await fs
            .collection('users')
            .where('isAdmin', isEqualTo: true)
            .get();
        for (final d in isAdminSnap.docs) {
          if (d.id.trim().isNotEmpty) {
            uids.add(d.id.trim());
          }
        }
      } catch (_) {}

      debugPrint('[ADMIN NOTIFY] admin count=${uids.length}');
      return uids.toList();
    } catch (e) {
      debugPrint('[ADMIN NOTIFY ERROR] $e');
      return [];
    }
  }

  /// Dispatches an event-driven notification to all active Admin users.
  /// Used for Customer complaints, support tickets, delivery exceptions, etc.
  ///
  /// Dynamically queries all admin users (roles: admin, owner, superadmin)
  /// and writes a notification document to `users/{adminUid}/notifications/{notificationId}`.
  /// Starts with `isRead: false`.
  /// Never hardcodes admin UIDs.
  Future<void> sendNotificationToAdmins({
    required String title,
    required String body,
    required NotificationType type,
    String? orderId,
    String? assignedAgentId,
    String? route,
    bool isActionable = false,
    Map<String, dynamic>? metadata,
    String? senderUid,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      debugPrint('[ADMIN NOTIFY ERROR] Firestore is not initialized');
      return;
    }

    final adminUids = await fetchAdminUserIds();
    if (adminUids.isEmpty) {
      debugPrint('[ADMIN NOTIFY] admin count=0 (no admins found)');
      return;
    }

    final effectiveSender =
        (senderUid != null && senderUid.isNotEmpty) ? senderUid : 'system';

    for (final adminUid in adminUids) {
      final col = _notifCol(adminUid);
      if (col == null) {
        debugPrint(
            '[ADMIN NOTIFY ERROR] collection ref null for admin uid=$adminUid');
        continue;
      }
      final docRef = col.doc();
      final path = 'users/$adminUid/notifications/${docRef.id}';
      debugPrint('[ADMIN NOTIFY] admin uid=$adminUid');
      debugPrint('[ADMIN NOTIFY] writing notification');
      debugPrint('[ADMIN NOTIFY] path=$path');

      try {
        await docRef.set({
          'title': title,
          'body': body,
          'type': type.value,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'isActionable': isActionable,
          'createdBy': effectiveSender,
          'userId': adminUid,
          if (orderId != null && orderId.trim().isNotEmpty)
            'orderId': orderId.trim(),
          if (assignedAgentId != null && assignedAgentId.trim().isNotEmpty)
            'assignedAgentId': assignedAgentId.trim(),
          if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
          if (metadata != null) 'metadata': metadata,
        });
        debugPrint('[ADMIN NOTIFY] SUCCESS');
      } catch (e) {
        debugPrint('[ADMIN NOTIFY ERROR] $e');
        rethrow;
      }
    }
  }

  /// Fetches UIDs of all delivery agents (`role == 'delivery'`).
  Future<List<String>> fetchDeliveryAgentUserIds() async {
    final fs = _firestore;
    if (fs == null) return [];
    try {
      final snapshot = await fs
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
    final fs = _firestore;
    if (fs == null) return [];
    try {
      final snapshot = await fs
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
    final fs = _firestore;
    if (fs == null) return [];
    final activeUids = <String>{};
    try {
      // 1. Try checking collectionGroup or querying users
      final userSnap = await fs.collection('users').get();
      for (final userDoc in userSnap.docs) {
        final uid = userDoc.id;
        try {
          final subDoc = await fs
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
    final fs = _firestore;
    if (fs == null) return;
    const chunkSize = 500;
    for (int i = 0; i < operations.length; i += chunkSize) {
      final batch = fs.batch();
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
    final fs = _firestore;
    if (fs == null) return;

    final List<String> recipients;
    if (targetUserIds.isNotEmpty) {
      recipients = {...targetUserIds, adminUid}.toList();
    } else {
      final allUserIds = await fetchAllUserIds();
      recipients = {...allUserIds, adminUid}.toList();
    }

    final operations = recipients.map<void Function(WriteBatch)>((uid) {
      return (WriteBatch batch) {
        final col = _notifCol(uid);
        if (col == null) return;
        final ref = col.doc();
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
          if (orderId != null && orderId.trim().isNotEmpty)
            'orderId': orderId.trim(),
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
