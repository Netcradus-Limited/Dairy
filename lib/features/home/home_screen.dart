import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' show PointerDeviceKind;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/localization/app_language.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/category_card.dart';
import '../../core/widgets/section_header.dart';
import '../../providers/product_provider.dart';
import '../../providers/navigation_provider.dart';

/// Sawariya Dairy — Pixel-Perfect Modern Home Screen
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _orderIdController = TextEditingController();

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // ─── 1. Quick Commerce Delivery Promise Pill ───
            _DeliveryPromisePill(
              onTap: () => ref.read(navigationProvider.notifier).setIndex(1),
            ),

            const SizedBox(height: 12),

            // ─── 2. Hero Banner (banner1v.mp4 Video Banner) ───
            _HeroPromotionalBanner(
              onTap: () => ref.read(navigationProvider.notifier).setIndex(1),
            ),

            const SizedBox(height: AppSizes.p20),

            // ─── 3. Categories Section ──────────────────────────────────────────
            categoriesAsync.when(
              loading: () => const SizedBox(
                height: 205,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF0F4A2F))),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: tr('Categories'),
                    subtitle: tr('Farm fresh dairy essentials delivered daily'),
                  ),
                  const SizedBox(height: AppSizes.p12),
                  SizedBox(
                    height: 205,
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
                        clipBehavior: Clip.none,
                        padding: EdgeInsets.zero,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: AppSizes.p14),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return CategoryCard(
                            category: cat,
                            width: isDesktop ? 195 : 170,
                            height: 205,
                            onTap: () {
                              ref
                                  .read(selectedCategoryProvider.notifier)
                                  .state = cat.id;
                              ref.read(navigationProvider.notifier).setIndex(1);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.p20),

            // ─── 3.5. Middle Promotional Banner (banner4 & banner5) ───────────────────
            const _CategoryPromotionalBanner(),

            const SizedBox(height: AppSizes.p20),

            // ─── 4. Bottom Split Row: Track Order & Freshness Banner ─────────────
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Track Your Order Card
                  Expanded(
                    flex: 5,
                    child: _TrackOrderCard(
                      controller: _orderIdController,
                      onTrackTap: () {
                        ref.read(navigationProvider.notifier).setIndex(2);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.p20),

                  // Right: Freshness You Can Trust Blue Banner
                  Expanded(
                    flex: 5,
                    child: _FreshnessBanner(
                      onExploreTap: () {
                        ref.read(navigationProvider.notifier).setIndex(1);
                      },
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _TrackOrderCard(
                    controller: _orderIdController,
                    onTrackTap: () {
                      ref.read(navigationProvider.notifier).setIndex(2);
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _FreshnessBanner(
                    onExploreTap: () {
                      ref.read(navigationProvider.notifier).setIndex(1);
                    },
                  ),
                ],
              ),

            const SizedBox(height: AppSizes.p20),

            // ─── Why Choose Us Banner ───
            const _WhyChooseUsVideo(),

            const SizedBox(height: 70), // Safe bottom clearance for floating cart
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Delivery Promise Pill
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryPromisePill extends StatelessWidget {
  final VoidCallback onTap;

  const _DeliveryPromisePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE6F4EA), Color(0xFFD1E7DD)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFB1D5C0),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F4A2F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.amber,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF0F4A2F),
                    ),
                    children: [
                      TextSpan(
                        text: tr('Next Morning Delivery: '),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: tr('6:00 AM – 7:30 AM • Order before 10 PM'),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF0F4A2F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Hero Promotional Banner ("Pure Goodness, Delivered to Your Doorstep")
// ─────────────────────────────────────────────────────────────────────────────

class _HeroPromotionalBanner extends StatefulWidget {
  final VoidCallback onTap;

  const _HeroPromotionalBanner({
    required this.onTap,
  });

  @override
  State<_HeroPromotionalBanner> createState() => _HeroPromotionalBannerState();
}

class _HeroPromotionalBannerState extends State<_HeroPromotionalBanner> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/images/homenew2v.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller.initialize().then((_) async {
      if (!mounted) return;
      await _controller.setVolume(0.0);
      await _controller.setLooping(true);
      try {
        await _controller.play();
      } catch (e) {
        debugPrint('Banner video autoplay prevented: $e');
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }).catchError((e) {
      debugPrint('Error initializing banner video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 2.0,
          child: GestureDetector(
            onTap: widget.onTap,
            child: (_controller.value.hasError || _hasError)
                ? Container(
                    color: Colors.grey[200],
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/banner1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.play_circle_outline,
                            size: 48, color: Color(0xFF005F38)),
                      ),
                    ),
                  )
                : (!_isInitialized
                    ? Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF005F38),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width > 0
                              ? _controller.value.size.width
                              : 16,
                          height: _controller.value.size.height > 0
                              ? _controller.value.size.height
                              : 9,
                          child: VideoPlayer(_controller),
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Track Order Card (Left bottom card)
// ─────────────────────────────────────────────────────────────────────────────

class _TrackOrderCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTrackTap;

  const _TrackOrderCard({required this.controller, required this.onTrackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E7F8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Track Your Order'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('Real-time updates on your fresh delivery'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Input + Track Button Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 0.9,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: tr('Enter your Order ID'),
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onTrackTap,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(110, 42),
                  backgroundColor: const Color(0xFF005F38),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  tr('Track Order'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Freshness You Can Trust Banner (Right bottom card)
// ─────────────────────────────────────────────────────────────────────────────

class _FreshnessBanner extends StatelessWidget {
  final VoidCallback onExploreTap;

  const _FreshnessBanner({required this.onExploreTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onExploreTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/home.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                color: const Color(0xFF005F38),
                alignment: Alignment.center,
                child: Text(
                  tr('Freshness You Can Trust'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Middle/Category Promotional Banner (1.png, 2.png, 3.png)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPromotionalBanner extends StatefulWidget {
  const _CategoryPromotionalBanner();

  @override
  State<_CategoryPromotionalBanner> createState() =>
      _CategoryPromotionalBannerState();
}

class _CategoryPromotionalBannerState
    extends State<_CategoryPromotionalBanner> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  final List<String> bannerImages = [
    'assets/images/1.png',
    'assets/images/2.png',
    'assets/images/3.png',
  ];

  @override
  Widget build(BuildContext context) {
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    return CarouselSlider(
      carouselController: _carouselController,
      options: CarouselOptions(
        aspectRatio: 1764 / 608,
        autoPlay: !isTest,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        enlargeCenterPage: false,
        viewportFraction: 1.0,
      ),
      items: bannerImages.map((imagePath) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF005F38),
                      alignment: Alignment.center,
                      child: Text(
                        tr('Sawariya Dairy Specials'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Why Choose Us Video Player Widget
// ─────────────────────────────────────────────────────────────────────────────

class _WhyChooseUsVideo extends StatefulWidget {
  const _WhyChooseUsVideo();

  @override
  State<_WhyChooseUsVideo> createState() => _WhyChooseUsVideoState();
}

class _WhyChooseUsVideoState extends State<_WhyChooseUsVideo> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/images/newhome2.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller.initialize().then((_) async {
      if (!mounted) return;
      await _controller.setVolume(0.0);
      await _controller.setLooping(true);
      try {
        await _controller.play();
      } catch (e) {
        debugPrint('Why choose us video autoplay prevented: $e');
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }).catchError((e) {
      debugPrint('Error initializing why video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
        child: (_controller.value.hasError || _hasError)
            ? Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/banner2.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.play_circle_outline,
                        size: 48, color: Color(0xFF005F38)),
                  ),
                ),
              )
            : (!_isInitialized
                ? Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF005F38),
                      ),
                    ),
                  )
                : VideoPlayer(_controller)),
      ),
    );
  }
}
