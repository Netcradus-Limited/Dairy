import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/delivery_boy_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/delivery_live_location_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/battery_optimization_provider.dart';
import '../../services/fcm_service.dart';
import '../../services/network_connectivity_service.dart';
import 'screens/requests_tab.dart';
import 'screens/active_delivery_tab.dart';
import 'screens/orders_tab.dart';
import 'screens/earnings_tab.dart';
import 'screens/profile_tab.dart';
import 'widgets/battery_optimization_warning_banner.dart';
import 'widgets/gps_status_warning_banner.dart';

class _BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Delivery Boy Panel - Main Screen with Bottom Navigation
class DeliveryPanelScreen extends ConsumerStatefulWidget {
  const DeliveryPanelScreen({super.key});

  @override
  ConsumerState<DeliveryPanelScreen> createState() =>
      _DeliveryPanelScreenState();
}

class _DeliveryPanelScreenState extends ConsumerState<DeliveryPanelScreen>
    with WidgetsBindingObserver {
  static const List<_BottomNavItem> _navItems = [
    _BottomNavItem(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Requests'),
    _BottomNavItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: 'Active'),
    _BottomNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Orders'),
    _BottomNavItem(
        icon: Icons.account_balance_wallet,
        activeIcon: Icons.account_balance_wallet,
        label: 'Earnings'),
    _BottomNavItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  static const List<Widget> _pages = [
    RequestsTab(),
    ActiveDeliveryTab(),
    OrdersTab(),
    EarningsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLastTappedOrder();
      ref.read(batteryOptimizationProvider.notifier).checkStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(batteryOptimizationProvider.notifier).checkStatus();
      ref.read(agentLiveLocationProvider.notifier).refreshStatus();
    }
  }

  void _checkLastTappedOrder() {
    final tappedOrderId = ref.read(lastTappedOrderIdProvider);
    if (tappedOrderId.isNotEmpty) {
      _handleTappedOrderId(tappedOrderId);
    }
  }

  void _handleTappedOrderId(String orderId) {
    final activeOrders =
        ref.read(deliveryActiveOrdersStreamProvider).asData?.value ?? [];
    final isActive =
        activeOrders.any((o) => o.id == orderId || o.orderId == orderId);
    if (isActive) {
      ref.read(deliveryPanelTabProvider.notifier).setTab(1);
    } else {
      ref.read(deliveryPanelTabProvider.notifier).setTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(lastTappedOrderIdProvider, (prev, next) {
      if (next.isNotEmpty && next != prev) {
        _handleTappedOrderId(next);
      }
    });

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final sharing = ref.watch(agentLiveLocationProvider);
    final currentIndex = ref.watch(deliveryPanelTabProvider);
    final isNetworkOnline = ref.watch(networkConnectivityProvider);

    final bodyContent = Column(
      children: [
        if (!isNetworkOnline) _buildOfflineBanner(context),
        const GpsStatusWarningBanner(),
        const BatteryOptimizationWarningBanner(),
        Expanded(
          child: IndexedStack(
            index: currentIndex,
            children: _pages,
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(currentIndex),
            Expanded(
              child: Column(
                children: [
                  _buildDesktopTopBar(isOnline, currentIndex, sharing),
                  Expanded(child: bodyContent),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildMobileAppBar(isOnline, currentIndex, sharing),
      body: bodyContent,
      bottomNavigationBar: _buildMobileBottomNav(currentIndex),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are currently offline. Changes will sync when reconnected.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
          InkWell(
            onTap: () =>
                ref.read(networkConnectivityProvider.notifier).checkNow(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Retry',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomNav(int currentIndex) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(deliveryPanelTabProvider.notifier).setTab(index),
        backgroundColor: AppColors.surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: _navItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDesktopSidebar(int currentIndex) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Container(
      width: 280,
      color: cardBg,
      child: Column(
        children: [
          Container(
            height: 140,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.transparent,
                  backgroundImage: AssetImage('assets/images/nicon.png'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = currentIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? AppColors.primaryLight.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? AppColors.primary : textSecondary,
                      ),
                      title: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () => ref
                          .read(deliveryPanelTabProvider.notifier)
                          .setTab(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Stats',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        '${ref.watch(deliveryAgentProvider).completedDeliveriesToday} / ${ref.watch(deliveryAgentProvider).totalDeliveriesToday}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${ref.watch(deliveryAgentProvider).earningsToday.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmLogout(context),
                hoverColor: AppColors.error.withValues(alpha: 0.08),
                splashColor: AppColors.error.withValues(alpha: 0.12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Logout',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBgOf(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(ctx),
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondaryOf(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondaryOf(ctx),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      ref.read(agentLiveLocationProvider.notifier).stopTracking();
      ref.read(cartProvider.notifier).clearLocalCart();
      await ref.read(userProvider.notifier).clearSession();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Widget _buildDesktopTopBar(bool isOnline, int currentIndex, bool sharing) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: Row(
        children: [
          Text(
            _navItems[currentIndex].label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Live Delivery Map',
            icon: const Icon(Icons.map_rounded),
            onPressed: () => context.push('/delivery-map'),
          ),
          IconButton(
            tooltip:
                sharing ? 'Stop sharing live location' : 'Share live location',
            icon: Icon(sharing
                ? Icons.location_on_rounded
                : Icons.location_off_rounded),
            onPressed: () =>
                ref.read(agentLiveLocationProvider.notifier).toggle(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? AppColors.success : AppColors.error,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
      bool isOnline, int currentIndex, bool sharing) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final cardBg = AppColors.cardBgOf(context);

    return AppBar(
      backgroundColor: cardBg,
      elevation: 0,
      title: Text(
        _navItems[currentIndex].label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Live Delivery Map',
          icon: const Icon(Icons.map_rounded),
          onPressed: () => context.push('/delivery-map'),
        ),
        IconButton(
          tooltip:
              sharing ? 'Stop sharing live location' : 'Share live location',
          icon: Icon(
              sharing ? Icons.location_on_rounded : Icons.location_off_rounded),
          onPressed: () =>
              ref.read(agentLiveLocationProvider.notifier).toggle(),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? AppColors.success : AppColors.error,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
