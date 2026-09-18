import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_language.dart';
import '../../core/responsive/responsive.dart';
import '../../providers/onboarding_provider.dart';
import '../auth/services/auth_video_service.dart';

/// Data Model for Onboarding Page Content
class OnboardingData {
  final String title;
  final String description;
  final String imageAsset;
  final bool showProductGrid;
  final Widget visualWidget;

  const OnboardingData({
    required this.title,
    required this.description,
    required this.imageAsset,
    this.showProductGrid = false,
    required this.visualWidget,
  });
}

/// Responsive Luxury Onboarding / Landing Experience for Sawariya Dairy
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Preload authentication videos early while user is on landing/onboarding
    AuthVideoService.instance.preload();
  }

  Future<void> _completeOnboarding() async {
    final service = ref.read(onboardingServiceProvider);
    await service.setOnboardingCompleted(true);
    if (!mounted) return;
    context.go('/login');
  }

  void _nextPage() {
    if (_currentPage < 2) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      } else {
        setState(() => _currentPage++);
      }
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final size = MediaQuery.of(context).size;

    final List<OnboardingData> pages = [
      OnboardingData(
        title: tr('Fresh Dairy, Every Day'),
        description: tr(
            'Enjoy fresh and quality dairy products delivered with care from Sawariya Dairy.'),
        imageAsset: AppAssets.landingHeroMilk,
        showProductGrid: false,
        visualWidget: const _DairyFreshVisual(),
      ),
      OnboardingData(
        title: tr('Pure Products, Trusted Quality'),
        description: tr(
            'Every product is sourced fresh, hygienically packed and quality-checked to bring you the best of Sawariya Dairy.'),
        imageAsset: AppAssets.landingHeroProducts,
        showProductGrid: true,
        visualWidget: const _DairyCollectionVisual(),
      ),
      OnboardingData(
        title: tr('Simple Shopping, Fresh Delivery'),
        description: tr(
            'Discover your favorite dairy products, order easily and enjoy freshness at your doorstep.'),
        imageAsset: AppAssets.landingHeroScooter,
        showProductGrid: false,
        visualWidget: const _DairyDeliveryVisual(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1B3B22),
      body: Stack(
        children: [
          // 1. Full-screen Lush Green Meadow Background
          Positioned.fill(
            child: Image.asset(
              AppAssets.landingBg,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // Ambient Background Blur & Light Softening Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ),
          ),

          // 2. Central Gold-Bordered Landing Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40.0 : 16.0,
                    vertical: isDesktop ? 32.0 : 16.0,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 980,
                      maxHeight: isDesktop ? 580 : size.height * 0.90,
                    ),
                    // Outer Metallic Gold Gradient Frame
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF5E4B5),
                          Color(0xFFD4AF37),
                          Color(0xFF997A26),
                          Color(0xFFF5E4B5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5), // Gold Border Thickness
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8F5), // Off-white / Cream
                        borderRadius: BorderRadius.circular(25.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25.5),
                        child: isDesktop
                            ? _buildDesktopSplitLayout(context, pages)
                            : _buildMobileLayout(context, pages),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop Viewport Layout: Side-by-side Split View
  Widget _buildDesktopSplitLayout(
      BuildContext context, List<OnboardingData> pages) {
    final page = pages[_currentPage];

    return Row(
      children: [
        // Left Half: High Resolution Hero Pane (covers whole area)
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  key: ValueKey<String>(page.imageAsset),
                  page.imageAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_outlined,
                        color: Color(0xFFD4AF37), size: 48),
                  ),
                ),
                // Soft edge gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Half: Brand Header, Content PageView, Sub-Card & Navigation Controls
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFFAF8F5),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar: Logo & Skip Action
                _buildTopHeader(),

                // Middle: Animated Content View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final item = pages[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF132238),
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.description,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF4A5568),
                              height: 1.55,
                            ),
                          ),

                          // Slide 2 Special Sub-Card with 4 Product Icons
                          if (item.showProductGrid) ...[
                            const SizedBox(height: 20),
                            _buildProductIconsSubCard(),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                // Bottom Controls: Gold Page Indicators & Navy Button
                _buildBottomControls(pages.length),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile Viewport Layout: Stacked Top Visual & Bottom Content Card
  Widget _buildMobileLayout(BuildContext context, List<OnboardingData> pages) {
    final page = pages[_currentPage];

    return Column(
      children: [
        // Top Half: Visual Header Pane (covers whole area)
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  key: ValueKey<String>(page.imageAsset),
                  page.imageAsset,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_outlined,
                        color: Color(0xFFD4AF37), size: 48),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Half: Content Pane
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFFAF8F5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopHeader(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final item = pages[index];
                      return SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF132238),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.description,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF4A5568),
                                height: 1.45,
                              ),
                            ),
                            if (item.showProductGrid) ...[
                              const SizedBox(height: 14),
                              _buildProductIconsSubCard(),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildBottomControls(pages.length),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Slide 2 Sub-Card with 4 Product Icons (Milk, Lassi, Ghee, Paneer)
  Widget _buildProductIconsSubCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFDCC8AA),
          width: 1.2,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _ProductSubItem(
                iconWidget: const _MilkBottleIcon(),
                label: tr('Milk'),
              ),
            ),
            _buildSubCardDivider(),
            Expanded(
              child: _ProductSubItem(
                iconWidget: const _LassiGlassIcon(),
                label: tr('Lassi'),
              ),
            ),
            _buildSubCardDivider(),
            Expanded(
              child: _ProductSubItem(
                iconWidget: const _GheePotIcon(),
                label: tr('Ghee'),
              ),
            ),
            _buildSubCardDivider(),
            Expanded(
              child: _ProductSubItem(
                iconWidget: const _PaneerCubeIcon(),
                label: tr('Paneer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCardDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0xFFE8DECF),
    );
  }

  /// Brand Header Widget with Logo & Skip Button
  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/newlogo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tr('Sawariya Dairy'),
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF14243B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _completeOnboarding,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(
                  tr('Skip'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF475569),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Bottom Controls: Page Indicators & Dark Navy Button
  Widget _buildBottomControls(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 3D Dot Indicators matching the reference image
        Row(
          children: List.generate(
            totalPages,
            (index) => _buildCustomPageDot(index),
          ),
        ),

        // Action Button ("Next" or "Get Started")
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF14243B), // Dark Navy
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14243B).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 38,
                  vertical: 12,
                ),
                child: Text(
                  _currentPage == totalPages - 1
                      ? tr('Get Started')
                      : tr('Next'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Custom Page Indicator Dot matching exact styling from image
  Widget _buildCustomPageDot(int index) {
    final isSelected = _currentPage == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? const Color(0xFF14243B) // Dark Navy Active Dot
            : const Color(0xFFDEC5A1), // Warm Light Tan / Gold Inactive Dot
      ),
    );
  }
}

