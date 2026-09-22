import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_assets.dart';
import '../../core/responsive/responsive.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/price_text.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/widgets/app_network_image.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../checkout/checkout_screen.dart';

/// Sawariya Dairy Phase 5 & 6 — Product Details Screen
class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  bool _isFavorite = false;
  int _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(product.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isFavorite
                      ? 'Added ${product.title} to Favorites'
                      : 'Removed from Favorites'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
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
          padding: EdgeInsets.zero,
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Big Image Banner
                    Expanded(
                      flex: 1,
                      child: _buildImageSection(product),
                    ),
                    const SizedBox(width: AppSizes.p32),

                    // Right: Info & Actions
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderInfo(product),
                          const SizedBox(height: AppSizes.p16),
                          _buildPriceSection(product),
                          const SizedBox(height: AppSizes.p20),
                          _buildQuantityAndCart(ref, product),
                          const SizedBox(height: AppSizes.p24),
                          _buildFeaturesAndDescription(product),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageSection(product),
                    const SizedBox(height: AppSizes.p20),
                    _buildHeaderInfo(product),
                    const SizedBox(height: AppSizes.p16),
                    _buildPriceSection(product),
                    const SizedBox(height: AppSizes.p20),
                    _buildQuantityAndCart(ref, product),
                    const SizedBox(height: AppSizes.p24),
                    _buildFeaturesAndDescription(product),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildImageSection(Product product) {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppSizes.borderLarge,
        child: Stack(
          children: [
            // Full ratio product image occupying the image section (4:5 ratio)
            Positioned.fill(
              child: Container(
                color: AppColors.lightBlue.withValues(alpha: 0.15),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Builder(builder: (context) {
                      final image = product.resolvedImageUrl.trim();
                      if (image.isEmpty) {
                        return Container(
                          color: AppColors.lightBlue,
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      Widget img;
                      if (image.startsWith('http://') ||
                          image.startsWith('https://')) {
                        img = AppNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(
                                'ProductDetailsScreen: Image failed for "$image": $error');
                            return Container(
                              color: AppColors.lightBlue,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        );
                      } else if (image.startsWith('assets/')) {
                        img = Image.asset(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(
                                'ProductDetailsScreen: Image.asset failed for "$image": $error');
                            return Container(
                              color: AppColors.lightBlue,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        final fallback = AppAssets.productImage(
                            categoryKey: product.categoryId);
                        img =
                            (fallback != null && fallback.startsWith('assets/'))
                                ? Image.asset(fallback, fit: BoxFit.contain)
                                : Container(
                                    color: AppColors.lightBlue,
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 48,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                      }
                      return img;
                    }),
                  ),
                ),
              ),
            ),

            // Top Badges Row
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (product.hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.discountTag,
                        borderRadius: AppSizes.borderSmall,
                        boxShadow: AppColors.cardShadowSm,
                      ),
                      child: Text(
                        '${product.discountPercentage}% OFF',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (product.isA2CowMilk)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.freshGreen,
                        borderRadius: AppSizes.borderSmall,
                        boxShadow: AppColors.cardShadowSm,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              size: 14, color: AppColors.textOnPrimary),
                          SizedBox(width: 4),
                          Text(
                            'A2 PURE',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Guaranteed Fresh Floating Badge
            Positioned(
              bottom: 12,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: AppSizes.borderSmall,
                  border: Border.all(color: AppColors.border, width: 0.8),
                  boxShadow: AppColors.cardShadowSm,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.primaryBlue),
                    SizedBox(width: 5),
                    Text(
                      '100% Farm Fresh Guaranteed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: const BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: AppSizes.borderSmall,
          ),
          child: Text(
            product.categoryName.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 4),
                Text(
                  '${product.rating}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${product.reviewCount} reviews)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSizes.borderSmall,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Pack: ${product.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection(Product product) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderMedium,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Price (Inclusive of all taxes)',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                PriceText(
                  price: product.price,
                  originalPrice: product.originalPrice,
                  priceFontSize: 22,
                ),
              ],
            ),
          ),
          if (product.hasDiscount)
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.freshGreen.withValues(alpha: 0.1),
                  borderRadius: AppSizes.borderSmall,
                  border: Border.all(
                      color: AppColors.freshGreen.withValues(alpha: 0.3)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Save ₹${(product.originalPrice! - product.price).toStringAsFixed(0)} today!',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.freshGreen,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToCart(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    try {
      context.push('/cart');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    }
  }

  void _navigateToCheckout(BuildContext context) {
    try {
      context.push('/checkout');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const CheckoutScreen(),
        ),
      );
    }
  }

  Widget _buildQuantityAndCart(WidgetRef ref, Product product) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Select Quantity:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p12),
            QuantitySelector(
              quantity: _selectedQuantity,
              onIncrement: () {
                setState(() => _selectedQuantity++);
              },
              onDecrement: () {
                if (_selectedQuantity > 1) {
                  setState(() => _selectedQuantity--);
                }
              },
              height: 38,
              width: 110,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.p16),
        Row(
          children: [
            // Add to Cart Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final qtyToAdd = _selectedQuantity;
                    ref.read(cartProvider.notifier).addItem(product, qtyToAdd);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          qtyToAdd == 1
                              ? 'Added ${product.title} to your Cart!'
                              : 'Added $qtyToAdd x ${product.title} to your Cart!',
                        ),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'VIEW CART',
                          textColor: AppColors.ratingStar,
                          onPressed: () {
                            _navigateToCart(context);
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Add to Cart',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(
                        color: AppColors.primaryBlue, width: 1.5),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSizes.borderMedium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p12),

            // Buy Now Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final buyNowQuantity = _selectedQuantity;
                    ref
                        .read(cartProvider.notifier)
                        .setItemQuantity(product, buyNowQuantity);
                    _navigateToCheckout(context);
                  },
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Buy Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturesAndDescription(Product product) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Description & Quality Standards',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description.isNotEmpty
                ? product.description
                : 'Sawariya Dairy products are harvested and processed under strict hygienic conditions. Guaranteed 100% natural without any added preservatives or adulterants.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quality Highlights:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _bulletPoint('FSSAI certified food grade packaging'),
          _bulletPoint('Zero preservatives & zero artificial colors'),
          _bulletPoint('Chilled cold-chain delivery within 2 hours of packing'),
          _bulletPoint(
              'Directly sourced from Gir Cow & Organic Sawariya Dairy farms'),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.freshGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
