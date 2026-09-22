import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/cart_item_tile.dart';
import '../../core/widgets/price_summary.dart';
import '../../providers/cart_provider.dart';
import '../../providers/navigation_provider.dart';
import '../checkout/checkout_screen.dart';

/// Sawariya Dairy Phase 6 — Cart Screen
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final delivery = ref.watch(cartDeliveryChargeProvider);
    final discount = ref.watch(cartDiscountProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final isDesktop = context.isDesktop;

    void handleGoBack() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }

    void handleGoToShop() {
      ref.read(navigationProvider.notifier).setIndex(1);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Shopping Cart'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: handleGoBack,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: AppColors.lightBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      size: 60,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p24),
                const Text(
                  'Your Cart is Currently Empty',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                const Text(
                  'Looks like you haven\'t added any fresh dairy items yet.\nExplore our wide range of farm-fresh products!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSizes.p24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: handleGoToShop,
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text(
                      'Explore Fresh Dairy Catalog',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppSizes.borderMedium,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Cart (${cartItems.length} items)'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: handleGoBack,
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared')),
              );
            },
            icon:
                const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            label: const Text(
              'Clear Cart',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: AppSizes.p16,
        ),
        child: ResponsiveContainer(
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Items List
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCartHeader(),
                          const SizedBox(height: AppSizes.p12),
                          ...cartItems.map(
                            (item) => CartItemTile(
                              cartItem: item,
                              onIncrement: () => ref
                                  .read(cartProvider.notifier)
                                  .increment(item.product),
                              onDecrement: () => ref
                                  .read(cartProvider.notifier)
                                  .decrement(item.product.id),
                              onRemove: () => ref
                                  .read(cartProvider.notifier)
                                  .removeItem(item.product.id),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p16),
                          _buildContinueShoppingButton(context, ref),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.p24),

                    // Right Column: Summary Card
                    Expanded(
                      flex: 2,
                      child: PriceSummaryCard(
                        subtotal: subtotal,
                        deliveryCharge: delivery,
                        discount: discount,
                        grandTotal: grandTotal,
                        actionButtonText: 'Proceed to Checkout',
                        onActionButtonPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CheckoutScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCartHeader(),
                    const SizedBox(height: AppSizes.p12),
                    ...cartItems.map(
                      (item) => CartItemTile(
                        cartItem: item,
                        onIncrement: () => ref
                            .read(cartProvider.notifier)
                            .increment(item.product),
                        onDecrement: () => ref
                            .read(cartProvider.notifier)
                            .decrement(item.product.id),
                        onRemove: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.product.id),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p16),
                    PriceSummaryCard(
                      subtotal: subtotal,
                      deliveryCharge: delivery,
                      discount: discount,
                      grandTotal: grandTotal,
                      actionButtonText: 'Proceed to Checkout',
                      onActionButtonPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.p16),
                    _buildContinueShoppingButton(context, ref),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: AppSizes.borderSmall,
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded,
              color: AppColors.primaryBlue, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Fresh Dairy Direct from Sawariya Farms',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueShoppingButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () {
        ref.read(navigationProvider.notifier).setIndex(1);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Continue Shopping'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        side: const BorderSide(color: AppColors.primaryBlue),
        shape: const RoundedRectangleBorder(
          borderRadius: AppSizes.borderMedium,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
