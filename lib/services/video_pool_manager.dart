import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Centralized manager for coordinating VideoPlayerControllers across the app.
///
/// Prevents hardware decoder exhaustion on mobile devices (Android MediaCodec /
/// iOS AVFoundation limits) by enforcing concurrency limits, releasing decoder
/// surfaces, and orchestrating smooth hand-offs between screens.
class VideoPoolManager {
  VideoPoolManager._();
  static final VideoPoolManager instance = VideoPoolManager._();

  /// Maximum number of simultaneously playing video controllers allowed
  static const int maxConcurrentActivePlayers = 2;

  final Set<VideoPlayerController> _registeredControllers = {};
  final List<VideoPlayerController> _activePlayingStack = [];

  /// Register a controller into the managed pool.
  void register(VideoPlayerController controller) {
    _registeredControllers.add(controller);
  }

  /// Unregister a controller when disposed.
  void unregister(VideoPlayerController controller) {
    _registeredControllers.remove(controller);
    _activePlayingStack.remove(controller);
  }

  /// Request permission for a controller to play.
  /// If the pool exceeds [maxConcurrentActivePlayers], older playing controllers
  /// are automatically paused to prevent hardware decoder crashes.
  Future<void> requestPlay(VideoPlayerController controller) async {
    register(controller);

    // Bring this controller to the top of active playing stack
    _activePlayingStack.remove(controller);
    _activePlayingStack.add(controller);

    // If over limit, pause the oldest active controller
    while (_activePlayingStack.length > maxConcurrentActivePlayers) {
      final oldest = _activePlayingStack.removeAt(0);
      if (oldest != controller && oldest.value.isInitialized && oldest.value.isPlaying) {
        try {
          await oldest.pause();
          debugPrint('[VideoPoolManager] Auto-paused background video to preserve hardware decoder.');
        } catch (e) {
          debugPrint('[VideoPoolManager] Non-fatal error auto-pausing video: $e');
        }
      }
    }
  }

  /// Notify that a controller has paused.
  void notifyPaused(VideoPlayerController controller) {
    _activePlayingStack.remove(controller);
  }

  /// Pause all active video players in the app (e.g. app backgrounded or lock screen).
  Future<void> pauseAll() async {
    for (final controller in List<VideoPlayerController>.from(_registeredControllers)) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        try {
          await controller.pause();
        } catch (_) {}
      }
    }
    _activePlayingStack.clear();
  }

  /// Validate media source URL or asset path.
  static bool isValidSource(String? source) {
    if (source == null) return false;
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('assets/')) return true;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      return uri != null && uri.hasAuthority && uri.host.isNotEmpty;
    }
    return false;
  }

  /// Default HTTP headers for streaming video. ExoPlayer and AVPlayer inject
  /// dynamic 'Range: bytes=X-Y' headers for chunk fetching and seeking; setting
  /// 'Accept-Encoding: identity' prevents servers from returning gzip-compressed
  /// responses that break range-based byte seeking.
  static Map<String, String> get streamingHttpHeaders => {
        'Accept': 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        'Accept-Encoding': 'identity',
      };
}
