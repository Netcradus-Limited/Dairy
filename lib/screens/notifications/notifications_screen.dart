import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/notification_item.dart';
import '../../models/order.dart' as order_model;
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/order_service.dart';

/// Admin Notifications Screen — Role-Aware Broadcasts, Targeted Alerts & History
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  NotificationType _selectedType = NotificationType.promotional;
  bool _isSending = false;

  // Contextual state
  String? _selectedOrderId;
  String _deliveryTarget = 'orderCustomer'; // orderCustomer, assignedDriver, both, allFleet
  String _audienceFilter = 'allUsers'; // allUsers, customersOnly, activeSubscribers, deliveryFleet

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(String title, String body) {
    setState(() {
      _titleController.text = title;
      _bodyController.text = body;
    });
  }

  List<({String label, String title, String body})> _getTemplatesForType(
      NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return [
          (
            label: 'Confirmed',
            title: 'Order Confirmed 🥛',
            body:
                'Your fresh milk order has been confirmed and is being packed in our cold-chain facility.'
          ),
          (
            label: 'Out for Delivery',
            title: 'Order Out for Delivery 🚚',
            body:
                'Our delivery rider is on the way to your address with your dairy order.'
          ),
          (
            label: 'Delivered',
            title: 'Order Delivered 🎉',
            body:
                'Your fresh dairy products have been delivered safely. Enjoy your pure dairy!'
          ),
          (
            label: 'Delayed',
            title: 'Delivery Update ⏳',
            body:
                'Your order is running a few minutes behind schedule due to route traffic. We apologize for the wait.'
          ),
          (
            label: 'Cancelled',
            title: 'Order Cancelled ❌',
            body:
                'Your order has been cancelled. Any applicable refund has been initiated.'
          ),
        ];
      case NotificationType.delivery:
        return [
          (
            label: 'Driver Assigned',
            title: 'Delivery Agent Assigned 📦',
            body:
                'A dedicated delivery agent has been assigned and will pick up your order shortly.'
          ),
          (
            label: 'Driver Approaching',
            title: 'Driver Near Your Location 🛵',
            body:
                'Your delivery agent is approaching your delivery address. Please keep gate access ready.'
          ),
          (
            label: 'Fleet Morning Dispatch',
            title: 'Morning Fleet Dispatch 🚀',
            body:
                'All morning batch crates have been organized for route departure. Safe driving!'
          ),
        ];
      case NotificationType.promotional:
        return [
          (
            label: 'Ghee Offer',
            title: 'Pure Desi A2 Cow Ghee Offer 🏷️',
            body:
                'Enjoy 15% off on our traditional Bilona Cow Ghee this weekend only. Pure aroma in every spoon!'
          ),
          (
            label: 'Morning Combo',
            title: 'Fresh Paneer & Milk Combo 🥛',
            body:
                'Order 2L Whole Milk today and get 200g Fresh Malai Paneer at special discount.'
          ),
          (
            label: 'Festive Treats',
            title: 'Celebrate with Pure Dairy ✨',
            body:
                'Special festive supply of Mawa, Butter, and Rabri now available for pre-order.'
          ),
        ];
      case NotificationType.subscription:
        return [
          (
            label: 'Morning Dispatch',
            title: 'Daily Milk Dispatched 🥛',
            body:
                'Today\'s morning subscription bottle has left the depot. Expected at your door by 6:30 AM.'
          ),
          (
            label: 'Renewal Reminder',
            title: 'Subscription Renewal Reminder 🔄',
            body:
                'Your monthly milk subscription will renew in 3 days. Tap to check your delivery schedule.'
          ),
          (
            label: 'Vacation Pause',
            title: 'Going on Vacation? ⏸️',
            body:
                'Easily pause your daily milk deliveries anytime through the Calendar tab in the app.'
          ),
        ];
      case NotificationType.system:
        return [
          (
            label: 'Maintenance',
            title: 'Scheduled System Maintenance ⚙️',
            body:
                'The Sawariya Dairy app will undergo routine maintenance tonight from 1:00 AM to 3:00 AM.'
          ),
          (
            label: 'Holiday Timings',
            title: 'Special Delivery Schedule 📢',
            body:
                'Morning delivery timings will operate from 5:30 AM to 7:30 AM tomorrow.'
          ),
          (
            label: 'Quality Assurance',
            title: 'Cold-Chain Quality Guarantee ❄️',
            body:
                'All dairy batches maintain strict 4°C chilled temperature standards from farm to doorstep.'
          ),
        ];
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message.')),
      );
      return;
    }

    // Validation for ORDER
    if (_selectedType == NotificationType.order) {
      if (_selectedOrderId == null || _selectedOrderId!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an order to send an order-specific notification.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Validation for DELIVERY with order targeting
    if (_selectedType == NotificationType.delivery) {
      if (_deliveryTarget != 'allFleet' &&
          (_selectedOrderId == null || _selectedOrderId!.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an order or choose "All Delivery Fleet".'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSending = true);

    try {
      final adminUid = ref.read(userProvider).id;
      if (adminUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin session not found.')),
        );
        return;
      }

      final repo = ref.read(notificationRepositoryProvider);

      if (_selectedType == NotificationType.order) {
        // ── 1. Targeted 1-to-1 Order Notification ──
        final cleanOrderId = _selectedOrderId!.trim();
        final fullOrder = await ref
            .read(orderServiceProvider)
            .getOrderById(cleanOrderId);

        if (fullOrder == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected order not found.')),
            );
          }
          return;
        }

        final targetUid = fullOrder.userId;

        if (targetUid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Customer UID not found on selected order.')),
            );
          }
          return;
        }

        await repo.sendNotificationToUser(
          targetUserId: targetUid,
          title: title,
          body: body,
          type: NotificationType.order,
          createdBy: adminUid,
          orderId: fullOrder.id,
          route: '/orders/${fullOrder.id}',
          isActionable: true,
        );
      } else if (_selectedType == NotificationType.delivery) {
        // ── 2. Delivery Notification Flow ──
        if (_deliveryTarget == 'allFleet') {
          final agentIds = await repo.fetchDeliveryAgentUserIds();
          await repo.sendBroadcast(
            adminUid: adminUid,
            title: title,
            body: body,
            type: NotificationType.delivery,
            targetUserIds: agentIds,
            route: '/delivery',
            isActionable: true,
          );
        } else if (_selectedOrderId != null &&
            _selectedOrderId!.trim().isNotEmpty) {
          final cleanOrderId = _selectedOrderId!.trim();
          final fullOrder = await ref
              .read(orderServiceProvider)
              .getOrderById(cleanOrderId);

          if (fullOrder != null) {
            final customerUid = fullOrder.userId;

            if (_deliveryTarget == 'orderCustomer' || _deliveryTarget == 'both') {
              if (customerUid.isNotEmpty) {
                await repo.sendNotificationToUser(
                  targetUserId: customerUid,
                  title: title,
                  body: body,
                  type: NotificationType.delivery,
                  createdBy: adminUid,
                  orderId: fullOrder.id,
                  route: '/orders/${fullOrder.id}',
                  isActionable: true,
                );
              }
            }

            final agentId = (fullOrder.assignedAgentId != null &&
                    fullOrder.assignedAgentId!.isNotEmpty)
                ? fullOrder.assignedAgentId!
                : '';

            if ((_deliveryTarget == 'assignedDriver' ||
                    _deliveryTarget == 'both') &&
                agentId.isNotEmpty) {
              await repo.sendNotificationToUser(
                targetUserId: agentId,
                title: title,
                body: body,
                type: NotificationType.delivery,
                createdBy: adminUid,
                orderId: fullOrder.id,
                assignedAgentId: agentId,
                route: '/delivery',
                isActionable: true,
              );
            }
          }
        }
      } else if (_selectedType == NotificationType.promotional) {
        // ── 3. Promotional Broadcast ──
        List<String> targetUids = [];
        if (_audienceFilter == 'customersOnly') {
          targetUids = await repo.fetchCustomerUserIds();
        } else if (_audienceFilter == 'activeSubscribers') {
          targetUids = await repo.fetchActiveSubscriberUserIds();
        } else {
          targetUids = await repo.fetchAllUserIds();
        }

        await repo.sendBroadcast(
          adminUid: adminUid,
          title: title,
          body: body,
          type: NotificationType.promotional,
          targetUserIds: targetUids,
          route: '/notifications',
          isActionable: true,
        );
      } else if (_selectedType == NotificationType.subscription) {
        // ── 4. Subscription Targeted / Broadcast ──
        List<String> targetUids = [];
        if (_audienceFilter == 'activeSubscribers') {
          targetUids = await repo.fetchActiveSubscriberUserIds();
        } else {
          targetUids = await repo.fetchAllUserIds();
        }

        await repo.sendBroadcast(
          adminUid: adminUid,
          title: title,
          body: body,
          type: NotificationType.subscription,
          targetUserIds: targetUids,
          route: '/subscriptions',
          isActionable: true,
        );
      } else if (_selectedType == NotificationType.system) {
        // ── 5. System Notification ──
        List<String> targetUids = [];
        if (_audienceFilter == 'deliveryFleet') {
          targetUids = await repo.fetchDeliveryAgentUserIds();
        } else if (_audienceFilter == 'customersOnly') {
          targetUids = await repo.fetchCustomerUserIds();
        } else {
          targetUids = await repo.fetchAllUserIds();
        }

        await repo.sendBroadcast(
          adminUid: adminUid,
          title: title,
          body: body,
          type: NotificationType.system,
          targetUserIds: targetUids,
          route: '/notifications',
          isActionable: false,
        );
      }

      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _selectedOrderId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Notification dispatched successfully! 🚀'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dispatch notification: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    final adminUid = ref.watch(userProvider).id;
    final asyncHistory = adminUid.isNotEmpty
        ? ref.watch(notificationsForUserStreamProvider(adminUid))
        : const AsyncValue<List<NotificationItem>>.data([]);

    final templates = _getTemplatesForType(_selectedType);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Text(
            'Broadcasts & Targeted Alerts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Text(
            'Send order alerts, delivery dispatches, subscriber updates, and marketing offers with precise recipient targeting.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Composer Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Compose Notification',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notification type selector
                Text(
                  '1. Select Notification Type',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NotificationType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                          if (type == NotificationType.subscription) {
                            _audienceFilter = 'activeSubscribers';
                          } else {
                            _audienceFilter = 'allUsers';
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type.icon,
                              size: 15,
                              color:
                                  isSelected ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type.value[0].toUpperCase() +
                                  type.value.substring(1),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Contextual Recipient Selector ──
                if (_selectedType == NotificationType.order) ...[
                  _buildOrderSelector(cardBg, cardBorder, textPrimary, textSecondary),
                  const SizedBox(height: 16),
                ] else if (_selectedType == NotificationType.delivery) ...[
                  _buildDeliveryTargetSelector(cardBg, cardBorder, textPrimary, textSecondary),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildAudienceSelector(cardBg, cardBorder, textPrimary, textSecondary),
                  const SizedBox(height: 16),
                ],

                // ── Quick Templates ──
                Text(
                  'Quick Message Templates',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: templates.map((tmpl) {
                    return ActionChip(
                      label: Text(
                        tmpl.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.6),
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _applyTemplate(tmpl.title, tmpl.body),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Title & Message Fields ──
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    hintText: 'e.g. Morning Milk Dispatch Update 🥛',
                    labelStyle: GoogleFonts.plusJakartaSans(
                        color: textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Message Body',
                    hintText:
                        'e.g. Today\'s morning batch has left the cold-chain facility. Expected delivery by 6:30 AM.',
                    labelStyle: GoogleFonts.plusJakartaSans(
                        color: textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dispatch Button ──
                ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendNotification,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                  label: Text(
                    _isSending
                        ? 'Dispatching…'
                        : (_selectedType == NotificationType.order
                            ? 'Send Order Notification'
                            : 'Dispatch Notification'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Notification History Panel ──
          Row(
            children: [
              Text(
                'Notification History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              asyncHistory.whenOrNull(
                    data: (list) => Text(
                      '${list.length} logged',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ) ??
                  const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),

          asyncHistory.when(
            loading: () => Container(
              height: 120,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not load notification history.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            data: (history) {
              if (history.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: cardBorder, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 40,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No notifications dispatched yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: history
                    .map((notif) =>
                        _AdminNotifHistoryTile(notif: notif, context: context))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrderSelector(
      Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    return StreamBuilder<List<order_model.Order>>(
      stream: ref.read(orderServiceProvider).streamAllDeliveryOrders(),
      builder: (context, snapshot) {
        final rawOrders = snapshot.data ?? [];
        // Deduplicate orders by unique ID to guarantee each order ID appears at most once
        final uniqueOrders = <String, order_model.Order>{};
        for (final o in rawOrders) {
          if (o.id.isNotEmpty && !uniqueOrders.containsKey(o.id)) {
            uniqueOrders[o.id] = o;
          }
        }
        final orders = uniqueOrders.values.toList();

        // Ensure selected value exists in current list to prevent assertion errors
        final isSelectedInList = _selectedOrderId != null &&
            uniqueOrders.containsKey(_selectedOrderId);
        final selectedValue = isSelectedInList ? _selectedOrderId : null;
        final selectedOrder =
            selectedValue != null ? uniqueOrders[selectedValue] : null;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '2. Target Specific Order (Customer Owner)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (orders.isEmpty)
                Text(
                  'No orders found in the system.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: textSecondary),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                  ),
                  hint: Text(
                    'Select an Order (#ORD - Customer Name - ₹Amount)',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: textSecondary),
                  ),
                  items: orders.map((o) {
                    return DropdownMenuItem<String>(
                      value: o.id,
                      child: Text(
                        '#${o.displayOrderCode} — ${o.deliveryAddress.fullName} (₹${o.totalAmount.toStringAsFixed(0)}) [${o.status.label}]',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedOrderId = val;
                    });
                  },
                ),
              if (selectedOrder != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Recipient: ${selectedOrder.deliveryAddress.fullName} (${selectedOrder.deliveryAddress.mobileNumber})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryTargetSelector(
      Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Delivery Recipient Target',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _deliveryTarget,
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cardBorder),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'orderCustomer',
              child: Text('Selected Order Customer'),
            ),
            DropdownMenuItem(
              value: 'assignedDriver',
              child: Text('Assigned Delivery Agent Only'),
            ),
            DropdownMenuItem(
              value: 'both',
              child: Text('Both Customer & Assigned Driver'),
            ),
            DropdownMenuItem(
              value: 'allFleet',
              child: Text('All Delivery Fleet (Broadcast)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _deliveryTarget = val);
          },
        ),
        if (_deliveryTarget != 'allFleet') ...[
          const SizedBox(height: 12),
          _buildOrderSelector(cardBg, cardBorder, textPrimary, textSecondary),
        ],
      ],
    );
  }

  Widget _buildAudienceSelector(
      Color cardBg, Color cardBorder, Color textPrimary, Color textSecondary) {
    List<DropdownMenuItem<String>> items = [];

    if (_selectedType == NotificationType.promotional) {
      items = const [
        DropdownMenuItem(value: 'allUsers', child: Text('All Registered Users')),
        DropdownMenuItem(value: 'customersOnly', child: Text('Customers Only')),
        DropdownMenuItem(value: 'activeSubscribers', child: Text('Active Subscribers Only')),
      ];
    } else if (_selectedType == NotificationType.subscription) {
      items = const [
        DropdownMenuItem(
            value: 'activeSubscribers',
            child: Text('Active Subscribers Only (Targeted)')),
        DropdownMenuItem(
            value: 'allUsers',
            child: Text('All Users (Subscription Announcement)')),
      ];
    } else {
      items = const [
        DropdownMenuItem(value: 'allUsers', child: Text('All Registered Users')),
        DropdownMenuItem(value: 'deliveryFleet', child: Text('Delivery Fleet Only')),
        DropdownMenuItem(value: 'customersOnly', child: Text('Customers Only')),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Target Audience Filter',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _audienceFilter,
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cardBorder),
            ),
          ),
          items: items,
          onChanged: (val) {
            if (val != null) setState(() => _audienceFilter = val);
          },
        ),
      ],
    );
  }
}

// ─── Admin notification history tile ─────────────────────────────────────────

class _AdminNotifHistoryTile extends StatelessWidget {
  final NotificationItem notif;
  final BuildContext context;

  const _AdminNotifHistoryTile({
    required this.notif,
    required this.context,
  });

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    return DateFormat('dd MMM, hh:mm a').format(ts);
  }

  Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF0284C7);
      case NotificationType.delivery:
        return AppColors.primary;
      case NotificationType.promotional:
        return const Color(0xFFF59E0B);
      case NotificationType.subscription:
        return const Color(0xFF7C3AED);
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final typeColor = _typeColor(notif.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(notif.type.icon, size: 18, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notif.type.value[0].toUpperCase() +
                            notif.type.value.substring(1),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      _formatTimestamp(notif.timestamp),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                    if (notif.orderId != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.receipt_long_rounded,
                          size: 11, color: textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        notif.orderId!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
