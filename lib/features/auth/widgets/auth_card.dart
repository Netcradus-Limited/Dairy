import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_assets.dart';
import '../services/auth_video_service.dart';
import 'web_video_helper.dart';

/// Responsive Luxury Authentication Shell Container Card for Sawariya Dairy
class AuthCard extends StatelessWidget {
  final Widget child;
  final String? featureTitle;
  final String? featureSubtitle;
  final String videoPath;

  const AuthCard({
    super.key,
    required this.child,
    this.featureTitle = 'Pure Dairy at Your Doorstep',
    this.featureSubtitle =
        'Order farm-fresh A2 milk, ghee, paneer, and butter with daily morning delivery.',
    this.videoPath = 'assets/images/loginv2.mp4',
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final orientation = MediaQuery.of(context).orientation;

    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    final isDesktop = width >= 900;
    final isTabletLandscape = isTablet && orientation == Orientation.landscape;
    final isHorizontal = isDesktop || isTabletLandscape;

    final double cardWidth = isMobile
        ? width * 0.94
        : isTablet
            ? (orientation == Orientation.portrait
                ? width * 0.90
                : width * 0.85)
            : 960;

    final double cardHeight =
        isHorizontal ? 520 : (height * 0.85).clamp(500.0, 680.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFAF7F0), // Soft Parchment / Off-White
      body: Stack(
        children: [
          // Full-screen background image
          Positioned.fill(
            child: Image.asset(
              AppAssets.landingBg,
              fit: BoxFit.cover,
            ),
          ),
          // Ambient overlay to ensure contrast
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
          // 1. Background Watermark Graphics
          // Bottom-Left Watermark (Milk drops & Reeds)
          Positioned(
            left: -30,
            bottom: -20,
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                size: const Size(260, 260),
                painter: _WatermarkDropsPainter(),
              ),
            ),
          ),

          // Right Watermark (Vintage Milk Can Line Art)
          Positioned(
            right: size.width * 0.02,
            bottom: size.height * 0.05,
            child: Opacity(
              opacity: 0.07,
              child: CustomPaint(
                size: Size(size.height * 0.55, size.height * 0.75),
                painter: _MilkCanWatermarkPainter(),
              ),
            ),
          ),

          // 2. Main Centered Gold-Bordered Container Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isHorizontal ? 36.0 : 16.0,
                  vertical: isHorizontal ? 28.0 : 16.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: cardWidth,
                      height: cardHeight,
                      // Outer Gold Frame
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF5E4B5),
                            Color(0xFFC5A059),
                            Color(0xFF8C6D2B),
                            Color(0xFFF5E4B5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding:
                          const EdgeInsets.all(2.5), // Gold Border Thickness
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(
                              0xFFFAF7EE), // Inner Cream Parchment Surface
                          borderRadius: BorderRadius.circular(21.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21.5),
                          child: LayoutBuilder(
                            builder: (context, boxConstraints) {
                              final mediaSection = Container(
                                color: Colors.white,
                                child: Center(
                                  child: _AuthVideoPlayer(
                                    videoPath: videoPath,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );

                              final formSection = Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: const Color(0xFFFAF7EE),
                                child: Center(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16.0 : 32.0,
                                      vertical: 24.0,
                                    ),
                                    child: child,
                                  ),
                                ),
                              );

                              if (isHorizontal) {
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: mediaSection,
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: formSection,
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: mediaSection,
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: formSection,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Bottom-Left Watermark Drops
class _WatermarkDropsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8C6D2B)
      ..style = PaintingStyle.fill;

    // Draw milk drops
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 14, paint);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.3), 10, paint);
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.65), 18, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Right Watermark Vintage Milk Can
class _MilkCanWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF786236)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final w = size.width;
    final h = size.height;

    // Milk Can Outer Contour
    final path = Path();
    path.moveTo(w * 0.3, h * 0.1);
    path.lineTo(w * 0.7, h * 0.1);
    path.lineTo(w * 0.75, h * 0.22);
    path.lineTo(w * 0.85, h * 0.35);
    path.lineTo(w * 0.85, h * 0.9);
    path.lineTo(w * 0.15, h * 0.9);
    path.lineTo(w * 0.15, h * 0.35);
    path.lineTo(w * 0.25, h * 0.22);
    path.close();

    canvas.drawPath(path, paint);

    // Can lid handle
    canvas.drawArc(
      Rect.fromLTWH(w * 0.35, h * 0.02, w * 0.3, h * 0.12),
      3.14,
      3.14,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Video Player Widget for Login Page
// ─────────────────────────────────────────────────────────────────────────────

class _AuthVideoPlayer extends StatefulWidget {
  final BoxFit fit;
  final String videoPath;
  const _AuthVideoPlayer({
    required this.videoPath,
    this.fit = BoxFit.contain,
  });

  @override
  State<_AuthVideoPlayer> createState() => _AuthVideoPlayerState();
}

class _AuthVideoPlayerState extends State<_AuthVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _bindController();
  }

  void _bindController() {
    _controller = AuthVideoService.instance.getController(widget.videoPath);
    _controller.addListener(_onControllerUpdate);

    if (_controller.value.isInitialized) {
      _isInitialized = true;
      _startPlayback();
    } else {
      final initFuture =
          AuthVideoService.instance.getInitFuture(widget.videoPath);
      initFuture?.then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = _controller.value.isInitialized;
          });
          if (_isInitialized) {
            _startPlayback();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AuthVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller.removeListener(_onControllerUpdate);
      _bindController();
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startPlayback() async {
    try {
      await _controller.setVolume(0.0);
      await _controller.setLooping(true);

      if (kIsWeb) {
        configureWebVideoAutoplay();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          configureWebVideoAutoplay();
        });
      }

      await _controller.play().catchError((error) {
        debugPrint('Auth video play() non-fatal error: $error');
      });
    } catch (e) {
      debugPrint('Error starting auth video playback: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    // Note: Do not dispose _controller here as it is cached in AuthVideoService
    super.dispose();
  }

  void _onTapPlay() {
    if (!_controller.value.isPlaying) {
      _controller.setVolume(0.0);
      _controller.play().catchError((error) {
        debugPrint('Tap play error: $error');
      });
      if (kIsWeb) {
        configureWebVideoAutoplay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorDesc = _controller.value.errorDescription?.toLowerCase() ?? '';
    final isAutoplayRejection = errorDesc.contains('interact') ||
        errorDesc.contains('notallowederror') ||
        errorDesc.contains('autoplay');

    if (_controller.value.hasError && !isAutoplayRejection) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(
                'Video Playback Error: ${_controller.value.errorDescription}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F3822), Color(0xFF052113)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4AF37),
            strokeWidth: 2,
          ),
        ),
      );
    }

    Widget videoWidget;
    if (widget.fit == BoxFit.contain) {
      videoWidget = AspectRatio(
        aspectRatio: _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9,
        child: VideoPlayer(_controller),
      );
    } else {
      videoWidget = SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: _controller.value.size.width > 0
                ? _controller.value.size.width
                : 16,
            height: _controller.value.size.height > 0
                ? _controller.value.size.height
                : 9,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTapPlay,
      child: videoWidget,
    );
  }
}
