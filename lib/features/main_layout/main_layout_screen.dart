import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_language.dart';
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

/// Main Responsive Layout Shell with Native Mobile Floating Cart Bar
class MainLayoutScreen extends ConsumerWidget {
  const MainLayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final cartSubtotal = ref.watch(cartSubtotalProvider);
    final deliveryLocation = ref.watch(deliveryLocationDisplayProvider);
    final isDesktop = context.isDesktop;

    final List<Widget> pages = [
      const HomeScreen(), // 0 – Home
      const ShopScreen(), // 1 – Shop
      const OrdersScreen(), // 2 – Orders
      const ProfileScreen(), // 3 – Profile
    ];

    void handleLocationTap() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddressScreen()),
      );
    }

    void handleCartTap() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
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
              MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()),
            );
          },
          onCartTap: handleCartTap,
        ),
        body: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;

    // Mobile & Tablet Layout with Floating Cart Bar & Bottom Navigation
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
          onCartTap: handleCartTap,
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: pages,
          ),
          // Floating Cart Bar (Quick Commerce Style above bottom nav)
          if (cartCount > 0)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: _FloatingCartBar(
                itemCount: cartCount,
                subtotal: cartSubtotal,
                onTap: handleCartTap,
              ),
            ),
        ],
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

class _FloatingCartBar extends StatelessWidget {
  final int itemCount;
  final double subtotal;
  final VoidCallback onTap;

  const _FloatingCartBar({
    required this.itemCount,
    required this.subtotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, (1 - val) * 20),
          child: Opacity(
            opacity: val,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4A2F), Color(0xFF1B6B4C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F4A2F).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? tr('item') : tr('items')} | ₹${subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        tr('Extra charges may apply at checkout'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('View Cart'),
                        style: const TextStyle(
                          color: Color(0xFF0F4A2F),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF0F4A2F),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
