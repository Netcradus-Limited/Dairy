import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dairy_app/core/constants/app_colors.dart';
import 'package:dairy_app/features/auth/widgets/otp_input_field.dart';

void main() {
  group('BUG-009 & BUG-010: Accessibility 2.5x Font Scaling Tests', () {
    testWidgets(
      'Login screen footer Wrap renders without horizontal overflow at 2.5x font scale on narrow 320dp viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.5),
                size: Size(320, 600),
              ),
              child: Scaffold(
                body: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF4A5568),
                        ),
                      ),
                      Text(
                        'Register',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text("Don't have an account? "), findsOneWidget);
        expect(find.text('Register'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'OtpInputField renders without vertical clipping or overflow at 2.5x font scale on 320dp viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.5),
                size: Size(320, 600),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: OtpInputField(
                    onCompleted: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(OtpInputField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
