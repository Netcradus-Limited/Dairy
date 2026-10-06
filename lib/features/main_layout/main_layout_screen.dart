import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive/responsive.dart';
import '../../core/widgets/app_app_bar.dart';
import '../../core/widgets/app_bottom_navigation.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/navigation_provider.dart';
import '../address/address_screen.dart';
import '../cart/cart_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

/// Main Responsive Layout Shell
class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    _loadedTabs.add(currentIndex);

    final cartCount = ref.watch(cartItemCountProvider);
    final deliveryLocation = ref.watch(deliveryLocationDisplayProvider);
    final isDesktop = context.isDesktop;

    final List<Widget> pages = [
      _loadedTabs.contains(0) ? const HomeScreen() : const SizedBox.shrink(),
      _loadedTabs.contains(1) ? const ShopScreen() : const SizedBox.shrink(),
      _loadedTabs.contains(2) ? const OrdersScreen() : const SizedBox.shrink(),
      _loadedTabs.contains(3) ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    void handleLocationTap() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddressScreen()),
      );
    }

    if (isDesktop) {
      return Scaffold(
        appBar: AppTopAppBar(
          cartItemCount: cartCount,
          deliveryLocation: deliveryLocation,
          onLocationTap: handleLocationTap,
          onSearchTap: () {
            ref.read(navigationProvider.notifier).setIndex(1);
          },
          onNotificationTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          onCartTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
        body: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;

    // Mobile & Tablet Layout
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(72.0 + topPadding),
        child: AppTopAppBar(
          cartItemCount: cartCount,
          deliveryLocation: deliveryLocation,
          onLocationTap: handleLocationTap,
          onSearchTap: () {
            ref.read(navigationProvider.notifier).setIndex(1);
          },
          onNotificationTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          onCartTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(navigationProvider.notifier).setIndex(index);
        },
      ),
    );
  }
}
