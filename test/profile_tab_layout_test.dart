import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/profile_tab.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/core/theme/app_theme.dart';

class MockDeliveryNotifier extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'ProfileTab renders without infinite-width BoxConstraints on mobile and desktop',
      (WidgetTester tester) async {
    // Incomplete profile agent triggers the Setup banner at line 520
    final incompleteAgent =
        DeliveryAgent.empty('test_agent_1').copyWith(isLoaded: true);

    // Test on Mobile dimensions (360 x 800)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryAgentProvider
              .overrideWith((ref) => MockDeliveryNotifier(incompleteAgent)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ProfileTab(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify banner and Setup button are rendered
    expect(find.text('Complete Your Profile'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Test on Desktop dimensions (1280 x 900)
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Complete Your Profile'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
