import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_app/features/profile/terms_and_conditions_screen.dart';
import 'package:dairy_app/features/profile/legal_policies_screen.dart';
import 'package:dairy_app/core/router/app_router.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/user_provider.dart';

class _TestUserNotifier extends UserNotifier {
  _TestUserNotifier(User initial) : super() {
    state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Terms & Conditions Screen UI Tests', () {
    testWidgets('Renders all 23 canonical sections, company header, and COD details',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TermsAndConditionsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Terms & Conditions'), findsWidgets);

      // Company and official details
      expect(find.text('SAWARIYA SARKAR DAIRY LLP'), findsOneWidget);
      expect(find.text('COD ONLY'), findsOneWidget);
      expect(find.text('Cash on Delivery Only'), findsOneWidget);
      expect(find.textContaining('Ground Floor, Khewat No. 253/260'), findsWidgets);
      expect(find.text('support@sawariyasdairy.com'), findsWidgets);
      expect(find.text('9896703884'), findsWidgets);

      // Verify sections are present
      for (final sec in TermsAndConditionsScreen.termsSections) {
        expect(find.text(sec.title), findsOneWidget,
            reason: 'Section ${sec.number} title "${sec.title}" should be present');
      }

      // Verify exactly 23 sections
      expect(TermsAndConditionsScreen.termsSections.length, equals(23));

      // Check first and last section
      expect(TermsAndConditionsScreen.termsSections.first.title, equals('Introduction'));
      expect(TermsAndConditionsScreen.termsSections.last.title, equals('Contact Information'));

      // Check specific operational rules
      expect(find.textContaining('CASH ON DELIVERY (COD) ONLY'), findsWidgets);
      expect(find.textContaining('within 24 hours of the scheduled delivery'), findsWidgets);
    });
  });

  group('GoRouter /terms-and-conditions Route Tests', () {
    test('Route /terms-and-conditions is registered in GoRouter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final hasTermsRoute = router.configuration.routes.any((route) {
        if (route is GoRoute) {
          return route.path == '/terms-and-conditions';
        }
        return false;
      });

      expect(hasTermsRoute, isTrue,
          reason: 'Expected /terms-and-conditions route to be defined in appRouterProvider');
    });

    testWidgets('Unauthenticated visitor can access /terms-and-conditions without /login redirect',
        (tester) async {
      // Unauthenticated state: guestUser (id == '')
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Direct navigation to /terms-and-conditions
      router.go('/terms-and-conditions');
      await tester.pumpAndSettle();

      // Should be on TermsAndConditionsScreen, NOT LoginScreen
      expect(find.byType(TermsAndConditionsScreen), findsOneWidget);
      expect(find.text('SAWARIYA SARKAR DAIRY LLP'), findsOneWidget);
    });

    testWidgets('Authenticated user can navigate to /terms-and-conditions directly',
        (tester) async {
      const authUser = User(
        id: 'cust_test_1',
        phone: '+91 98765 43210',
        name: 'Verified Customer',
        role: 'customer',
      );
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(authUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Direct navigation to /terms-and-conditions
      router.go('/terms-and-conditions');
      await tester.pumpAndSettle();

      // Should be on TermsAndConditionsScreen
      expect(find.byType(TermsAndConditionsScreen), findsOneWidget);
    });
  });

  group('GoRouter Public Legal Policy Routes Tests', () {
    test('Routes /privacy-policy, /refund-policy, /delivery-policy, /delete-account are registered in GoRouter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final registeredPaths = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toSet();

      expect(registeredPaths.contains('/terms-and-conditions'), isTrue);
      expect(registeredPaths.contains('/privacy-policy'), isTrue);
      expect(registeredPaths.contains('/refund-policy'), isTrue);
      expect(registeredPaths.contains('/delivery-policy'), isTrue);
      expect(registeredPaths.contains('/delete-account'), isTrue);
      expect(registeredPaths.contains('/dpdp'), isTrue);
      expect(registeredPaths.contains('/data-protection'), isTrue);
    });

    testWidgets('Unauthenticated visitor can access /privacy-policy and see LegalPoliciesScreen at Tab 0',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go('/privacy-policy');
      await tester.pumpAndSettle();

      expect(find.byType(LegalPoliciesScreen), findsOneWidget);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('DATA CONTROLLER & APP OVERVIEW'), findsOneWidget);
    });

    testWidgets('Unauthenticated visitor can access /refund-policy and see Tab 2',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go('/refund-policy');
      await tester.pumpAndSettle();

      expect(find.byType(LegalPoliciesScreen), findsOneWidget);
      expect(find.text('Refund & Cancellation Policy'), findsOneWidget);
    });

    testWidgets('Unauthenticated visitor can access /delivery-policy and see Tab 3',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go('/delivery-policy');
      await tester.pumpAndSettle();

      expect(find.byType(LegalPoliciesScreen), findsOneWidget);
      expect(find.text('Delivery Policy'), findsWidgets);
    });

    testWidgets('Unauthenticated visitor can access /delete-account and see Tab 4',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(guestUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go('/delete-account');
      await tester.pumpAndSettle();

      expect(find.byType(LegalPoliciesScreen), findsOneWidget);
      expect(find.text('Account Deletion & Data Retention'), findsOneWidget);
    });

    testWidgets('Authenticated user can navigate to /privacy-policy directly without being redirected to /home or /admin',
        (tester) async {
      const authUser = User(
        id: 'cust_test_2',
        phone: '+91 98765 43210',
        name: 'Verified Customer',
        role: 'customer',
      );
      final container = ProviderContainer(
        overrides: [
          userProvider.overrideWith((ref) => _TestUserNotifier(authUser)),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go('/privacy-policy');
      await tester.pumpAndSettle();

      expect(find.byType(LegalPoliciesScreen), findsOneWidget);
      expect(find.text('Privacy Policy'), findsWidgets);
    });
  });

  group('LegalPoliciesScreen Tab Integration Tests', () {
    testWidgets('LegalPoliciesScreen Tab 1 loads the full 23-section terms text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPoliciesScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1 selected
      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.textContaining('1. INTRODUCTION'), findsOneWidget);
      expect(find.textContaining('23. CONTACT INFORMATION'), findsOneWidget);
      expect(find.textContaining('CASH ON DELIVERY (COD) ONLY'), findsWidgets);
    });

    testWidgets('LegalPoliciesScreen is responsive on desktop viewport (1200x800) without character stacking',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPoliciesScreen(initialTabIndex: 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Open Online'), findsNothing);

      // Verify title is rendered with appropriate horizontal width
      final titleFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Privacy Policy' && w.style?.fontSize == 22.0,
      );
      expect(titleFinder, findsOneWidget);
      final titleBox = tester.renderObject<RenderBox>(titleFinder);
      expect(titleBox.size.width, greaterThan(100.0),
          reason: 'Title should have full horizontal width, not single-character width');
      expect(titleBox.size.height, lessThan(40.0),
          reason: 'Single-line or wrapped title should not be stacked character by character');
    });

    testWidgets('LegalPoliciesScreen is responsive on mobile viewport (360x800) without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (int i = 0; i < 6; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: LegalPoliciesScreen(initialTabIndex: i),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Tab $i should render without overflow on 360x800 viewport');
      }
    });
  });
}
