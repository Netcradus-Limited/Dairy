import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../constants/app_colors.dart';
import '../router/app_router.dart';
import '../../services/video_pool_manager.dart';

/// Production-grade unified video player for Sawariya Dairy.
///
/// Features:
/// - Supports both local assets and remote network/streaming URLs.
/// - Full App Lifecycle awareness (pauses on background/lock, resumes on foreground).
/// - Full Route awareness (pauses when modal routes push on top, resumes on pop).
/// - Tab & Visibility awareness (pauses when obscured in an IndexedStack).
/// - Hardware decoder concurrency safety via [VideoPoolManager].
/// - Buffering indicators and graceful error recovery with Retry.
/// - Zero-division aspect ratio guards.
class AppVideoPlayer extends StatefulWidget {
  final String videoPath;
  final double? aspectRatio;
  final BoxFit fit;
  final bool autoPlay;
  final bool looping;
  final bool muted;
  final bool showTapPlayPause;
  final String? fallbackAssetImage;
  final bool isActiveTab;
  final BorderRadius? borderRadius;
  final VoidCallback? onInitialized;
  final ValueChanged<String>? onError;

  const AppVideoPlayer({
    super.key,
    required this.videoPath,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.looping = true,
    this.muted = true,
    this.showTapPlayPause = true,
    this.fallbackAssetImage,
    this.isActiveTab = true,
    this.borderRadius,
    this.onInitialized,
    this.onError,
  });

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isBuffering = false;
  bool _isPlaying = false;
  bool _wasPlayingBeforeModal = false;
  bool _wasPlayingBeforeBackground = false;
  bool _isBackgrounded = false;
  bool _isCurrentRoute = true;
  bool _showPlayIconOverlay = false;
  Timer? _overlayTimer;
  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  Future<void> _initializePlayer() async {
    final path = widget.videoPath.trim();
    if (!VideoPoolManager.isValidSource(path)) {
      _handleError('Invalid video source: $path');
      return;
    }

    if (mounted) {
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });
    }

    // Safely dispose any previous controller
    final prev = _controller;
    if (prev != null) {
      VideoPoolManager.instance.unregister(prev);
      prev.removeListener(_onControllerUpdate);
      unawaited(prev.dispose());
      _controller = null;
    }

    try {
      VideoPlayerController controller;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          httpHeaders: VideoPoolManager.streamingHttpHeaders,
        );
      } else {
        controller = VideoPlayerController.asset(
          path,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      _controller = controller;
      VideoPoolManager.instance.register(controller);

      await controller.initialize();

      if (!mounted || _controller != controller) {
        VideoPoolManager.instance.unregister(controller);
        controller.removeListener(_onControllerUpdate);
        unawaited(controller.dispose());
        return;
      }

      await controller.setVolume(widget.muted ? 0.0 : 1.0);
      await controller.setLooping(widget.looping);

      controller.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      widget.onInitialized?.call();

      if (widget.autoPlay && widget.isActiveTab && _isCurrentRoute) {
        _play();
      }
    } catch (e) {
      debugPrint('[AppVideoPlayer] Error initializing video ($path): $e');
      _handleError(e.toString());
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _isInitialized = false;
    });
    widget.onError?.call(message);
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final isBuffering = controller.value.isBuffering;
    final isPlaying = controller.value.isPlaying;
    final hasError = controller.value.hasError;

    if (hasError && !_hasError) {
      _handleError(controller.value.errorDescription ?? 'Video playback error');
      return;
    }

    if (isBuffering != _isBuffering || isPlaying != _isPlaying) {
      setState(() {
        _isBuffering = isBuffering;
        _isPlaying = isPlaying;
      });
    }
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await VideoPoolManager.instance.requestPlay(controller);
      await controller.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('[AppVideoPlayer] Playback non-fatal error: $e');
    }
  }

  Future<void> _pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.pause();
      VideoPoolManager.instance.notifyPaused(controller);
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } catch (e) {
      debugPrint('[AppVideoPlayer] Pause non-fatal error: $e');
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }

    if (widget.showTapPlayPause) {
      _overlayTimer?.cancel();
      setState(() => _showPlayIconOverlay = true);
      _overlayTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() => _showPlayIconOverlay = false);
        }
      });
    }
  }

  // ─── Lifecycle Handling (App Minimized / Restored) ───────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (!_isBackgrounded) {
        _isBackgrounded = true;
        _wasPlayingBeforeBackground = _isPlaying;
        _pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      if (_wasPlayingBeforeBackground && widget.isActiveTab && _isCurrentRoute) {
        _play();
      }
    }
  }

  // ─── Route Awareness (Modal Screens Pushed / Popped) ─────────────────────
  @override
  void didPushNext() {
    _isCurrentRoute = false;
    _wasPlayingBeforeModal = _isPlaying;
    _pause();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    if (_wasPlayingBeforeModal && widget.isActiveTab) {
      _play();
    }
  }

  // ─── Widget Updates (Tab Switch or Path Change) ──────────────────────────
  @override
  void didUpdateWidget(covariant AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoPath != widget.videoPath) {
      _initializePlayer();
      return;
    }

    if (oldWidget.isActiveTab != widget.isActiveTab) {
      if (widget.isActiveTab && _isCurrentRoute && widget.autoPlay) {
        _play();
      } else {
        _pause();
      }
    }

    if (oldWidget.muted != widget.muted && _controller != null) {
      _controller!.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    _overlayTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      VideoPoolManager.instance.unregister(controller);
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    // Zero-division aspect ratio safety guard
    double effectiveRatio = 16 / 9;
    if (_isInitialized && controller != null) {
      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        final calc = size.width / size.height;
        if (calc.isFinite && calc > 0) {
          effectiveRatio = calc;
        }
      }
    }
    if (widget.aspectRatio != null && widget.aspectRatio! > 0) {
      effectiveRatio = widget.aspectRatio!;
    }

    Widget content;

    if (_hasError) {
      content = _buildErrorWidget();
    } else if (!_isInitialized || controller == null) {
      content = _buildLoadingWidget();
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width > 0
                  ? controller.value.size.width
                  : 16,
              height: controller.value.size.height > 0
                  ? controller.value.size.height
                  : 9,
              child: VideoPlayer(controller),
            ),
          ),
          if (_isBuffering)
            Container(
              color: Colors.black26,
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (_showPlayIconOverlay)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showPlayIconOverlay ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget wrapped = AspectRatio(
      aspectRatio: effectiveRatio,
      child: GestureDetector(
        onTap: _togglePlayPause,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );

    if (widget.borderRadius != null) {
      wrapped = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: wrapped,
      );
    }

    return wrapped;
  }

  Widget _buildLoadingWidget() {
    if (widget.fallbackAssetImage != null &&
        widget.fallbackAssetImage!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            widget.fallbackAssetImage!,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _buildPlaceholderContainer(),
          ),
          Container(
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _buildPlaceholderContainer(showSpinner: true);
  }

  Widget _buildPlaceholderContainer({bool showSpinner = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: showSpinner
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.play_circle_outline,
                size: 44,
                color: AppColors.primary,
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 32,
            ),
            const SizedBox(height: 6),
            const Text(
              'Unable to load video',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