/// Helper Widget for Slide 2 Sub-Card Items
class _ProductSubItem extends StatelessWidget {
  final Widget iconWidget;
  final String label;

  const _ProductSubItem({required this.iconWidget, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Center(child: iconWidget),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// VECTOR ICONS FOR SLIDE 2 (Milk, Lassi, Ghee, Paneer)
// ============================================================================

class _MilkBottleIcon extends StatelessWidget {
  const _MilkBottleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 28),
      painter: _MilkBottlePainter(),
    );
  }
}

class _MilkBottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeColor = Color(0xFF1C3A70);
    const milkColor = Color(0xFF93C5FD);
    const milkHighlight = Color(0xFFDBEAFE);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = milkColor
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Bottle outline path
    final bottlePath = Path();
    bottlePath.moveTo(w * 0.36, h * 0.05);
    bottlePath.lineTo(w * 0.64, h * 0.05);
    bottlePath.lineTo(w * 0.64, h * 0.22);
    bottlePath.cubicTo(w * 0.64, h * 0.30, w * 0.82, h * 0.36, w * 0.82, h * 0.48);
    bottlePath.lineTo(w * 0.82, h * 0.90);
    bottlePath.cubicTo(w * 0.82, h * 0.96, w * 0.76, h * 0.96, w * 0.70, h * 0.96);
    bottlePath.lineTo(w * 0.30, h * 0.96);
    bottlePath.cubicTo(w * 0.24, h * 0.96, w * 0.18, h * 0.96, w * 0.18, h * 0.90);
    bottlePath.lineTo(w * 0.18, h * 0.48);
    bottlePath.cubicTo(w * 0.18, h * 0.36, w * 0.36, h * 0.30, w * 0.36, h * 0.22);
    bottlePath.close();

    // Milk fill inside bottle
    final milkPath = Path();
    milkPath.moveTo(w * 0.20, h * 0.46);
    milkPath.cubicTo(w * 0.35, h * 0.42, w * 0.65, h * 0.48, w * 0.80, h * 0.46);
    milkPath.lineTo(w * 0.80, h * 0.90);
    milkPath.cubicTo(w * 0.80, h * 0.94, w * 0.74, h * 0.94, w * 0.68, h * 0.94);
    milkPath.lineTo(w * 0.32, h * 0.94);
    milkPath.cubicTo(w * 0.26, h * 0.94, w * 0.20, h * 0.94, w * 0.20, h * 0.90);
    milkPath.close();

    canvas.drawPath(milkPath, fillPaint);

    // Inner highlight stroke
    final innerHighlight = Path()
      ..moveTo(w * 0.26, h * 0.54)
      ..lineTo(w * 0.26, h * 0.84);
    canvas.drawPath(
      innerHighlight,
      Paint()
        ..color = milkHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );

    // Bottle outline
    canvas.drawPath(bottlePath, strokePaint);

    // Top rim line
    canvas.drawLine(
      Offset(w * 0.32, h * 0.05),
      Offset(w * 0.68, h * 0.05),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LassiGlassIcon extends StatelessWidget {
  const _LassiGlassIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 28),
      painter: _LassiGlassPainter(),
    );
  }
}

