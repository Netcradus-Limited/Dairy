import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/product_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/firebase_storage_service.dart';
import '../../core/widgets/app_network_image.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final bgColor = AppColors.bgOf(context);

    if (provider.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading products from Firestore...',
                style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filteredProducts = provider.products.where((p) {
      if (provider.searchQuery.isEmpty) return true;
      final q = provider.searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.subtitle.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Text(
              'Dairy Products & Inventory',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Configure milk varieties, fat content, packaging, and stock levels.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('add_product_button'),
                onPressed: () => _showProductDialog(context, provider, null),
                icon: const Icon(Icons.add_box_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Add Product',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dairy Products & Inventory',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Configure milk varieties, fat content, packaging, and stock levels.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  key: const Key('add_product_button'),
                  onPressed: () => _showProductDialog(context, provider, null),
                  icon: const Icon(Icons.add_box_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Add Product',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          filteredProducts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No products found in catalog.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add products from the button above to get started.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredProducts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop
                        ? 3
                        : (ResponsiveLayout.isTablet(context) ? 2 : 1),
                    mainAxisExtent: 230,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (ctx, idx) {
                    final product = filteredProducts[idx];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                alignment: Alignment.center,
                                clipBehavior: Clip.antiAlias,
                                child: Builder(builder: (context) {
                                  final image = product.resolvedImageUrl.trim();
                                  if (image.isEmpty) {
                                    return Text(
                                      product.emoji,
                                      style: const TextStyle(fontSize: 22),
                                    );
                                  }
                                  Widget img;
                                  if (image.startsWith('http://') ||
                                      image.startsWith('https://')) {
                                    img = AppNetworkImage(
                                      imageUrl: image,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        debugPrint(
                                            'ProductsScreen: Image failed for "$image": $error');
                                        return Container(
                                          width: 44,
                                          height: 44,
                                          color: AppColors.cardBorder
                                              .withValues(alpha: 0.2),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            size: 20,
                                            color: AppColors.textMuted,
                                          ),
                                        );
                                      },
                                    );
                                  } else if (image.startsWith('assets/')) {
                                    img = Image.asset(
                                      image,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        debugPrint(
                                            'ProductsScreen: Image.asset failed for "$image": $error');
                                        return Text(
                                          product.emoji,
                                          style: const TextStyle(fontSize: 22),
                                        );
                                      },
                                    );
                                  } else {
                                    final fallback = AppAssets.productImage(
                                        categoryKey: product.category);
                                    img = (fallback != null &&
                                            fallback.startsWith('assets/'))
                                        ? Image.asset(fallback,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover)
                                        : Text(
                                            product.emoji,
                                            style:
                                                const TextStyle(fontSize: 22),
                                          );
                                  }
                                  return img;
                                }),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      product.subtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  product.isBestSeller
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 20,
                                  color: product.isBestSeller
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.textMuted,
                                ),
                                tooltip: product.isBestSeller
                                    ? 'Remove Best Seller'
                                    : 'Mark as Best Seller',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 30, minHeight: 30),
                                onPressed: () =>
                                    provider.toggleBestSeller(product.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.primary),
                                tooltip: 'Edit Product',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 30, minHeight: 30),
                                onPressed: () => _showProductDialog(
                                    context, provider, product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Color(0xFFEF4444)),
                                tooltip: 'Delete Product',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 30, minHeight: 30),
                                onPressed: () => _showDeleteConfirmation(
                                    context, provider, product),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildBadge(product.category, AppColors.primary),
                              if (product.fatContent.isNotEmpty)
                                _buildBadge(product.fatContent,
                                    AppColors.statusPreparing),
                              if (product.isBestSeller)
                                _buildBadge(
                                    'Best Seller', const Color(0xFFF59E0B)),
                            ],
                          ),
                          const Spacer(),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currencyFormatter.format(product.price),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Stock: ${product.stockQuantity} ${product.unit}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Text(
                                    product.inStock ? 'In Stock' : 'Out',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: product.inStock
                                          ? AppColors.revenueGreen
                                          : AppColors.statusCancelled,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: product.inStock,
                                      activeThumbColor: AppColors.revenueGreen,
                                      activeTrackColor: AppColors.revenueGreen
                                          .withValues(alpha: 0.3),
                                      onChanged: (val) => provider
                                          .toggleProductStock(product.id),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static const List<Map<String, String>> _productImages = [
    {'label': 'Milk', 'path': AppAssets.milkPng},
    {'label': 'Paneer', 'path': AppAssets.paneerPng},
    {'label': 'Ghee', 'path': AppAssets.gheePng},
    {'label': 'Lassi', 'path': AppAssets.lassiPng},
    {'label': 'Makhan', 'path': AppAssets.makhanPng},
    {'label': 'Uple', 'path': AppAssets.uplePng},
    {'label': 'Water', 'path': AppAssets.waterPng},
  ];

  void _showProductDialog(
      BuildContext context, AdminProvider provider, DairyProduct? existing) {
    final isEdit = existing != null;
    final prodId =
        existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? '${existing.price.toInt()}' : '65');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '1 Litre');
    final fatCtrl =
        TextEditingController(text: existing?.fatContent ?? '3.5% Fat');
    final stockCtrl =
        TextEditingController(text: '${existing?.stockQuantity ?? 100}');
    final categoryCtrl =
        TextEditingController(text: existing?.category ?? 'Milk & Creams');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🥛');

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        bool isUploadingImage = false;
        String selectedImageUrl = existing?.imageUrl ?? '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isNarrow = MediaQuery.sizeOf(ctx).width < 500;
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Edit Dairy Product' : 'Add Dairy Product',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: math.min(440.0, MediaQuery.sizeOf(ctx).width - 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Product Image Selector ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Product Image',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: isUploadingImage
                                ? null
                                : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1024,
                                        maxHeight: 1024,
                                        imageQuality: 85,
                                      );
                                      if (picked == null) return;

                                      setDialogState(
                                          () => isUploadingImage = true);
                                      final bytes = await picked.readAsBytes();

                                      final downloadUrl =
                                          await FirebaseStorageService.instance
                                              .uploadProductImage(
                                                  productId: prodId,
                                                  bytes: bytes);

                                      setDialogState(() {
                                        selectedImageUrl = downloadUrl;
                                        isUploadingImage = false;
                                      });

                                      // If editing an existing product, persist imageUrl immediately to Firestore
                                      if (existing != null) {
                                        final updated = existing.copyWith(
                                            imageUrl: downloadUrl);
                                        await provider.updateProduct(updated);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Product image uploaded successfully!'),
                                            backgroundColor:
                                                AppColors.freshGreen,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(
                                          () => isUploadingImage = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to upload image: ${e.toString().replaceAll("Exception: ", "")}',
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isUploadingImage
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined,
                                    size: 16, color: AppColors.primary),
                            label: Text(
                              isUploadingImage
                                  ? 'Uploading...'
                                  : 'Upload Image',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isUploadingImage)
                        Container(
                          height: 90,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                  color: AppColors.primary),
                              const SizedBox(height: 8),
                              Text(
                                'Uploading to Firebase Storage...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (selectedImageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (selectedImageUrl
                                      .trim()
                                      .startsWith('http://') ||
                                  selectedImageUrl
                                      .trim()
                                      .startsWith('https://'))
                              ? AppNetworkImage(
                                  imageUrl: selectedImageUrl.trim(),
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 90,
                                      width: double.infinity,
                                      color: AppColors.background,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.primary),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 90,
                                    width: double.infinity,
                                    color: AppColors.background,
                                    child: const Icon(Icons.image_not_supported,
                                        color: AppColors.textMuted),
                                  ),
                                )
                              : Image.asset(
                                  AppAssets.productImage(
                                        imageUrl: selectedImageUrl,
                                        categoryKey: categoryCtrl.text,
                                        productTitle: nameCtrl.text,
                                      ) ??
                                      AppAssets.milkPng,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 90,
                                    width: double.infinity,
                                    color: AppColors.background,
                                    child: const Icon(Icons.image_not_supported,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Or choose a preset dairy product image:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _productImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final img = _productImages[index];
                            final isSelected = selectedImageUrl == img['path'];
                            return GestureDetector(
                              onTap: () => setDialogState(
                                  () => selectedImageUrl = img['path']!),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.cardBorder,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(6),
                                    child: Image.asset(
                                      img['path']!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.image,
                                                  color: AppColors.textMuted),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    img['label']!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Existing fields ──
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Product Name (e.g. Pure Cow Milk 1L)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Subtitle / Description'),
                      ),
                      const SizedBox(height: 12),
                      if (isNarrow) ...[
                        TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Price (₹)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Stock Quantity'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Unit (e.g. 500ml, 1L)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: fatCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Fat % (e.g. 4.5% Fat)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: categoryCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emojiCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Emoji Icon'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Price (₹)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Stock Quantity'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Unit (e.g. 500ml, 1L)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: fatCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Fat % (e.g. 4.5% Fat)'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: categoryCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Category'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: emojiCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Emoji Icon'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a product name'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          if (!isEdit && selectedImageUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a product image'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            if (isEdit) {
                              await provider.updateProduct(
                                existing.copyWith(
                                  name: nameCtrl.text.trim(),
                                  subtitle: subtitleCtrl.text.trim(),
                                  price: double.tryParse(priceCtrl.text) ??
                                      existing.price,
                                  stockQuantity: int.tryParse(stockCtrl.text) ??
                                      existing.stockQuantity,
                                  unit: unitCtrl.text.trim(),
                                  fatContent: fatCtrl.text.trim(),
                                  category: categoryCtrl.text.trim(),
                                  emoji: emojiCtrl.text.trim().isEmpty
                                      ? '🥛'
                                      : emojiCtrl.text.trim(),
                                  imageUrl: selectedImageUrl,
                                ),
                              );
                            } else {
                              await provider.addProduct(
                                DairyProduct(
                                  id: prodId,
                                  name: nameCtrl.text.trim(),
                                  subtitle: subtitleCtrl.text.trim().isEmpty
                                      ? fatCtrl.text.trim()
                                      : subtitleCtrl.text.trim(),
                                  category: categoryCtrl.text.trim().isEmpty
                                      ? 'Milk & Creams'
                                      : categoryCtrl.text.trim(),
                                  unit: unitCtrl.text.trim().isEmpty
                                      ? '1 Litre'
                                      : unitCtrl.text.trim(),
                                  price:
                                      double.tryParse(priceCtrl.text) ?? 60.0,
                                  stockQuantity:
                                      int.tryParse(stockCtrl.text) ?? 100,
                                  fatContent: fatCtrl.text.trim().isEmpty
                                      ? '3.5% Fat'
                                      : fatCtrl.text.trim(),
                                  packaging: 'Fresh Pouch',
                                  emoji: emojiCtrl.text.trim().isEmpty
                                      ? '🥛'
                                      : emojiCtrl.text.trim(),
                                  imageUrl: selectedImageUrl,
                                ),
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Product "${nameCtrl.text}" updated successfully!'
                                        : 'Product "${nameCtrl.text}" added to catalog!',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            debugPrint('Product save failed: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save product: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Add Product',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, AdminProvider provider, DairyProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Product',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${product.name}" from your product inventory?',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await provider.deleteProduct(product.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Product "${product.name}" removed.'),
                      backgroundColor: AppColors.revenueGreen,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete product: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
