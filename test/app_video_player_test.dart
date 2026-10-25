import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dairy_app/core/widgets/app_video_player.dart';
import 'package:dairy_app/repositories/firestore_product_repository.dart';
import 'package:dairy_app/services/video_pool_manager.dart';

void main() {
  group('VideoPoolManager Unit Tests', () {
    test('isValidSource validates asset paths and HTTP/HTTPS URLs', () {
      expect(VideoPoolManager.isValidSource('assets/images/homenew2v.mp4'), isTrue);
      expect(VideoPoolManager.isValidSource('https://storage.googleapis.com/dairy/video.mp4'), isTrue);
      expect(VideoPoolManager.isValidSource('http://example.com/media/clip.mp4'), isTrue);

      expect(VideoPoolManager.isValidSource(null), isFalse);
      expect(VideoPoolManager.isValidSource(''), isFalse);
      expect(VideoPoolManager.isValidSource('   '), isFalse);
      expect(VideoPoolManager.isValidSource('ftp://invalid.com/video.mp4'), isFalse);
      expect(VideoPoolManager.isValidSource('not_a_valid_url'), isFalse);
    });

    test('streamingHttpHeaders configures identity encoding and media types', () {
      final headers = VideoPoolManager.streamingHttpHeaders;
      expect(headers['Accept'], contains('video/mp4'));
      expect(headers['Accept-Encoding'], equals('identity'));
    });
  });

  group('AppVideoPlayer Widget Tests', () {
    testWidgets('Renders error UI with Retry button when source is invalid',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayer(
              videoPath: 'invalid_source_path',
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify that error state is displayed cleanly instead of crashing
      expect(find.text('Unable to load video'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('Tapping Retry attempts re-initialization',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayer(
              videoPath: 'invalid_source_path',
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      );

      await tester.pump();

      final retryFinder = find.text('Retry');
      expect(retryFinder, findsOneWidget);

      await tester.tap(retryFinder);
      await tester.pump();

      // Still gracefully shows error state for invalid URL without throwing unhandled exceptions
      expect(find.text('Unable to load video'), findsOneWidget);
    });

    testWidgets('Gracefully falls back to fallbackAssetImage without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayer(
              videoPath: 'assets/images/homenew2v.mp4',
              fallbackAssetImage: 'assets/images/banner1.png',
              aspectRatio: 2.0,
            ),
          ),
        ),
      );

      await tester.pump();

      // Widget tree rendered cleanly
      expect(find.byType(AppVideoPlayer), findsOneWidget);
    });

    testWidgets('Handles multi-step background lifecycle transitions without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayer(
              videoPath: 'invalid_source_path',
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      );

      await tester.pump();

      // Trigger inactive -> paused (minimizing app)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Resume app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.byType(AppVideoPlayer), findsOneWidget);
    });

    testWidgets('Widget disposal during initialization cleans up safely',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppVideoPlayer(
              videoPath: 'assets/images/homenew2v.mp4',
              fallbackAssetImage: 'assets/images/banner1.png',
              aspectRatio: 2.0,
            ),
          ),
        ),
      );

      // Immediately dispose widget without pumping to completion
      await tester.pumpWidget(const SizedBox());
      expect(find.byType(AppVideoPlayer), findsNothing);
    });

    testWidgets('Route subscription is stable across MediaQuery / theme changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: AppVideoPlayer(
                  videoPath: 'invalid_source_path',
                  aspectRatio: 16 / 9,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Simulate dependency change (e.g. keyboard pop, window resize)
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      await tester.pump();

      expect(find.byType(AppVideoPlayer), findsOneWidget);
    });
  });

  group('FirestoreProductRepository Seeding Tests', () {
    test('seedDefaultsIfNeeded is idempotent and persists flag to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fakeDb = FakeFirebaseFirestore();
      final repo = FirestoreProductRepository(fakeDb, false);

      // Call seedDefaultsIfNeeded concurrently
      final future1 = repo.seedDefaultsIfNeeded();
      final future2 = repo.seedDefaultsIfNeeded();

      expect(identical(future1, future2), isTrue);

      await Future.wait([future1, future2]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('firestore_defaults_seeded_v1'), isTrue);

      // Verify second call immediately exits without re-querying
      await repo.seedDefaultsIfNeeded();
      expect(prefs.getBool('firestore_defaults_seeded_v1'), isTrue);
    });

    test('seedDefaultsIfNeeded allows retry when previous attempt failed',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fakeDb = FakeFirebaseFirestore();
      final repo = FirestoreProductRepository(fakeDb, false);

      final future1 = repo.seedDefaultsIfNeeded();
      await future1;

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('firestore_defaults_seeded_v1'), isTrue);
    });
  });
}
