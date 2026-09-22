import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/product_image.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../subscription/edit_subscription_screen.dart';

/// Sawariya Dairy — Subscriptions Home Screen
/// Displays and manages multiple recurring product subscriptions with Firestore live sync.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditSubscriptionScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.loading && state.subscriptions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.hasError && state.subscriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${state.errorMessage}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(subscriptionProvider.notifier)
                            .loadSubscription(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionState state) {
    if (state.subscriptions.isEmpty) {
      return _buildEmptyState(context);
    }

    final activeCount = state.activeSubscriptions.length;
    final totalMonthly = state.activeSubscriptions.fold<double>(
        0.0, (acc, s) => acc + s.monthlyCost);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHorizontalPadding,
        vertical: AppSizes.p16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubscriptionsOverview(
            context,
            totalCount: state.subscriptions.length,
            activeCount: activeCount,
            totalMonthly: totalMonthly,
          ),
          const SizedBox(height: AppSizes.p16),
          ...state.subscriptions.map(
            (sub) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p16),
              child: _SubscriptionCard(
                subscription: sub,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditSubscriptionScreen(subscription: sub),
                    ),
                  );
                },
                statusColor: _statusColor(sub.status),
                isActive: sub.isActiveAndValid,
                isExpired: !sub.isActiveAndValid && !sub.isCancelled,
                isCancelled: sub.isCancelled,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsOverview(
    BuildContext context, {
    required int totalCount,
    required int activeCount,
    required double totalMonthly,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: AppSizes.borderSmall,
                  ),
                  child: const Icon(
                    Icons.all_inbox_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeCount Active ($totalCount Total)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Daily & recurring doorstep deliveries',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${totalMonthly.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const Text(
                  'Est. monthly',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                  Icons.subscriptions_outlined,
                  size: 50,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            const Text(
              'No Subscriptions Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            const Text(
              'Subscribe to your favourite dairy products (Milk, Ghee, Paneer, Lassi, Makhan) and get them delivered fresh with a 10% recurring discount.',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditSubscriptionScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create Subscription',
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

  Color _statusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return AppColors.freshGreen;
      case SubscriptionStatus.paused:
        return const Color(0xFFF59E0B);
      case SubscriptionStatus.cancelled:
        return AppColors.error;
    }
  }
}

class _SubscriptionCard extends ConsumerWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final Color statusColor;
  final bool isActive;
  final bool isExpired;
  final bool isCancelled;

  const _SubscriptionCard({
    required this.subscription,
    required this.onTap,
    required this.statusColor,
    required this.isActive,
    required this.isExpired,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(subscription.id),
      direction: isCancelled
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: Container(
        decoration: const BoxDecoration(
          color: AppColors.error,
          borderRadius: AppSizes.borderLarge,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cancel Subscription?'),
                content: Text(
                    'Are you sure you want to cancel your ${subscription.product.title} subscription?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep Active'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Cancel Subscription'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(subscriptionProvider.notifier).cancelSubscription(subscription.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${subscription.product.title} subscription cancelled')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSizes.borderLarge,
          border: Border.all(
            color: isCancelled
                ? AppColors.border
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1.0,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTap,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: product, status chip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: AppSizes.borderSmall,
                            ),
                            child: Center(
                              child: ProductImage(
                                imageUrl: subscription.product.imageUrl,
                                categoryKey: subscription.product.categoryId,
                                title: subscription.product.title,
                                size: 38,
                                radius: 8,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscription.product.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${subscription.product.unit} • ${subscription.product.categoryName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.35)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                subscription.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    // Middle: details
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.repeat_rounded,
                            'Frequency',
                            subscription.frequency.label,
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            Icons.numbers_rounded,
                            'Qty per delivery',
                            '${subscription.quantity}',
                          ),
                          const SizedBox(height: 6),
                          () {
                            final nextDelivery = subscription.nextDeliveryDate;
                            return _buildDetailRow(
                              Icons.schedule_rounded,
                              'Next delivery',
                              nextDelivery == null
                                  ? '—'
                                  : DateFormat.yMMMd()
                                      .add_jm()
                                      .format(nextDelivery),
                            );
                          }(),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            Icons.local_shipping_outlined,
                            'Delivery slot',
                            subscription.deliveryTimeSlot,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.border),
              // Bottom: pricing + actions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;
                    final actionButtons = _buildActionButtons(context, ref);
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '₹${subscription.priceAfterDiscountPerDelivery.toStringAsFixed(2)} / delivery',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              Text(
                                '₹${subscription.monthlyCost.toStringAsFixed(0)} / mo',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (actionButtons.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: actionButtons,
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${subscription.priceAfterDiscountPerDelivery.toStringAsFixed(2)} / delivery',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            Text(
                              '₹${subscription.monthlyCost.toStringAsFixed(0)} / month',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (actionButtons.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: actionButtons,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, WidgetRef ref) {
    return [
      if (subscription.status == SubscriptionStatus.active) ...[
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(subscriptionProvider.notifier)
                  .skipNextDelivery(subscription.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Next ${subscription.product.title} delivery skipped')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to skip: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.skip_next_rounded,
              size: 16, color: Color(0xFFE65100)),
          label: const Text(
            'Skip',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: Color(0xFFE65100)),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(subscriptionProvider.notifier)
                .pauseSubscription(subscription.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${subscription.product.title} subscription paused')),
            );
          },
          icon: const Icon(Icons.pause_rounded,
              size: 16, color: AppColors.primaryBlue),
          label: const Text(
            'Pause',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: AppColors.primaryBlue),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(subscriptionProvider.notifier)
                .cancelSubscription(subscription.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${subscription.product.title} subscription cancelled')),
            );
          },
          icon: const Icon(Icons.cancel_outlined,
              size: 16, color: AppColors.error),
          label: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: AppColors.error),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
      if (subscription.status == SubscriptionStatus.paused) ...[
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(subscriptionProvider.notifier)
                .resumeSubscription(subscription.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${subscription.product.title} subscription resumed')),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded,
              size: 16, color: AppColors.freshGreen),
          label: const Text(
            'Resume',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.freshGreen,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: AppColors.freshGreen),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(subscriptionProvider.notifier)
                .cancelSubscription(subscription.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${subscription.product.title} subscription cancelled')),
            );
          },
          icon: const Icon(Icons.cancel_outlined,
              size: 16, color: AppColors.error),
          label: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: const BorderSide(color: AppColors.error),
            shape: const RoundedRectangleBorder(
                borderRadius: AppSizes.borderMedium),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ];
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
