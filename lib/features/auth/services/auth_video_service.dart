import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:video_player/video_player.dart';

import '../widgets/web_video_helper.dart';

/// Service responsible for preloading and caching VideoPlayerControllers
/// for authentication screens (Login, Register, OTP, Forgot/Reset Password).
/// This prevents any flash of static placeholder images and ensures instant playback.
class AuthVideoService {
  AuthVideoService._internal();
  static final AuthVideoService instance = AuthVideoService._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initFutures = {};

  static const String loginVideoPath = 'assets/images/loginv2.mp4';
  static const String otpVideoPath = 'assets/images/otpv.mp4';

  /// Preload both login and OTP videos concurrently in the background
  void preload() {
    getController(loginVideoPath);
    getController(otpVideoPath);
  }

  /// Get or create an initialized VideoPlayerController for the specified asset path
  VideoPlayerController getController(String videoPath) {
    if (_controllers.containsKey(videoPath)) {
      return _controllers[videoPath]!;
    }

    final controller = VideoPlayerController.asset(
      videoPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _controllers[videoPath] = controller;

    final future = _initializeController(controller);
    _initFutures[videoPath] = future;

    return controller;
  }

  Future<void> _initializeController(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      await controller.setVolume(0.0);
      await controller.setLooping(true);

      if (kIsWeb) {
        configureWebVideoAutoplay();
      }

      await controller.play().catchError((error) {
        debugPrint('AuthVideoService play non-fatal error: $error');
      });
    } catch (e) {
      debugPrint('AuthVideoService init error for controller: $e');
    }
  }

  Future<void>? getInitFuture(String videoPath) => _initFutures[videoPath];

  bool isInitialized(String videoPath) {
    return _controllers[videoPath]?.value.isInitialized ?? false;
  }

  void play(String videoPath) {
    final controller = _controllers[videoPath];
    if (controller != null && controller.value.isInitialized) {
      controller.setVolume(0.0);
      controller.play().catchError((e) {
        debugPrint('AuthVideoService play error: $e');
      });
      if (kIsWeb) {
        configureWebVideoAutoplay();
      }
    }
  }

  void pause(String videoPath) {
    final controller = _controllers[videoPath];
    if (controller != null && controller.value.isInitialized) {
      controller.pause().catchError((_) {});
    }
  }

  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initFutures.clear();
  }
}
