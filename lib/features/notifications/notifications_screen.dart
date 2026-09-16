import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../models/notification_item.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../orders/order_details_screen.dart';

/// Sawariya Dairy — Notifications Screen (Task 11: Firestore-backed)
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    return DateFormat.MMMd().format(timestamp);
  }

  void _openNotification(
      BuildContext context, WidgetRef ref, NotificationItem item) {
    // Mark read in Firestore
    final userId = ref.read(currentUserIdProvider);
    if (userId != null && userId.isNotEmpty) {
      ref
          .read(notificationRepositoryProvider)
          .markRead(userId, item.id)
          .catchError((_) {});
    }

    final rawOrderId = item.orderId?.trim();
    if (rawOrderId != null && rawOrderId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsRouteScreen(orderId: rawOrderId),
        ),
      );
      return;
    }

    final explicitRoute = item.route?.trim();
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      try {
        context.push(explicitRoute);
        return;
      } catch (_) {}
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(item.title)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(userNotificationsStreamProvider);
    final userId = ref.watch(currentUserIdProvider);
    final repo = ref.read(notificationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: asyncNotifications.whenOrNull(
              data: (notifications) => [
                if (notifications.any((n) => !n.isRead) && userId != null)
                  TextButton.icon(
                    onPressed: () {
                      final unreadIds = notifications
                          .where((n) => !n.isRead)
                          .map((n) => n.id)
                          .toList();
                      repo.markAllRead(userId, unreadIds).catchError((_) {});
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (notifications.isNotEmpty && userId != null)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    tooltip: 'Clear all',
                    onPressed: () {
                      final allIds = notifications.map((n) => n.id).toList();
                      repo.clearAll(userId, allIds).catchError((_) {});
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ) ??
            const [],
      ),
      body: asyncNotifications.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryBlue,
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSizes.p16),
                const Text(
                  'Could not load notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(userNotificationsStreamProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(context, ref);
          }
          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHorizontalPadding,
              vertical: AppSizes.p16,
            ),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p12),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return _NotificationTile(
                item: item,
                timeAgo: _timeAgo(item.timestamp),
                onTap: () => _openNotification(context, ref, item),
                onDismiss: (ctx) {
                  if (userId != null) {
                    repo.dismiss(userId, item.id).catchError((_) {});
                  }
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Notification dismissed')),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 50,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            const Text(
              'No Notifications Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'We will notify you about your order status, delivery updates and special offers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(navigationProvider.notifier).setIndex(0);
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: const Icon(Icons.home_rounded),
                label: const Text(
                  'Back to Home',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSizes.borderMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final String timeAgo;
  final VoidCallback onTap;
  final void Function(BuildContext)? onDismiss;

  const _NotificationTile({
    required this.item,
    required this.timeAgo,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = _iconColor(item.type);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: const BoxDecoration(
          color: AppColors.error,
          borderRadius: AppSizes.borderLarge,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) {
        if (onDismiss != null) onDismiss!(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSizes.borderLarge,
          border: Border.all(
            color: item.isRead
                ? AppColors.border
                : AppColors.primaryBlue.withValues(alpha: 0.3),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppSizes.borderLarge,
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p14,
              vertical: AppSizes.p12,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.type.icon, size: 22, color: iconColor),
            ),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          item.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.orderId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order #${item.orderId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (item.isActionable) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: AppSizes.borderSmall,
                      ),
                      child: const Text(
                        'Tap to view',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _iconColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF0284C7);
      case NotificationType.delivery:
        return AppColors.primaryBlue;
      case NotificationType.promotional:
        return const Color(0xFFF59E0B);
      case NotificationType.subscription:
        return const Color(0xFF7C3AED);
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }
}
