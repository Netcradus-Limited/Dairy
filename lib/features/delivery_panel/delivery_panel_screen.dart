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
import 'theme/delivery_theme.dart';
import 'screens/delivery_home_tab.dart';
import 'screens/delivery_my_orders_tab.dart';
import 'screens/delivery_map_tab.dart';
import 'screens/delivery_earnings_redesigned_tab.dart';
import 'screens/delivery_profile_redesigned_tab.dart';
import 'screens/delivery_history_redesigned_screen.dart';
import 'screens/delivery_settings_redesigned_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'widgets/delivery_agent_avatar.dart';
import 'widgets/delivery_bottom_nav.dart';

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
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _BottomNavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'My Orders',
    ),
    _BottomNavItem(
      icon: Icons.location_on_outlined,
      activeIcon: Icons.location_on_rounded,
      label: 'Map',
    ),
    _BottomNavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
    ),
    _BottomNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  static const List<Widget> _pages = [
    DeliveryHomeTab(),
    DeliveryMyOrdersTab(),
    DeliveryMapTab(),
    DeliveryEarningsRedesignedTab(),
    DeliveryProfileRedesignedTab(),
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
      drawer: _buildAppDrawer(context),
      body: bodyContent,
      bottomNavigationBar: DeliveryBottomNav(
        currentIndex: currentIndex,
        onTabSelected: (index) =>
            ref.read(deliveryPanelTabProvider.notifier).setTab(index),
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    final agent = ref.watch(deliveryAgentProvider);
    return Drawer(
      child: Material(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: DeliveryTheme.headerGradient,
            ),
            accountName: Text(
              agent.name.isNotEmpty ? agent.name : 'Delivery Partner',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              agent.phone.isNotEmpty
                  ? agent.phone
                  : (FirebaseAuth.instance.currentUser?.phoneNumber ??
                      'Sawariya Dairy Delivery Partner'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFFC8E6C9),
              ),
            ),
            currentAccountPicture: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: DeliveryAgentAvatar(
                radius: 34,
                imageUrl: agent.profileImageUrl,
                iconSize: 36,
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.home_outlined, color: DeliveryTheme.primary),
            title: Text('Home', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              ref.read(deliveryPanelTabProvider.notifier).setTab(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined,
                color: DeliveryTheme.primary),
            title: Text('My Orders', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              ref.read(deliveryPanelTabProvider.notifier).setTab(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined,
                color: DeliveryTheme.primary),
            title: Text('Map', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              ref.read(deliveryPanelTabProvider.notifier).setTab(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined,
                color: DeliveryTheme.primary),
            title: Text('Earnings', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              ref.read(deliveryPanelTabProvider.notifier).setTab(3);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.history_rounded, color: DeliveryTheme.primary),
            title:
                Text('Delivery History', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeliveryHistoryRedesignedScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined,
                color: DeliveryTheme.primary),
            title: Text('Settings', style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeliverySettingsRedesignedScreen(),
                ),
              );
            },
          ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: DeliveryTheme.statusCancelledText),
              title: Text(
                'Logout',
                style: GoogleFonts.plusJakartaSans(
                  color: DeliveryTheme.statusCancelledText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout_rounded,
                color: DeliveryTheme.statusCancelledText, size: 24),
            const SizedBox(width: 8),
            Text(
              'Confirm Logout',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? Live GPS tracking will be safely terminated.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DeliveryTheme.statusCancelledText,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      ref.read(agentLiveLocationProvider.notifier).stopTracking();
      ref.read(cartProvider.notifier).clearLocalCart();
      await ref.read(userProvider.notifier).clearSession();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 16, color: AppColors.warning),
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
                        ? const Color(0xFFE8F5E9)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(
                              color: Color(0xFF81C784), width: 1.5)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? const Color(0xFF43A047)
                            : textSecondary,
                      ),
                      title: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : textPrimary,
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
                    color: const Color(0xFF43A047),
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
                onTap: _confirmLogout,
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
                  ? const Color(0xFFE8F5E9)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? const Color(0xFF43A047) : AppColors.error,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF43A047) : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? const Color(0xFF43A047) : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
