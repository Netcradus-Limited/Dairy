import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/notification_item.dart';
import '../providers/admin_provider.dart';
import '../providers/notification_provider.dart';

/// Interactive dropdown overlay and bottom-sheet menu for the Admin Notification Center.
/// Displays live Firestore notifications, unread badges, mark-as-read actions,
/// and contextual navigation for dairy operations.
class AdminNotificationDropdown extends ConsumerWidget {
  final VoidCallback? onClose;
  final void Function(int navIndex)? onNavigate;

  const AdminNotificationDropdown({
    super.key,
    this.onClose,
    this.onNavigate,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminProvider provider,
    bool isMobile = false,
  }) async {
    if (isMobile) {
      final cardBg = AppColors.cardBgOf(context);
      await showModalBottomSheet(
        context: context,
        backgroundColor: cardBg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AdminNotificationDropdown(
              onClose: () => Navigator.of(ctx).pop(),
              onNavigate: (index) {
                Navigator.of(ctx).pop();
                provider.setNavIndex(index);
              },
            ),
          ),
        ),
      );
    } else {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.15),
        barrierDismissible: true,
        builder: (ctx) => Stack(
          children: [
            Positioned(
              top: 75,
              right: 28,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: AppColors.cardBgOf(ctx),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorderOf(ctx)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AdminNotificationDropdown(
                    onClose: () => Navigator.of(ctx).pop(),
                    onNavigate: (index) {
                      Navigator.of(ctx).pop();
                      provider.setNavIndex(index);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  static Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF0284C7);
      case NotificationType.delivery:
        return AppColors.primary;
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

  static String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    return DateFormat('dd MMM, hh:mm a').format(ts);
  }

  int _resolveNavIndexForNotification(NotificationItem notif) {
    // Contextual routing based on notification type and payload
    switch (notif.type) {
      case NotificationType.order:
        return 5; // Orders screen
      case NotificationType.customer:
        return 1; // Customers screen
      case NotificationType.subscription:
        return 2; // Subscriptions screen
      case NotificationType.delivery:
        return 6; // Delivery Management screen
      case NotificationType.payment:
        return 8; // Payments screen
      case NotificationType.support:
        return 10; // Support / Complaints screen
      case NotificationType.promotional:
      case NotificationType.system:
        return 9; // Notifications screen
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final effectiveUid = ref.watch(effectiveUserIdProvider);
    final notificationsAsync = ref.watch(userNotificationsStreamProvider);

    return Container(
      color: cardBg,
      constraints: const BoxConstraints(maxHeight: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                notificationsAsync.whenOrNull(
                      data: (list) {
                        final unread = list.where((n) => !n.isRead).length;
                        if (unread == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread new',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final list = notificationsAsync.value ?? [];
                    final unreadIds =
                        list.where((n) => !n.isRead).map((n) => n.id).toList();
                    if (unreadIds.isNotEmpty && effectiveUid.isNotEmpty) {
                      try {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markAllRead(effectiveUid, unreadIds);
                      } catch (e) {
                        debugPrint(
                            '[NOTIFICATION READ ERROR] Dropdown markAllRead failed: $e');
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Mark all as read',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: cardBorder),

          // ── Notification Items Stream List ──
          Flexible(
            child: effectiveUid.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_circle_outlined,
                              size: 36, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          Text(
                            'No active session found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : notificationsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 28, color: AppColors.error),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load notifications: $err',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => ref
                                  .invalidate(userNotificationsStreamProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 36),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 28,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No notifications yet',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You\'re all caught up with your dairy alerts.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, thickness: 0.5, color: cardBorder),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          final typeColor = _getTypeColor(notif.type);
                          final isUnread = !notif.isRead;

                          return Material(
                            color: isUnread
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                if (isUnread && effectiveUid.isNotEmpty) {
                                  try {
                                    await ref
                                        .read(notificationRepositoryProvider)
                                        .markAsRead(effectiveUid, notif.id);
                                  } catch (e) {
                                    debugPrint(
                                        '[NOTIFICATION READ ERROR] Dropdown markAsRead failed: $e');
                                  }
                                }

                                if (notif.isActionable) {
                                  final targetIndex =
                                      _resolveNavIndexForNotification(notif);
                                  if (onNavigate != null) {
                                    onNavigate!(targetIndex);
                                  } else if (onClose != null) {
                                    onClose!();
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Type Icon
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            typeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        notif.type.icon,
                                        size: 18,
                                        color: typeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: isUnread
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                    color: textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isUnread) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            notif.body,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: textSecondary,
                                              height: 1.35,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 11,
                                                color: textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatTimestamp(
                                                    notif.timestamp),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  color: textSecondary,
                                                ),
                                              ),
                                              if (notif.orderId != null &&
                                                  notif
                                                      .orderId!.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(
                                                            alpha: 0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    '#${notif.orderId}',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // ── Footer: View All Notifications ──
          Divider(height: 1, thickness: 1, color: cardBorder),
          InkWell(
            onTap: () {
              if (onNavigate != null) {
                onNavigate!(9); // Nav index 9 is Notifications
              } else if (onClose != null) {
                onClose!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View All Notifications',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
