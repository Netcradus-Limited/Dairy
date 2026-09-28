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
import '../../providers/product_provider.dart';
import '../orders/order_details_screen.dart';
import '../profile/customer_support_screen.dart';
import '../subscription/subscriptions_screen.dart';

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

  Future<void> _openNotification(
      BuildContext context, WidgetRef ref, NotificationItem item) async {
    // 1. Mark read in Firestore if unread
    final userId = ref.read(effectiveUserIdProvider);
    if (!item.isRead && userId.isNotEmpty) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .markAsRead(userId, item.id);
      } catch (e) {
        debugPrint(
            '[NOTIFICATION READ ERROR] CustomerScreen markAsRead failed: $e');
      }
    }

    if (!context.mounted) return;

    // 2. Navigate to Order Details if orderId is present
    final rawOrderId = item.orderId?.trim();
    if (rawOrderId != null && rawOrderId.isNotEmpty) {
      final cleanOrderId = rawOrderId.replaceAll(RegExp(r'^#+'), '').trim();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailsRouteScreen(orderId: cleanOrderId),
        ),
      );
      return;
    }

    // 3. Handle Promotional notification / Ghee / Product offers -> Navigate straight to Shop with category filtered
    if (item.type == NotificationType.promotional ||
        (item.route != null && item.route!.trim() == '/shop') ||
        item.title.toLowerCase().contains('offer') ||
        item.title.toLowerCase().contains('ghee') ||
        item.body.toLowerCase().contains('ghee')) {
      final text = '${item.title} ${item.body}'.toLowerCase();
      if (text.contains('ghee')) {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_ghee';
      } else if (text.contains('milk') || text.contains('a2')) {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_milk';
      } else if (text.contains('paneer')) {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_paneer';
      } else if (text.contains('lassi') ||
          text.contains('curd') ||
          text.contains('dahi')) {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_lassi';
      } else if (text.contains('butter') || text.contains('makhan')) {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_makhan';
      } else {
        ref.read(selectedCategoryProvider.notifier).state = 'cat_all';
      }
      ref.read(productSearchQueryProvider.notifier).state = '';
      ref.read(navigationProvider.notifier).setIndex(1); // 1 = Shop catalog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/shop');
      }
      return;
    }

    // 4. Navigate if explicit custom route is specified and is NOT /notifications
    final explicitRoute = item.route?.trim();
    if (explicitRoute != null &&
        explicitRoute.isNotEmpty &&
        explicitRoute != '/notifications') {
      try {
        if (explicitRoute == '/shop') {
          ref.read(navigationProvider.notifier).setIndex(1);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/shop');
          }
          return;
        } else if (explicitRoute == '/home') {
          ref.read(navigationProvider.notifier).setIndex(0);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/home');
          }
          return;
        } else if (explicitRoute == '/orders') {
          ref.read(navigationProvider.notifier).setIndex(2);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/orders');
          }
          return;
        } else if (explicitRoute == '/profile') {
          ref.read(navigationProvider.notifier).setIndex(3);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/profile');
          }
          return;
        } else if (explicitRoute == '/subscriptions') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
          );
          return;
        } else if (explicitRoute == '/support') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerSupportScreen()),
          );
          return;
        }
        context.push(explicitRoute);
        return;
      } catch (_) {}
    }

    // 5. Handle Subscription notification
    if (item.type == NotificationType.subscription) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
      );
      return;
    }

    // 6. Handle Support notification
    if (item.type == NotificationType.support) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSupportScreen()),
      );
      return;
    }

    // 7. Show interactive details dialog for system and general alerts
    _showNotificationDetailsModal(context, ref, item);
  }

  void _showNotificationDetailsModal(
      BuildContext context, WidgetRef ref, NotificationItem item) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _NotificationDetailDialog(item: item),
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
      case NotificationType.customer:
        return const Color(0xFF10B981);
      case NotificationType.payment:
        return const Color(0xFF059669);
      case NotificationType.support:
        return const Color(0xFFE11D48);
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }
}

/// Rich interactive details dialog for customer notifications
class _NotificationDetailDialog extends ConsumerWidget {
  final NotificationItem item;

  const _NotificationDetailDialog({required this.item});

  String _formatFullDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Color _badgeColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF0284C7);
      case NotificationType.delivery:
        return AppColors.primaryBlue;
      case NotificationType.promotional:
        return const Color(0xFFF59E0B);
      case NotificationType.subscription:
        return const Color(0xFF7C3AED);
      case NotificationType.customer:
        return const Color(0xFF10B981);
      case NotificationType.payment:
        return const Color(0xFF059669);
      case NotificationType.support:
        return const Color(0xFFE11D48);
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }

  String _badgeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return 'Order Update';
      case NotificationType.delivery:
        return 'Delivery Status';
      case NotificationType.promotional:
        return 'Special Offer';
      case NotificationType.subscription:
        return 'Subscription';
      case NotificationType.customer:
        return 'Account Update';
      case NotificationType.payment:
        return 'Payment Update';
      case NotificationType.support:
        return 'Support Alert';
      case NotificationType.system:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _badgeColor(item.type);
    final label = _badgeLabel(item.type);
    final isPromotional = item.type == NotificationType.promotional;
    final isOrder = item.type == NotificationType.order ||
        (item.orderId != null && item.orderId!.trim().isNotEmpty);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: AppColors.surface,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type Icon + Category Badge + Timestamp
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.type.icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatFullDate(item.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 20),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),

              // Notification Title
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // Notification Body Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  item.body.isNotEmpty ? item.body : 'No additional details.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),

              // Order ID Chip if present
              if (item.orderId != null && item.orderId!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Order #${item.orderId}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                  if (isPromotional) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        final text = '${item.title} ${item.body}'.toLowerCase();
                        if (text.contains('ghee')) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_ghee';
                        } else if (text.contains('milk') || text.contains('a2')) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_milk';
                        } else if (text.contains('paneer')) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_paneer';
                        } else if (text.contains('lassi') ||
                            text.contains('curd') ||
                            text.contains('dahi')) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_lassi';
                        } else if (text.contains('butter') ||
                            text.contains('makhan')) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_makhan';
                        } else {
                          ref.read(selectedCategoryProvider.notifier).state =
                              'cat_all';
                        }
                        ref.read(productSearchQueryProvider.notifier).state = '';
                        Navigator.of(context).pop();
                        ref.read(navigationProvider.notifier).setIndex(1);
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/shop');
                        }
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text('Explore Shop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ] else if (isOrder &&
                      item.orderId != null &&
                      item.orderId!.trim().isNotEmpty) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        final cleanOrderId = item.orderId!
                            .replaceAll(RegExp(r'^#+'), '')
                            .trim();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailsRouteScreen(orderId: cleanOrderId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('View Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
