import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/product_provider.dart';
import '../cart/cart_screen.dart';
import '../product/product_details_screen.dart';

/// Sawariya Dairy — Redesigned Shop Catalog Screen matching the mockup
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _videoHasError = false;

  final CarouselSliderController _middleCarouselController =
      CarouselSliderController();
  int _middleBannerIndex = 0;

  final List<String> _middleBanners = [
    'assets/images/1.png',
    'assets/images/2.png',
    'assets/images/3.png',
  ];

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/images/orderv.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoController.initialize().then((_) async {
      if (!mounted) return;
      await _videoController.setVolume(0.0);
      await _videoController.setLooping(true);
      try {
        await _videoController.play();
      } catch (e) {
        debugPrint('Shop video autoplay prevented: $e');
      }
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    }).catchError((e) {
      debugPrint('Error initializing shop video: $e');
      if (mounted) {
        setState(() {
          _videoHasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    ref.read(productSearchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = 'cat_all';
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(allProductsProvider);
    final cartQuantities = ref.watch(cartQuantitiesProvider);
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);

    final categoriesAsync = ref.watch(categoriesProvider);
    final firestoreCategories = categoriesAsync.valueOrNull ?? [];

    // Dynamically build category options starting with "All"
    final categoryOptions = <Map<String, String>>[
      {
        'id': 'cat_all',
        'title': 'All',
        'image': 'assets/images/all.png',
        'description':
            'Browse our entire range of premium, farm-fresh dairy products.'
      },
      ...firestoreCategories.map((c) => {
            'id': c.id,
            'title': c.title,
            'image': c.resolvedImageUrl.isNotEmpty
                ? c.resolvedImageUrl
                : (c.imageUrl.isNotEmpty ? c.imageUrl : 'assets/images/doodh.png'),
            'description': c.subtitle.isNotEmpty
                ? c.subtitle
                : 'Fresh and premium ${c.title} products delivered daily.',
          }),
    ];

    // Find the currently selected category title for dynamic headers
    final selectedCat = categoryOptions.firstWhere(
      (cat) => cat['id'] == selectedCategoryId,
      orElse: () => {
        'id': 'cat_all',
        'title': 'All',
        'image': 'assets/images/all.png',
        'description':
            'Browse our entire range of premium, farm-fresh dairy products.'
      },
    );

    // Filter products by category and search query
    final selectedTitle = (selectedCat['title'] ?? '').toLowerCase();
    final filteredProducts = allProducts.where((product) {
      bool matchesCategory = false;
      if (selectedCategoryId == 'cat_all') {
        matchesCategory = true;
      } else if (selectedCategoryId == 'cat_milk') {
        matchesCategory = product.categoryId == 'cat_milk';
      } else if (selectedCategoryId == 'cat_paneer') {
        matchesCategory = product.categoryId == 'cat_paneer' &&
            !product.title.toLowerCase().contains('butter') &&
            !product.title.toLowerCase().contains('makhan');
      } else if (selectedCategoryId == 'cat_ghee') {
        matchesCategory = product.categoryId == 'cat_ghee' ||
            product.title.toLowerCase().contains('ghee');
      } else if (selectedCategoryId == 'cat_lassi') {
        matchesCategory = product.categoryId == 'cat_lassi' ||
            product.categoryId == 'cat_curd' ||
            product.title.toLowerCase().contains('lassi') ||
            product.title.toLowerCase().contains('dahi');
      } else if (selectedCategoryId == 'cat_makhan') {
        matchesCategory = product.categoryId == 'cat_makhan' ||
            product.title.toLowerCase().contains('butter') ||
            product.title.toLowerCase().contains('makhan');
      } else if (selectedCategoryId == 'cat_uple') {
        matchesCategory = product.categoryId == 'cat_uple' ||
            product.title.toLowerCase().contains('uple') ||
            product.title.toLowerCase().contains('dung');
      } else if (selectedCategoryId == 'cat_water') {
        matchesCategory = product.categoryId == 'cat_water' ||
            product.title.toLowerCase().contains('water');
      } else {
        matchesCategory = product.categoryId == selectedCategoryId ||
            (selectedTitle.isNotEmpty &&
                product.categoryName.toLowerCase() == selectedTitle);
      }

      final matchesSearch = searchQuery.isEmpty ||
          product.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          product.categoryName
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Shop Title Row with Cart Icon (on Mobile/Tablet) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shop',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF005F38),
                    ),
                  ),
                  if (isMobile)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF172033),
                            size: 24,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CartScreen()),
                            );
                          },
                        ),
                        if (ref.watch(cartItemCountProvider) > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E6BFF),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${ref.watch(cartItemCountProvider)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Promotional Banner ──
              _buildPromoBanner(),
              const SizedBox(height: 16),
              // ── Horizontal Categories Row ──
              SizedBox(
                height: 125,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = categoryOptions[index];
                      final isSelected = cat['id'] == selectedCategoryId;

                      // Color mapping matching mockups
                      Color getBorderColor(String? id) {
                        switch (id) {
                          case 'cat_milk':
                            return const Color(0xFF5B9BD5);
                          case 'cat_ghee':
                            return const Color(0xFFEDC240);
                          case 'cat_lassi':
                            return const Color(0xFFD38B27);
                          case 'cat_makhan':
                            return const Color(0xFFF2D16D);
                          case 'cat_paneer':
                            return const Color(0xFF70AD47);
                          default:
                            return const Color(0xFF005F38);
                        }
                      }

                      Color getBgColor(String? id) {
                        switch (id) {
                          case 'cat_milk':
                            return const Color(0xFFEAF5FF);
                          case 'cat_ghee':
                            return const Color(0xFFFFF9EE);
                          case 'cat_lassi':
                            return const Color(0xFFEBF3FE);
                          case 'cat_makhan':
                            return const Color(0xFFF0F9F4);
                          case 'cat_paneer':
                            return const Color(0xFFFFF5EA);
                          default:
                            return const Color(0xFFEAF5EF);
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          ref.read(selectedCategoryProvider.notifier).state =
                              cat['id'] ?? 'cat_all';
                          _showCategoryPopup(context, cat);
                        },
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: isSelected ? 1.08 : 0.95,
                          child: SizedBox(
                            width: 80,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 76,
                                  width: 76,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: getBgColor(cat['id']),
                                    border: Border.all(
                                      color:
                                          getBorderColor(cat['id']),
                                      width: isSelected ? 3.0 : 1.5,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: getBorderColor(
                                                  cat['id'])
                                              .withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      else
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: (cat['image'] ?? '').startsWith('http')
                                            ? Image.network(
                                                cat['image'] ?? '',
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.grid_view_rounded,
                                                    color: AppColors.primary,
                                                    size: 32,
                                                  );
                                                },
                                              )
                                            : Image.asset(
                                                cat['image'] ?? '',
                                                fit: cat['id'] == 'cat_all'
                                                    ? BoxFit.cover
                                                    : BoxFit.contain,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.grid_view_rounded,
                                                    color: AppColors.primary,
                                                    size: 32,
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat['id'] == 'cat_all'
                                      ? 'ALL'
                                      : (cat['title'] ?? ''),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF005F38)
                                        : const Color(0xFF667085),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Dynamic Title Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedCategoryId == 'cat_all'
                        ? 'Products'
                        : '${selectedCat['title']} Products',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Products Grid ──
              filteredProducts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: EmptyStateWidget(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          message:
                              'No products match your filter. Try adjusting or reset.',
                          buttonText: 'Reset Filters',
                          onButtonPressed: _resetFilters,
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: isMobile
                            ? (MediaQuery.sizeOf(context).width < 380
                                ? 0.68
                                : 0.72)
                            : 0.79,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final qty = cartQuantities[product.id] ?? 0;

                        return ProductCard(
                          product: product,
                          quantity: qty,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailsScreen(product: product),
                              ),
                            );
                          },
                          onIncrement: () {
                            ref.read(cartProvider.notifier).increment(product);
                          },
                          onDecrement: () {
                            ref
                                .read(cartProvider.notifier)
                                .decrement(product.id);
                          },
                        );
                      },
                    ),
              const SizedBox(height: 24),

              // ── Middle Promotional Banners ──
              _buildMiddlePromoBanner(),
              const SizedBox(height: 8),

              // Middle Banner Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_middleBanners.length, (index) {
                  final isActive = index == _middleBannerIndex;
                  return GestureDetector(
                    onTap: () {
                      _middleCarouselController.animateToPage(index);
                      setState(() => _middleBannerIndex = index);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isActive ? 12 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF005F38)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // ── Bottom Benefits Strip ──
              _buildBenefitsRow(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 2.0,
          child: (_videoController.value.hasError || _videoHasError)
              ? Container(
                  color: const Color(0xFF005F38),
                  child: Image.asset(
                    'assets/images/1.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.play_circle_outline,
                          size: 48, color: Colors.white),
                    ),
                  ),
                )
              : (!_isVideoInitialized
                  ? Container(
                      color: const Color(0xFF005F38),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _buildMiddlePromoBanner() {
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    return CarouselSlider(
      carouselController: _middleCarouselController,
      options: CarouselOptions(
        aspectRatio: 1764 / 608,
        viewportFraction: 1.0,
        autoPlay: !isTest,
        autoPlayInterval: const Duration(seconds: 4),
        enlargeCenterPage: false,
        onPageChanged: (index, reason) {
          setState(() {
            _middleBannerIndex = index;
          });
        },
      ),
      items: _middleBanners.map((imagePath) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF005F38),
                  alignment: Alignment.center,
                  child: const Text(
                    'Sawariya Dairy Special',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBenefitsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _BenefitItem(
            icon: Icons.verified_user_outlined,
            title: '100% Pure',
            subtitle: 'No Additives',
          ),
          _BenefitItem(
            icon: Icons.eco_outlined,
            title: 'Farm Fresh',
            subtitle: 'Daily Collection',
          ),
          _BenefitItem(
            icon: Icons.local_shipping_outlined,
            title: 'Safe Delivery',
            subtitle: 'Hygienic Packing',
          ),
          _BenefitItem(
            icon: Icons.payment_outlined,
            title: 'Secure Payment',
            subtitle: '100% Safe',
          ),
        ],
      ),
    );
  }

  void _showCategoryPopup(BuildContext context, Map<String, String> cat) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top header close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF667085)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 8),
                // Category image with beautiful container background
                if ((cat['image'] ?? '').isNotEmpty)
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: (cat['image'] ?? '').startsWith('http')
                        ? Image.network(
                            cat['image'] ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.grid_view_rounded,
                              color: AppColors.primary,
                              size: 44,
                            ),
                          )
                        : Image.asset(
                            cat['image'] ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.grid_view_rounded,
                              color: AppColors.primary,
                              size: 44,
                            ),
                          ),
                  )
                else
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'All',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Title
                Text(
                  cat['title']!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  cat['description']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Explore Products button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Explore Products',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF005F38), size: 16),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 7.5,
            color: Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}
