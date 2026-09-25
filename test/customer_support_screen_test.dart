import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dairy_app/core/constants/app_strings.dart';
import 'package:dairy_app/features/profile/customer_support_screen.dart';
import 'package:dairy_app/models/user.dart';
import 'package:dairy_app/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String expectedSupportEmail = 'support@sawariyasdairy.com';
  const String expectedSubject = 'Sawariya Dairy Customer Support';

  group('Customer Support Centralized Configuration & Mailto URI Tests', () {
    test('AppStrings contains correct company support email and subject', () {
      expect(AppStrings.supportEmail, equals(expectedSupportEmail));
      expect(AppStrings.supportEmailSubject, equals(expectedSubject));
      expect(SUPPORT_EMAIL, equals(expectedSupportEmail));
    });

    test('Mailto URI format is constructed correctly without Gmail URLs', () {
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: AppStrings.supportEmail,
        queryParameters: {
          'subject': AppStrings.supportEmailSubject,
        },
      );

      expect(mailtoUri.scheme, equals('mailto'));
      expect(mailtoUri.path, equals(expectedSupportEmail));
      expect(
        mailtoUri.queryParameters['subject'],
        equals(expectedSubject),
      );
      // Verify no Gmail-specific domain or external webmail query is used
      expect(mailtoUri.toString(), isNot(contains('mail.google.com')));
      expect(mailtoUri.toString(), isNot(contains('outlook.live.com')));
      expect(mailtoUri.toString(), isNot(contains('mail.yahoo.com')));
    });
  });

  group('CustomerSupportScreen UI & Interaction Tests', () {
    final List<MethodCall> urlLauncherCalls = [];
    final List<MethodCall> platformCalls = [];
    bool canLaunchResult = true;
    bool launchResult = true;

    setUp(() {
      urlLauncherCalls.clear();
      platformCalls.clear();
      canLaunchResult = true;
      launchResult = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (MethodCall call) async {
          urlLauncherCalls.add(call);
          if (call.method == 'canLaunch') {
            return canLaunchResult;
          } else if (call.method == 'launch') {
            return launchResult;
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          platformCalls.add(call);
          if (call.method == 'Clipboard.setData') {
            return null;
          } else if (call.method == 'Clipboard.getData') {
            return {'text': expectedSupportEmail};
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('Displays configured support email and contact actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CustomerSupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Customer Support & Complaints'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      // Verify Support Email is displayed in the contact card
      expect(find.text(expectedSupportEmail), findsOneWidget);
      expect(find.text('Email: Not configured yet'), findsNothing);

      // Verify Phone placeholder remains unchanged since unconfigured
      expect(find.text('Phone: Not configured yet'), findsOneWidget);
    });

    group('Web Platform Behavior (kIsWeb == true)', () {
      testWidgets(
          'Email dialog on Web displays support email, helper text, Copy Email & Cancel, and NO Open Email App',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Email Action Button
        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        // Verify Dialog Title & Content
        expect(find.text('Email Customer Support'), findsOneWidget);
        expect(find.text(expectedSupportEmail), findsWidgets);
        expect(
          find.text(
              'Copy this email address and use your preferred email service.'),
          findsOneWidget,
        );

        // Verify Available Actions
        expect(find.text('Copy Email'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Verify "Open Email App" is NOT shown on Web
        expect(find.text('Open Email App'), findsNothing);

        // Verify no url_launcher calls occurred
        expect(urlLauncherCalls.isEmpty, isTrue);
      });

      testWidgets(
          'Tapping "Copy Email" on Web copies email, closes dialog, and displays "Support email copied" SnackBar',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Dialog
        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        // Tap Copy Email
        await tester.tap(find.text('Copy Email'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.text('Email Customer Support'), findsNothing);

        // Verify Clipboard was updated
        final clipboardSetCalls = platformCalls
            .where((call) => call.method == 'Clipboard.setData')
            .toList();
        expect(clipboardSetCalls.isNotEmpty, isTrue);
        expect(
          clipboardSetCalls.last.arguments,
          equals({'text': expectedSupportEmail}),
        );

        // Verify SnackBar
        expect(find.text('Support email copied'), findsOneWidget);

        // Verify NO url_launcher calls occurred
        expect(urlLauncherCalls.isEmpty, isTrue);
      });
    });

    group('Native Platform Behavior (kIsWeb == false)', () {
      testWidgets(
          'Email dialog on Native displays Open Email App, Copy Email, and Cancel',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Email Action Button
        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        // Verify Dialog Title and actions
        expect(find.text('Email Customer Support'), findsOneWidget);
        expect(find.text(expectedSupportEmail), findsWidgets);
        expect(find.text('Open Email App'), findsOneWidget);
        expect(find.text('Copy Email'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Cancel closes dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Email Customer Support'), findsNothing);
      });

      testWidgets(
          'Tapping "Open Email App" launches mailto URI with correct subject',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Dialog
        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        // Tap "Open Email App"
        await tester.tap(find.text('Open Email App'));
        await tester.pumpAndSettle();

        // Verify url_launcher was called with correct mailto URI
        expect(urlLauncherCalls.isNotEmpty, isTrue);
        final launchedCall = urlLauncherCalls.firstWhere(
          (call) => call.method == 'launch' || call.method == 'canLaunch',
        );
        final url = launchedCall.arguments['url'] as String;
        final parsedUri = Uri.parse(url);
        expect(parsedUri.scheme, equals('mailto'));
        expect(parsedUri.path, equals(expectedSupportEmail));
        expect(parsedUri.queryParameters['subject'], equals(expectedSubject));
        expect(url, isNot(contains('mail.google.com')));
      });

      testWidgets(
          'Failed mailto launch safely copies address and shows fallback message',
          (WidgetTester tester) async {
        canLaunchResult = false;
        launchResult = false;

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Email App'));
        await tester.pumpAndSettle();

        // Check fallback message was shown
        expect(
          find.text('Could not open an email app. Support email copied.'),
          findsOneWidget,
        );

        // Verify clipboard was set
        final clipboardSetCalls = platformCalls
            .where((call) => call.method == 'Clipboard.setData')
            .toList();
        expect(clipboardSetCalls.isNotEmpty, isTrue);
        expect(
          clipboardSetCalls.last.arguments,
          equals({'text': expectedSupportEmail}),
        );
      });

      testWidgets(
          'Tapping "Copy Email" in native dialog copies support email directly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CustomerSupportScreen(isWebOverride: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final emailButton = find.widgetWithText(InkWell, 'Email');
        await tester.tap(emailButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Copy Email'));
        await tester.pumpAndSettle();

        // Verify clipboard set
        final clipboardSetCalls = platformCalls
            .where((call) => call.method == 'Clipboard.setData')
            .toList();
        expect(clipboardSetCalls.isNotEmpty, isTrue);
        expect(
          clipboardSetCalls.last.arguments,
          equals({'text': expectedSupportEmail}),
        );

        // Verify SnackBar
        expect(find.text('Support email copied'), findsOneWidget);
      });
    });

    testWidgets(
        'Tapping the copy icon in contact card copies support email directly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CustomerSupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find copy button beside the support email in contact row
      final copyIcons = find.byIcon(Icons.copy_rounded);
      expect(copyIcons, findsWidgets);

      await tester.tap(copyIcons.last);
      await tester.pumpAndSettle();

      // Verify clipboard setData was called
      final clipboardSetCalls = platformCalls
          .where((call) => call.method == 'Clipboard.setData')
          .toList();
      expect(clipboardSetCalls.isNotEmpty, isTrue);
      expect(
        clipboardSetCalls.last.arguments,
        equals({'text': expectedSupportEmail}),
      );

      // Verify Confirmation Snackbar
      expect(find.text('Support email copied'), findsOneWidget);
    });

    testWidgets(
        'Complaint form retains customer profile email and does not replace with support email',
        (WidgetTester tester) async {
      const customerEmail = 'customer.test@example.com';
      const customerName = 'Rahul Sharma';
      const customerPhone = '9876543210';

      const mockUser = User(
        id: 'cust_123',
        name: customerName,
        phone: customerPhone,
        email: customerEmail,
        role: 'customer',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider
                .overrideWith((ref) => UserNotifier()..state = mockUser),
          ],
          child: const MaterialApp(
            home: CustomerSupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check pre-filled customer details from logged-in user profile
      expect(find.text(customerName), findsOneWidget);
      expect(find.text(customerPhone), findsOneWidget);
      expect(find.text(customerEmail), findsOneWidget);

      // Support email should only be in the company contact card, not inside customer email field
      final emailFields = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.controller?.text == customerEmail,
      );
      expect(emailFields, findsOneWidget);
    });
  });
}
