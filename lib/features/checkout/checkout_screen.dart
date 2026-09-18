import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/address_tile.dart';
import '../../core/widgets/cart_item_tile.dart';
import '../../core/widgets/payment_option_tile.dart';
import '../../core/widgets/price_summary.dart';
import '../../models/address.dart';
import '../../models/order.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/order_service.dart';
import '../address/add_address_screen.dart';
import '../address/address_screen.dart';
import '../../core/localization/app_language.dart';

/// StateProvider for current payment method choice
final paymentMethodProvider = StateProvider<PaymentMethodType>((ref) {
  return PaymentMethodType.cashOnDelivery;
});

/// Sawariya Dairy Phase 6 — Checkout Screen
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  Future<void> _onPlaceOrder(BuildContext context, WidgetRef ref) async {
    final cartItems = ref.read(cartItemsProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Your cart is empty'))),
      );
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to place an order.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.push('/login');
      return;
    }

    final selectedAddress = ref.read(selectedAddressProvider);
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please add or select a delivery address to place your order.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final paymentMethod = ref.read(paymentMethodProvider);
    final paymentName = paymentMethod == PaymentMethodType.cashOnDelivery
        ? 'Cash on Delivery'
        : 'Online Payment';

    // Show a loading indicator while the order is persisted to Firestore.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Order newOrder;
    try {
      newOrder = await ref.read(orderServiceProvider).placeOrder(
            userId: authUser.uid,
            items: cartItems,
            deliveryAddress: selectedAddress,
            paymentMethod: paymentName,
          );
    } catch (e) {
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
      return;
    }
    Navigator.pop(context); // close loading dialog

    // Firestore stream will automatically reflect the new order.
    // Clear the cart after an order is placed
    ref.read(cartProvider.notifier).clearCart();

    // Show Confirmation Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppSizes.borderLarge),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.freshGreen,
                  size: 54,
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              const Text(
                '🎉 Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Order #${newOrder.displayOrderCode}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              Text(
                'Thank you for ordering with Sawariya Dairy!\nYour fresh products will be delivered to:\n\n${selectedAddress.fullName}\n${selectedAddress.fullAddressText}\n\nPayment Mode: $paymentName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.p20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx); // close dialog
                    Navigator.pop(context); // close checkout page

                    // Navigate to Home
                    ref.read(navigationProvider.notifier).setIndex(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSizes.borderMedium,
                    ),
                  ),
                  child: const Text(
                    'Back to Home Feed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final delivery = ref.watch(cartDeliveryChargeProvider);
    final discount = ref.watch(cartDiscountProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('Checkout & Order Review')),
        elevation: 0,
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
                    // Left Column (Address & Payment)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAddressSection(context, ref, selectedAddress),
                          const SizedBox(height: AppSizes.p20),
                          _buildPaymentSection(ref, paymentMethod),
                          const SizedBox(height: AppSizes.p20),
                          _buildCartItemsReview(cartItems),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.p24),

                    // Right Column (Bill Summary & Action)
                    Expanded(
                      flex: 2,
                      child: PriceSummaryCard(
                        subtotal: subtotal,
                        deliveryCharge: delivery,
                        discount: discount,
                        grandTotal: grandTotal,
                        actionButtonText: 'Place Order Now',
                        onActionButtonPressed: () =>
                            _onPlaceOrder(context, ref),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAddressSection(context, ref, selectedAddress),
                    const SizedBox(height: AppSizes.p16),
                    _buildPaymentSection(ref, paymentMethod),
                    const SizedBox(height: AppSizes.p16),
                    _buildCartItemsReview(cartItems),
                    const SizedBox(height: AppSizes.p20),
                    PriceSummaryCard(
                      subtotal: subtotal,
                      deliveryCharge: delivery,
                      discount: discount,
                      grandTotal: grandTotal,
                      actionButtonText: 'Place Order Now',
                      onActionButtonPressed: () => _onPlaceOrder(context, ref),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAddressSection(
      BuildContext context, WidgetRef ref, Address? selectedAddress) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    tr('Delivery Address'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  final chosen = await Navigator.push<Address>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddressScreen(),
                    ),
                  );
                  if (chosen != null) {
                    ref.read(selectedAddressIdProvider.notifier).state =
                        chosen.id;
                  }
                },
                icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                label: Text(selectedAddress != null ? 'Change' : 'Select'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          if (selectedAddress != null) ...[
            AddressTile(
              address: selectedAddress,
              isSelected: true,
              onSelect: () {},
            ),
            const SizedBox(height: 8),
            // Quick action to capture & use current location
            InkWell(
              onTap: () async {
                final newAddr = await Navigator.push<Address>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AddAddressScreen(autoDetectLocation: true),
                  ),
                );
                if (newAddr != null) {
                  ref.read(selectedAddressIdProvider.notifier).state =
                      newAddr.id;
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 15,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Use Current Location Instead',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    size: 36,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No delivery address selected.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Auto-detect your location or choose a saved address to proceed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final newAddr = await Navigator.push<Address>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddAddressScreen(
                                    autoDetectLocation: true),
                              ),
                            );
                            if (newAddr != null) {
                              ref
                                  .read(selectedAddressIdProvider.notifier)
                                  .state = newAddr.id;
                            }
                          },
                          icon: const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text('Use Current Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final chosen = await Navigator.push<Address>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddressScreen(),
                              ),
                            );
                            if (chosen != null) {
                              ref
                                  .read(selectedAddressIdProvider.notifier)
                                  .state = chosen.id;
                            }
                          },
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: const Text('Saved Addresses'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side:
                                const BorderSide(color: AppColors.primaryBlue),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection(WidgetRef ref, PaymentMethodType paymentMethod) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          PaymentOptionTile(
            method: PaymentMethodType.cashOnDelivery,
            selectedMethod: paymentMethod,
            onSelected: (m) =>
                ref.read(paymentMethodProvider.notifier).state = m,
          ),
          PaymentOptionTile(
            method: PaymentMethodType.onlinePayment,
            selectedMethod: paymentMethod,
            onSelected: (m) =>
                ref.read(paymentMethodProvider.notifier).state = m,
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsReview(List<dynamic> cartItems) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${cartItems.length} Products',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          ...cartItems.map(
            (item) => CartItemTile(
              cartItem: item,
              isCompact: true,
              onIncrement: () {},
              onDecrement: () {},
              onRemove: () {},
            ),
          ),
        ],
      ),
    );
  }
}