class _LassiGlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeColor = Color(0xFF1C3A70);
    const lassiColor = Color(0xFF93C5FD);
    const lassiHighlight = Color(0xFFDBEAFE);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Straw poking out
    final strawPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.68, h * 0.04),
      Offset(w * 0.52, h * 0.44),
      strawPaint,
    );

    // Liquid fill inside glass
    final fillPath = Path();
    fillPath.moveTo(w * 0.25, h * 0.36);
    fillPath.cubicTo(w * 0.40, h * 0.32, w * 0.60, h * 0.38, w * 0.75, h * 0.36);
    fillPath.lineTo(w * 0.68, h * 0.90);
    fillPath.cubicTo(w * 0.68, h * 0.94, w * 0.62, h * 0.94, w * 0.58, h * 0.94);
    fillPath.lineTo(w * 0.42, h * 0.94);
    fillPath.cubicTo(w * 0.38, h * 0.94, w * 0.32, h * 0.94, w * 0.32, h * 0.90);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = lassiColor
        ..style = PaintingStyle.fill,
    );

    // Highlight line
    canvas.drawLine(
      Offset(w * 0.36, h * 0.46),
      Offset(w * 0.38, h * 0.82),
      Paint()
        ..color = lassiHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );

    // Glass outline
    final glassPath = Path();
    glassPath.moveTo(w * 0.20, h * 0.26);
    glassPath.lineTo(w * 0.80, h * 0.26);
    glassPath.lineTo(w * 0.70, h * 0.92);
    glassPath.cubicTo(w * 0.70, h * 0.96, w * 0.64, h * 0.96, w * 0.58, h * 0.96);
    glassPath.lineTo(w * 0.42, h * 0.96);
    glassPath.cubicTo(w * 0.36, h * 0.96, w * 0.30, h * 0.96, w * 0.30, h * 0.92);
    glassPath.close();

    canvas.drawPath(glassPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GheePotIcon extends StatelessWidget {
  const _GheePotIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 28),
      painter: _GheePotPainter(),
    );
  }
}

