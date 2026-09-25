import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/auth/widgets/otp_input_field.dart';

void main() {
  group('OtpInputField Autofill and Input Tests', () {
    testWidgets(
        'OtpInputField renders AutofillGroup and AutofillHints.oneTimeCode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputField(
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      // Verify AutofillGroup exists
      expect(find.byType(AutofillGroup), findsOneWidget);

      // Verify 6 TextFields exist
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));

      // Verify each TextField has AutofillHints.oneTimeCode and TextInputType.number
      for (int i = 0; i < 6; i++) {
        final field = tester.widget<TextField>(textFields.at(i));
        expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
        expect(field.keyboardType, equals(TextInputType.number));
      }
    });

    testWidgets('6-digit OTP Autofill correctly distributes across all 6 boxes',
        (WidgetTester tester) async {
      String? completedCode;
      String? changedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputField(
              onChanged: (val) => changedCode = val,
              onCompleted: (val) => completedCode = val,
            ),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);

      // Simulate system autofill injecting '654321' into the first field
      await tester.enterText(textFields.first, '654321');
      await tester.pumpAndSettle();

      expect(completedCode, equals('654321'));
      expect(changedCode, equals('654321'));

      // Verify each box has the individual digit
      expect(find.text('6'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'Manual single-digit entry advances through boxes and triggers onCompleted',
        (WidgetTester tester) async {
      String? completedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputField(
              onCompleted: (val) => completedCode = val,
            ),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);

      // Enter digits 1 by 1
      final digits = ['9', '8', '7', '6', '5', '4'];
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), ' ${digits[i]}');
        await tester.pumpAndSettle();
      }

      expect(completedCode, equals('987654'));
    });
  });
}
