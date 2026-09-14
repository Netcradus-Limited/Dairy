// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Ensures the underlying HTML video element on Flutter Web has all attributes
/// and properties necessary for automatic muted autoplay across desktop and mobile browsers.
void configureWebVideoAutoplay([int? playerId]) {
  void apply() {
    try {
      final selector = playerId != null && playerId >= 0
          ? '#videoElement-$playerId'
          : 'video';
      final elements = web.document.querySelectorAll(selector);
      for (int i = 0; i < elements.length; i++) {
        final el = elements.item(i);
        if (el != null && el.isA<web.HTMLVideoElement>()) {
          _configureVideoElement(el as web.HTMLVideoElement);
        }
      }

      // Also configure any other video tags present in the DOM
      if (elements.length == 0 || selector != 'video') {
        final allVideos = web.document.querySelectorAll('video');
        for (int i = 0; i < allVideos.length; i++) {
          final el = allVideos.item(i);
          if (el != null && el.isA<web.HTMLVideoElement>()) {
            _configureVideoElement(el as web.HTMLVideoElement);
          }
        }
      }
    } catch (_) {}
  }

  // Apply immediately
  apply();

  // Retry across subsequent frames to guarantee DOM attachment
  Future.delayed(const Duration(milliseconds: 50), apply);
  Future.delayed(const Duration(milliseconds: 150), apply);
  Future.delayed(const Duration(milliseconds: 350), apply);
  Future.delayed(const Duration(milliseconds: 700), apply);
}

void _configureVideoElement(web.HTMLVideoElement video) {
  try {
    video.muted = true;
    video.defaultMuted = true;
    video.autoplay = true;
    video.playsInline = true;
    video.loop = true;

    video.setAttribute('muted', 'true');
    video.setAttribute('autoplay', 'true');
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    video.setAttribute('loop', 'true');

    // If currently paused, trigger play programmatically on the HTML video element
    if (video.paused) {
      video.play().toDart.catchError((Object? _) => null);
    }
  } catch (_) {}
}
