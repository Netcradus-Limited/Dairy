import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/core/widgets/price_summary.dart';

void main() {
  group('PriceSummaryCard Accessibility & Overflow Tests', () {
    testWidgets(
      'renders without overflow under extreme 1.5x accessibility text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.5),
                size: Size(360, 800),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PriceSummaryCard(
                    subtotal: 450.0,
                    deliveryCharge: 30.0,
                    discount: 45.0,
                    grandTotal: 435.0,
                    actionButtonText: 'Proceed to Checkout',
                    onActionButtonPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(PriceSummaryCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders without overflow under extreme 2.0x accessibility text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(320, 600),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PriceSummaryCard(
                    subtotal: 1250.0,
                    deliveryCharge: 0.0,
                    discount: 125.0,
                    grandTotal: 1125.0,
                    actionButtonText: 'Place Order Now',
                    onActionButtonPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(PriceSummaryCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
