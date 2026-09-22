import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../models/product.dart';
import 'price_text.dart';
import 'quantity_selector.dart';
import 'app_network_image.dart';

/// Modern Production Responsive Product Card matching Native Mobile Quick-Commerce UX
class ProductCard extends StatefulWidget {
  final Product product;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.quantity = 0,
    this.onIncrement,
    this.onDecrement,
    this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final origPrice = p.originalPrice;
    final hasDiscount = origPrice != null && origPrice > p.price && origPrice > 0;
    final discountPercent = (hasDiscount && origPrice != null && origPrice > 0)
        ? (((origPrice - p.price) / origPrice) * 100).round()
        : 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF0F4A2F)
                : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color(0xFF0F4A2F).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Header with Discount Badges
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Builder(builder: (context) {
                                final image = p.resolvedImageUrl.trim();
                                if (image.isEmpty) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 32,
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                }
                                if (image.startsWith('http://') ||
                                    image.startsWith('https://')) {
                                  return AppNetworkImage(
                                    imageUrl: image,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 32,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }
                                return Image.asset(
                                  image,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 32,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),

                      // Discount Badge
                      if (hasDiscount && discountPercent > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '${discountPercent}% OFF',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Product Info & Quantity Actions
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unit Tag pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.unit.isNotEmpty ? p.unit : 'Standard',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Product Title
                      Text(
                        p.title.isEmpty ? 'Product' : p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price & Add Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: PriceText(
                              price: p.price,
                              originalPrice: p.originalPrice,
                              priceFontSize: 15,
                              originalPriceFontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          QuantitySelector(
                            quantity: widget.quantity,
                            onIncrement: widget.onIncrement ?? () {},
                            onDecrement: widget.onDecrement ?? () {},
                            height: 30,
                            width: widget.quantity == 0 ? 64 : 78,
                          ),
                        ],
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
