import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/services/auth_video_service.dart';

/// Premium Minimal Animated Splash Screen for Sawariya Dairy
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Preload authentication videos early for instant playback on login & otp
    AuthVideoService.instance.preload();

    // Setup smooth fade & scale animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    // Navigate after 3 seconds with a cancellable timer
    _navigationTimer = Timer(const Duration(milliseconds: 3000), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // If a session already exists, go straight to the relevant home screen
    // (the login-on-every-launch bug). The router redirect also handles this,
    // this branch is the deterministic splash-level decision.
    final user = ref.read(userProvider);
    if (user.id.isNotEmpty) {
      if (user.isAdmin) {
        context.go('/admin');
      } else if (user.isDelivery) {
        context.go('/delivery');
      } else {
        context.go('/home');
      }
      return;
    }

    final onboardingService = ref.read(onboardingServiceProvider);
    final isCompleted = await onboardingService.isOnboardingCompleted();

    if (!mounted) return;
    if (isCompleted) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen background image
          Positioned.fill(
            child: Image.asset(
              AppAssets.landingBg,
              fit: BoxFit.cover,
            ),
          ),
          // Ambient overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
          // Background Gradient Bubbles
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightBlue.withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightBlue.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Main Center Brand Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dairy Fresh Visual Icon Badge
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(52),
                            child: Image.asset(
                              'assets/images/nicon.png',
                              width: 104,
                              height: 104,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSizes.p24),

                      // Brand Title
                      const Text(
                        'Sawariya Dairy',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: AppSizes.p8),

                      // Tagline
                      const Text(
                        'Pure by Nature, Trusted by You.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: AppSizes.p48),

                      // Minimal Loading Indicator
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