class _GheePotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeColor = Color(0xFF1C3A70);
    const fillGheeColor = Color(0xFF93C5FD);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Liquid fill inside pot
    final fillPath = Path();
    fillPath.addOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62),
        width: w * 0.46,
        height: h * 0.42,
      ),
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillGheeColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill,
    );

    // Inner contour circle
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62),
        width: w * 0.38,
        height: h * 0.36,
      ),
      Paint()
        ..color = strokeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Pot / Jar outer outline
    final potPath = Path();
    potPath.moveTo(w * 0.32, h * 0.12);
    potPath.lineTo(w * 0.68, h * 0.12);
    potPath.lineTo(w * 0.64, h * 0.24);
    potPath.cubicTo(w * 0.90, h * 0.34, w * 0.90, h * 0.78, w * 0.66, h * 0.92);
    potPath.lineTo(w * 0.34, h * 0.92);
    potPath.cubicTo(w * 0.10, h * 0.78, w * 0.10, h * 0.34, w * 0.36, h * 0.24);
    potPath.close();

    canvas.drawPath(potPath, strokePaint);

    // Top rim lip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.12),
          width: w * 0.44,
          height: h * 0.08,
        ),
        const Radius.circular(2),
      ),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaneerCubeIcon extends StatelessWidget {
  const _PaneerCubeIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 28),
      painter: _PaneerCubePainter(),
    );
  }
}

class _PaneerCubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeColor = Color(0xFF1C3A70);
    const topColor = Color(0xFFEFF6FF);
    const leftColor = Color(0xFFDBEAFE);
    const rightColor = Color(0xFFBFDBFE);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Isometric 3D paneer cube
    final topP = Offset(w * 0.5, h * 0.08);
    final rightP = Offset(w * 0.90, h * 0.30);
    final centerP = Offset(w * 0.5, h * 0.52);
    final leftP = Offset(w * 0.10, h * 0.30);
    final bottomP = Offset(w * 0.5, h * 0.92);
    final bRightP = Offset(w * 0.90, h * 0.72);
    final bLeftP = Offset(w * 0.10, h * 0.72);

    // Top Face
    final topFace = Path()
      ..moveTo(topP.dx, topP.dy)
      ..lineTo(rightP.dx, rightP.dy)
      ..lineTo(centerP.dx, centerP.dy)
      ..lineTo(leftP.dx, leftP.dy)
      ..close();
    canvas.drawPath(topFace, Paint()..color = topColor..style = PaintingStyle.fill);

    // Left Face
    final leftFace = Path()
      ..moveTo(leftP.dx, leftP.dy)
      ..lineTo(centerP.dx, centerP.dy)
      ..lineTo(bottomP.dx, bottomP.dy)
      ..lineTo(bLeftP.dx, bLeftP.dy)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = leftColor..style = PaintingStyle.fill);

    // Right Face
    final rightFace = Path()
      ..moveTo(centerP.dx, centerP.dy)
      ..lineTo(rightP.dx, rightP.dy)
      ..lineTo(bRightP.dx, bRightP.dy)
      ..lineTo(bottomP.dx, bottomP.dy)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = rightColor..style = PaintingStyle.fill);

    // Outlines & Creases
    canvas.drawPath(topFace, strokePaint);
    canvas.drawPath(leftFace, strokePaint);
    canvas.drawPath(rightFace, strokePaint);

    // Internal segment cuts
    final midLeft = Offset((leftP.dx + centerP.dx) / 2, (leftP.dy + centerP.dy) / 2);
    final midBottomLeft = Offset((bLeftP.dx + bottomP.dx) / 2, (bLeftP.dy + bottomP.dy) / 2);
    canvas.drawLine(
      midLeft,
      midBottomLeft,
      Paint()
        ..color = strokeColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final midRight = Offset((centerP.dx + rightP.dx) / 2, (centerP.dy + rightP.dy) / 2);
    final midBottomRight = Offset((bottomP.dx + bRightP.dx) / 2, (bottomP.dy + bRightP.dy) / 2);
    canvas.drawLine(
      midRight,
      midBottomRight,
      Paint()
        ..color = strokeColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// FALLBACK VISUAL ILLUSTRATION WIDGETS
// ============================================================================

class _DairyFreshVisual extends StatelessWidget {
  const _DairyFreshVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/newlogo.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_drink_rounded,
              size: 80,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '100% PURE MILK',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC5A059),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DairyCollectionVisual extends StatelessWidget {
  const _DairyCollectionVisual();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.set_meal_rounded, size: 80, color: AppColors.primaryBlue),
          SizedBox(height: 12),
          Text(
            'PURE DAIRY PRODUCTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC5A059),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DairyDeliveryVisual extends StatelessWidget {
  const _DairyDeliveryVisual();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining_rounded,
              size: 80, color: AppColors.primaryBlue),
          SizedBox(height: 12),
          Text(
            'MORNING DOORSTEP DELIVERY',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC5A059),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
