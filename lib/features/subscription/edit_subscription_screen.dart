import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/product_image.dart';
import '../../models/product.dart';
import '../../models/subscription.dart';
import '../../providers/product_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../repositories/product_repository.dart';

class EditSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscription;

  const EditSubscriptionScreen({super.key, this.subscription});

  @override
  ConsumerState<EditSubscriptionScreen> createState() =>
      _EditSubscriptionScreenState();
}

class _EditSubscriptionScreenState
    extends ConsumerState<EditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _deliverySlotController = TextEditingController();
  late SubscriptionFrequency _selectedFrequency;
  late String _deliveryTimeSlot;
  late bool _includeIcePack;

  late final bool _isNew;
  Product? _chosenProduct;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    if (s != null) {
      _isNew = false;
      _selectedFrequency = s.frequency;
      _deliveryTimeSlot = s.deliveryTimeSlot;
      _includeIcePack = s.includeIcePack;
      _chosenProduct = s.product;
      _quantityController.text = s.quantity.toString();
      _deliverySlotController.text = s.deliveryTimeSlot;
    } else {
      _isNew = true;
      _selectedFrequency = SubscriptionFrequency.daily;
      _deliveryTimeSlot = 'Morning (6:00 AM - 9:00 AM)';
      _includeIcePack = true;
      _quantityController.text = '1';
      _deliverySlotController.text = 'Morning (6:00 AM - 9:00 AM)';
    }
  }

  static List<Product> _dedupe(List<Product> list) {
    final seen = <String>{};
    final out = <Product>[];
    for (final p in list) {
      if (seen.add(p.id)) out.add(p);
    }
    return out;
  }

  List<Product> _getFallbackProducts() {
    final repo = ProductRepository();
    return _dedupe([
      ...repo.getA2MilkProducts(),
      ...repo.getFreshDeals(),
      ...repo.getBestSellers(),
    ]).where((p) => p.subscriptionEnabled && p.inStock).toList();
  }

  List<Product> _resolveAvailableProducts(List<Product> streamedProducts) {
    final baseList = streamedProducts.isNotEmpty
        ? streamedProducts
        : _getFallbackProducts();

    final filtered = baseList
        .where((p) => p.subscriptionEnabled && p.inStock)
        .toList();

    return _dedupe(filtered.isNotEmpty ? filtered : _getFallbackProducts());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _deliverySlotController.dispose();
    super.dispose();
  }

  DateTime _computeNextDelivery(SubscriptionFrequency frequency) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, 6);
    switch (frequency) {
      case SubscriptionFrequency.daily:
        return base.add(const Duration(days: 1));
      case SubscriptionFrequency.alternateDay:
        return base.add(const Duration(days: 2));
      case SubscriptionFrequency.weekly:
        return base.add(const Duration(days: 7));
    }
  }

  Future<void> _onSave(List<Product> availableProducts) async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity < 1) return;

    _deliveryTimeSlot = _deliverySlotController.text.trim().isNotEmpty
        ? _deliverySlotController.text.trim()
        : _deliveryTimeSlot;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in with OTP before creating a subscription.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final defaultProduct = availableProducts.isNotEmpty
        ? availableProducts.first
        : _getFallbackProducts().first;
    final Product product = _chosenProduct ?? defaultProduct;
    final now = DateTime.now();

    // Check duplicate active subscription for exact same product when creating new
    if (_isNew) {
      final existingSubs = ref.read(subscriptionProvider).subscriptions;
      final duplicate = existingSubs.where(
        (s) => s.product.id == product.id && s.isActiveAndValid,
      ).toList();

      if (duplicate.isNotEmpty) {
        final shouldEdit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Active Subscription Exists'),
            content: Text(
                'You already have an active subscription for "${product.title}". Would you like to edit your existing subscription instead?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Edit Existing'),
              ),
            ],
          ),
        );
        if (shouldEdit == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EditSubscriptionScreen(subscription: duplicate.first),
            ),
          );
        }
        return;
      }
    }

    final uniqueDocId = _isNew
        ? 'sub_${now.millisecondsSinceEpoch}_${now.microsecond}'
        : widget.subscription!.id;

    final subscription = _isNew
        ? Subscription(
            id: uniqueDocId,
            product: product,
            quantity: quantity,
            frequency: _selectedFrequency,
            status: SubscriptionStatus.active,
            startDate: now,
            endDate: now.add(const Duration(days: 30)),
            nextDeliveryDate: _computeNextDelivery(_selectedFrequency),
            deliveryTimeSlot: _deliveryTimeSlot,
            includeIcePack: _includeIcePack,
            planId: 'plan_${product.id}',
            planName: '${product.title} Monthly Plan',
            autoRenew: true,
            createdAt: now,
            updatedAt: now,
          )
        : widget.subscription!.copyWith(
            product: product,
            quantity: quantity,
            frequency: _selectedFrequency,
            deliveryTimeSlot: _deliveryTimeSlot,
            includeIcePack: _includeIcePack,
            updatedAt: now,
          );

    final notifier = ref.read(subscriptionProvider.notifier);

    try {
      if (_isNew) {
        await notifier.createSubscription(subscription);
      } else {
        await notifier.updateSubscription(subscription);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNew
              ? 'New subscription for ${product.title} created successfully!'
              : '${product.title} subscription updated successfully!'),
          backgroundColor: AppColors.freshGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save subscription: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final streamedProducts = ref.watch(allProductsProvider);
    final availableProducts = _resolveAvailableProducts(streamedProducts);

    final defaultProduct = availableProducts.isNotEmpty
        ? availableProducts.first
        : _getFallbackProducts().first;
    final product = _chosenProduct ?? defaultProduct;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isNew ? 'New Subscription' : 'Edit Subscription'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHorizontalPadding,
          vertical: AppSizes.p16,
        ),
        child: Center(
          child: Container(
            constraints:
                BoxConstraints(maxWidth: isDesktop ? 720 : double.infinity),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductSelector(availableProducts, product),
                  const SizedBox(height: AppSizes.p20),
                  _buildFrequencySelector(),
                  const SizedBox(height: AppSizes.p20),
                  AppTextField(
                    label: 'Quantity per delivery',
                    hint: 'Enter number of units',
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.numbers_rounded,
                        color: AppColors.primaryBlue),
                    onChanged: (_) {
                      setState(() {});
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Quantity is required';
                      }
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) {
                        return 'Enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.p20),
                  AppTextField(
                    label: 'Delivery Time Slot',
                    hint: 'e.g. Morning (6:00 AM - 9:00 AM)',
                    controller: _deliverySlotController,
                    prefixIcon: const Icon(Icons.schedule_rounded,
                        color: AppColors.primaryBlue),
                    validator: AppValidators.validateRequired,
                    onChanged: (v) => _deliveryTimeSlot = v,
                  ),
                  const SizedBox(height: AppSizes.p20),
                  SwitchListTile(
                    value: _includeIcePack,
                    onChanged: (v) => setState(() => _includeIcePack = v),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primaryBlue,
                    title: const Text(
                      'Include ice pack for freshness',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p24),
                  _buildPricingPreview(product, quantity),
                  const SizedBox(height: AppSizes.p24),
                  AppButton(
                    text: _isNew ? 'Create Subscription' : 'Save Changes',
                    onPressed: () => _onSave(availableProducts),
                  ),
                  const SizedBox(height: AppSizes.p24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductSelector(List<Product> products, Product currentProduct) {
    final selectedId = products.any((p) => p.id == currentProduct.id)
        ? currentProduct.id
        : products.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Product',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.p8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p12, vertical: AppSizes.p4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSizes.borderLarge,
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedId,
              items: products
                  .map((p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Row(
                          children: [
                            ProductImage(
                              imageUrl: p.imageUrl,
                              categoryKey: p.categoryId,
                              title: p.title,
                              size: 32,
                              radius: 6,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${p.unit.isNotEmpty ? p.unit : "1 pc"} • ${p.categoryName.isNotEmpty ? p.categoryName : p.categoryId}',
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
                            Text(
                              '₹${p.price.toStringAsFixed(p.price.truncateToDouble() == p.price ? 0 : 2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) {
                  setState(() {
                    _chosenProduct = products.firstWhere(
                      (p) => p.id == id,
                      orElse: () => products.first,
                    );
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Frequency',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.p8),
        Wrap(
          spacing: AppSizes.p8,
          children: SubscriptionFrequency.values.map((f) {
            final selected = _selectedFrequency == f;
            return ChoiceChip(
              label: Text(f.label),
              selected: selected,
              selectedColor: AppColors.primaryBlue,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color:
                    selected ? AppColors.textOnPrimary : AppColors.textPrimary,
              ),
              onSelected: (_) => setState(() => _selectedFrequency = f),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPricingPreview(Product product, int quantity) {
    final validQty = quantity > 0 ? quantity : 1;
    final perDelivery = product.price * validQty;
    final discountRate = 0.10; // Standard 10% subscription recurring discount
    final discount = perDelivery * discountRate;
    final afterDiscount = (perDelivery - discount).clamp(0.0, double.infinity);
    final monthly = afterDiscount * _selectedFrequency.deliveriesPerMonth;

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
          const Text(
            'Pricing Preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          _pricingRow(
            'Unit price (${product.unit.isNotEmpty ? product.unit : "1 pc"})',
            '₹${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
          ),
          _pricingRow(
            'Qty per delivery',
            '$validQty',
          ),
          _pricingRow(
            'Subtotal per delivery',
            '₹${perDelivery.toStringAsFixed(2)}',
          ),
          _pricingRow(
            'Subscription discount (10%)',
            '-₹${discount.toStringAsFixed(2)}',
            valueColor: AppColors.freshGreen,
          ),
          _pricingRow(
            'After discount',
            '₹${afterDiscount.toStringAsFixed(2)}',
            valueColor: AppColors.primaryBlue,
            bold: true,
          ),
          const SizedBox(height: AppSizes.p8),
          _pricingRow(
            'Est. monthly (${_selectedFrequency.label})',
            '₹${monthly.toStringAsFixed(0)}',
            valueColor: AppColors.textPrimary,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
