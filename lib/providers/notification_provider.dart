import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';
import 'user_provider.dart';

// ─── Repository provider ────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

// ─── Firestore-backed stream provider (real data) ──────────────────────────

/// Streams all notifications for the currently authenticated user from Firestore.
/// Uses the `users/{uid}/notifications` subcollection (rules-compliant).

final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationItem>>((ref) {
  final user = ref.watch(userProvider);
  final authUid = FirebaseAuth.instance.currentUser?.uid;
  final effectiveUid =
      (authUid != null && authUid.isNotEmpty) ? authUid : user.id;

  debugPrint('[NOTIF DEBUG] 1. FirebaseAuth.currentUser.uid: $authUid');
  debugPrint('[NOTIF DEBUG] 2. userProvider.id: ${user.id}');
  debugPrint('[NOTIF DEBUG] 3. effectiveUid used: $effectiveUid');
  debugPrint(
      '[NOTIF DEBUG] 4. Exact Firestore collection path being queried: users/$effectiveUid/notifications');

  if (effectiveUid.isEmpty) {
    debugPrint(
        '[NOTIF DEBUG] effectiveUid is empty (guest user), returning empty stream');
    return const Stream.empty();
  }
  return ref
      .watch(notificationRepositoryProvider)
      .streamUserNotifications(effectiveUid);
});

/// Streams notifications for a specific [userId] — used by admin panel.
final notificationsForUserStreamProvider =
    StreamProvider.autoDispose.family<List<NotificationItem>, String>(
  (ref, userId) {
    if (userId.isEmpty) return const Stream.empty();
    return ref
        .watch(notificationRepositoryProvider)
        .streamUserNotifications(userId);
  },
);

// ─── Derived convenience providers (Firestore-backed) ──────────────────────

/// Unread notifications count for the current user from Firestore.
final firestoreUnreadCountProvider = Provider.autoDispose<AsyncValue<int>>(
  (ref) => ref.watch(userNotificationsStreamProvider).whenData(
        (list) => list.where((n) => !n.isRead).length,
      ),
);

// ─── Legacy mock notifier (kept for offline/widget test fallback) ──────────
// NOTE: The mock seed data is only used when Firestore is unavailable.
// The customer NotificationsScreen now uses [userNotificationsStreamProvider].

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier() : super(const []);

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void markRead(String id) {
    state =
        state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  (ref) => NotificationsNotifier(),
);

/// Convenience providers using real Firestore stream (replaced legacy mock list).
/// The customer NotificationsScreen now uses [userNotificationsStreamProvider].
final unreadNotificationsProvider = Provider<List<NotificationItem>>((ref) {
  return ref.watch(userNotificationsStreamProvider).value?.where((n) => !n.isRead).toList() ?? [];
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(unreadNotificationsProvider).length;
});
