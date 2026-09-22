import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/category_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/firebase_storage_service.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<Map<String, String>> _categoryPresets = [
    {'label': 'Milk', 'path': AppAssets.milkCategory},
    {'label': 'Paneer', 'path': AppAssets.paneerCategory},
    {'label': 'Ghee', 'path': AppAssets.gheeCategory},
    {'label': 'Lassi', 'path': AppAssets.lassiCategory},
    {'label': 'Makhan', 'path': AppAssets.makhanCategory},
    {'label': 'Uple', 'path': AppAssets.upleCategory},
    {'label': 'Water', 'path': AppAssets.waterCategory},
    {'label': 'All', 'path': 'assets/images/all.png'},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final bgColor = AppColors.bgOf(context);

    if (provider.isLoading && provider.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading categories from Firestore...',
                style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

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
              'Product Categories',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Categorize fresh dairy items, daily morning batches, and retail dairy products.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('add_category_button'),
                onPressed: () => _showCategoryDialog(context, provider, null),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Add Category',
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
                        'Product Categories',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Categorize fresh dairy items, daily morning batches, and retail dairy products.',
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
                  key: const Key('add_category_button'),
                  onPressed: () => _showCategoryDialog(context, provider, null),
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      size: 18, color: Colors.white),
                  label: Text(
                    'Add Category',
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
              ],
            ),
          ],
          const SizedBox(height: 20),
          provider.categories.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No categories yet.',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first category to organize products.',
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
                  itemCount: provider.categories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop
                        ? 3
                        : (ResponsiveLayout.isTablet(context) ? 2 : 1),
                    mainAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (ctx, idx) {
                    final cat = provider.categories[idx];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cat.isActive ? cardBorder : cardBorder.withValues(alpha: 0.5),
                        ),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Builder(
                                  builder: (context) {
                                    final image = cat.resolvedImageUrl.trim();
                                    if (image.isEmpty) {
                                      return Text(
                                        cat.emoji,
                                        style: const TextStyle(fontSize: 22),
                                      );
                                    }
                                    if (image.startsWith('http://') ||
                                        image.startsWith('https://')) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          image,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                            cat.emoji,
                                            style: const TextStyle(fontSize: 22),
                                          ),
                                        ),
                                      );
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        image,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          cat.emoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: cardBorder),
                                          ),
                                          child: Text(
                                            '${cat.productCount} Products',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: cat.isActive
                                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                : Colors.grey.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            cat.isActive ? 'Active' : 'Inactive',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: cat.isActive
                                                  ? const Color(0xFF059669)
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: AppColors.primary),
                                    tooltip: 'Edit Category',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 26, minHeight: 26),
                                    onPressed: () =>
                                        _showCategoryDialog(context, provider, cat),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        size: 18, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete Category',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 26, minHeight: 26),
                                    onPressed: () => _showDeleteConfirmation(
                                        context, provider, cat),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (cat.sortOrder > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${cat.sortOrder}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              cat.description,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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

  void _showCategoryDialog(
      BuildContext context, AdminProvider provider, DairyCategory? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🥛');
    final countCtrl =
        TextEditingController(text: '${existing?.productCount ?? 0}');
    final sortOrderCtrl =
        TextEditingController(text: '${existing?.sortOrder ?? 0}');

    showDialog(
      context: context,
      builder: (ctx) {
        String selectedImageUrl = existing?.imageUrl ?? '';
        bool isUploadingImage = false;
        bool isActive = existing?.isActive ?? true;
        String? errorMessage;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isNarrow = MediaQuery.sizeOf(ctx).width < 500;
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 24.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEdit ? 'Update Category' : 'Add New Category',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: math.min(440.0, MediaQuery.sizeOf(ctx).width - 32),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Category Image Selector ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Category Image',
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
                                    final catId = existing?.id ??
                                        'cat_${DateTime.now().millisecondsSinceEpoch % 10000}';

                                    final downloadUrl =
                                        await FirebaseStorageService
                                            .instance
                                            .uploadCategoryImage(
                                                categoryId: catId,
                                                bytes: bytes);

                                    setDialogState(() {
                                      selectedImageUrl = downloadUrl;
                                      isUploadingImage = false;
                                    });

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Category image uploaded successfully!'),
                                          backgroundColor: AppColors.freshGreen,
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
                            isUploadingImage ? 'Uploading...' : 'Upload Image',
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
                        child: selectedImageUrl.startsWith('http')
                            ? Image.network(
                                selectedImageUrl,
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
                                AppAssets.categoryImage(
                                      imageUrl: selectedImageUrl,
                                      categoryKey: nameCtrl.text,
                                    ) ??
                                    AppAssets.milkCategory,
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
                      'Or choose a preset default category image:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categoryPresets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final img = _categoryPresets[index];
                          final isSelected = selectedImageUrl == img['path'];
                          return GestureDetector(
                            onTap: () => setDialogState(
                                () => selectedImageUrl = img['path']!),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
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
                                  padding: const EdgeInsets.all(4),
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
                                    fontSize: 9.5,
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
                    const SizedBox(height: 14),

                    // ── Form fields ──
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Category Name *',
                          hintText: 'e.g. Milk & Creams'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Short description of products'),
                    ),
                    const SizedBox(height: 12),
                    if (isNarrow) ...[
                      TextField(
                        controller: emojiCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Emoji Icon',
                            hintText: '🥛, 🧀, 🍯'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Product Count'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sortOrderCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Display Sort Order',
                            hintText: '0, 1, 2...'),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Active Status',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch(
                              value: isActive,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) {
                                setDialogState(() => isActive = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emojiCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Emoji Icon',
                                  hintText: '🥛, 🧀, 🍯'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: countCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Product Count'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sortOrderCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Display Sort Order',
                                  hintText: '0, 1, 2...'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.cardBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Active Status',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      setDialogState(() => isActive = val);
                                    },
                                  ),
                                ],
                              ),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = nameCtrl.text.trim();
                  if (trimmedName.isEmpty) {
                    setDialogState(() => errorMessage = 'Please enter a category name');
                    return;
                  }

                  // Check duplicate name
                  final duplicate = provider.categories.any((c) =>
                      (isEdit ? c.id != existing.id : true) &&
                      c.name.trim().toLowerCase() == trimmedName.toLowerCase());
                  if (duplicate) {
                    setDialogState(() => errorMessage =
                        'A category named "$trimmedName" already exists.');
                    return;
                  }

                  try {
                    if (isEdit) {
                      await provider.updateCategory(
                        existing.copyWith(
                          name: trimmedName,
                          description: descCtrl.text.trim(),
                          emoji: emojiCtrl.text.trim().isEmpty
                              ? '🥛'
                              : emojiCtrl.text.trim(),
                          productCount: int.tryParse(countCtrl.text) ??
                              existing.productCount,
                          imageUrl: selectedImageUrl,
                          isActive: isActive,
                          sortOrder: int.tryParse(sortOrderCtrl.text) ?? 0,
                          updatedAt: DateTime.now(),
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Category "$trimmedName" updated successfully!')),
                        );
                      }
                    } else {
                      final generatedId =
                          'cat_${trimmedName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
                      await provider.addCategory(
                        DairyCategory(
                          id: generatedId,
                          name: trimmedName,
                          description: descCtrl.text.trim(),
                          productCount: int.tryParse(countCtrl.text) ?? 0,
                          icon: Icons.category_rounded,
                          color: AppColors.primary,
                          emoji: emojiCtrl.text.trim().isEmpty
                              ? '🥛'
                              : emojiCtrl.text.trim(),
                          imageUrl: selectedImageUrl,
                          isActive: isActive,
                          sortOrder: int.tryParse(sortOrderCtrl.text) ?? 0,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Category "$trimmedName" added successfully!')),
                        );
                      }
                    }
                  } catch (e) {
                    setDialogState(() => errorMessage = e
                        .toString()
                        .replaceAll('Exception: ', '')
                        .replaceAll('Error: ', ''));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Create Category',
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
      BuildContext context, AdminProvider provider, DairyCategory category) {
    final hasProducts = provider.hasLinkedProducts(category.id);
    final linkedCount = provider.countLinkedProducts(category.id);

    if (hasProducts) {
      // Deletion is blocked because products reference this category
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cannot Delete Category',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category "${category.name}" cannot be deleted because $linkedCount product(s) are currently assigned to it.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'To prevent orphaned products in your store, please deactivate this category instead or reassign its products to another category.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (category.isActive)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await provider.toggleCategoryActive(category.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Category "${category.name}" has been deactivated.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.visibility_off_outlined,
                    size: 16, color: Colors.white),
                label: const Text('Deactivate Instead',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      );
      return;
    }

    // Standard deletion confirmation when no products are linked
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Category',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the category "${category.name}"? This action cannot be undone.',
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
              Navigator.pop(ctx);
              try {
                await provider.deleteCategory(category.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Category "${category.name}" deleted successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: const Color(0xFFEF4444),
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
