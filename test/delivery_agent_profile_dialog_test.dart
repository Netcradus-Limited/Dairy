import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/delivery_panel/screens/profile_tab.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/providers/delivery_provider.dart';
import 'package:dairy_app/core/theme/app_theme.dart';

class MockDeliveryNotifierWithSave extends StateNotifier<DeliveryAgent>
    implements DeliveryNotifier {
  MockDeliveryNotifierWithSave(super.state);

  String? savedName;
  String? savedPhone;
  String? savedVehicle;
  String? savedVehicleNumber;
  String? savedZone;
  bool updateProfileCalled = false;

  @override
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? vehicle,
    String? vehicleNumber,
    String? assignedZone,
    String? profileImageUrl,
  }) async {
    updateProfileCalled = true;
    savedName = name;
    savedPhone = phone;
    savedVehicle = vehicle;
    savedVehicleNumber = vehicleNumber;
    savedZone = assignedZone;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Delivery Agent Profile Dialog — Read-Only Phone Verification', () {
    testWidgets(
        'Phone number field is displayed, strictly read-only, has lock icon & helper text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final agent = DeliveryAgent.empty('agent_auth_123').copyWith(
        name: 'Devendra Singh',
        phone: '+919876543210',
        vehicle: 'Honda Activa',
        vehicleNumber: 'MP 09 AB 1234',
        assignedZone: 'Vijay Nagar',
        status: DeliveryStatus.onDuty,
        isLoaded: true,
      );

      final notifier = MockDeliveryNotifierWithSave(agent);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentProvider.overrideWith((ref) => notifier),
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

      // Scroll to and tap Edit Details button
      final editButton = find.text('Edit Details');
      await tester.ensureVisible(editButton);
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Edit Profile Details'), findsOneWidget);

      // Verify Phone Number TextField
      final phoneFinder = find.byWidgetPredicate((widget) {
        if (widget is TextField) {
          final decoration = widget.decoration;
          if (decoration != null &&
              (decoration.labelText?.contains('Phone Number') ?? false)) {
            return true;
          }
        }
        return false;
      });

      expect(phoneFinder, findsOneWidget);
      final phoneField = tester.widget<TextField>(phoneFinder);

      // Verify readOnly is true and interactive selection is disabled
      expect(phoneField.readOnly, isTrue,
          reason: 'Phone field MUST be read-only');
      expect(phoneField.enableInteractiveSelection, isFalse,
          reason: 'Interactive selection must be disabled on read-only phone');

      // Verify initial displayed phone value is the authenticated agent phone
      expect(phoneField.controller?.text, equals('+919876543210'));

      // Verify lock suffix icon and helper text
      final decoration = phoneField.decoration!;
      expect(decoration.labelText, equals('Phone Number (Read-Only)'));
      expect(decoration.helperText, equals('Linked to authenticated account'));
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Verify other fields remain editable (readOnly == false)
      final nameFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Full Name') ?? false));
      expect(nameFinder, findsOneWidget);
      final nameField = tester.widget<TextField>(nameFinder);
      expect(nameField.readOnly, isFalse, reason: 'Full Name must be editable');

      final vehicleFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Model') ?? false));
      expect(vehicleFinder, findsOneWidget);
      final vehicleField = tester.widget<TextField>(vehicleFinder);
      expect(vehicleField.readOnly, isFalse,
          reason: 'Vehicle Model must be editable');

      final plateFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Plate') ?? false));
      expect(plateFinder, findsOneWidget);
      final plateField = tester.widget<TextField>(plateFinder);
      expect(plateField.readOnly, isFalse,
          reason: 'Vehicle Plate must be editable');

      final zoneFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Delivery Zone') ?? false));
      expect(zoneFinder, findsOneWidget);
      final zoneField = tester.widget<TextField>(zoneFinder);
      expect(zoneField.readOnly, isFalse,
          reason: 'Delivery Zone must be editable');
    });

    testWidgets(
        'Saving profile preserves authenticated phone number and saves editable fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final agent = DeliveryAgent.empty('agent_auth_123').copyWith(
        name: 'Devendra Singh',
        phone: '+919876543210',
        vehicle: 'Honda Activa',
        vehicleNumber: 'MP 09 AB 1234',
        assignedZone: 'Vijay Nagar',
        status: DeliveryStatus.onDuty,
        isLoaded: true,
      );

      final notifier = MockDeliveryNotifierWithSave(agent);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open dialog
      final editButton = find.text('Edit Details');
      await tester.ensureVisible(editButton);
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Edit name
      final nameFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Full Name') ?? false));
      await tester.enterText(nameFinder, 'Vikram Sharma');

      // Edit vehicle
      final vehicleFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Model') ?? false));
      await tester.enterText(vehicleFinder, 'Hero Splendor');

      // Edit plate
      final plateFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Plate') ?? false));
      await tester.enterText(plateFinder, 'MP 09 CD 5678');

      // Edit zone
      final zoneFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Delivery Zone') ?? false));
      await tester.enterText(zoneFinder, 'Palasia');

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify updateProfile was called
      expect(notifier.updateProfileCalled, isTrue);

      // CRITICAL: Phone number saved MUST preserve the authenticated phone number
      expect(notifier.savedPhone, equals('+919876543210'));

      // Other fields were successfully updated with user edits
      expect(notifier.savedName, equals('Vikram Sharma'));
      expect(notifier.savedVehicle, equals('Hero Splendor'));
      expect(notifier.savedVehicleNumber, equals('MP 09 CD 5678'));
      expect(notifier.savedZone, equals('Palasia'));
    });

    testWidgets('Gracefully handles missing phone number without crashing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Agent with empty phone number
      final agent = DeliveryAgent.empty('agent_no_phone').copyWith(
        name: 'New Rider',
        phone: '',
        vehicle: 'Bike',
        vehicleNumber: 'MP 09 XY 9999',
        assignedZone: 'Bhawarkua',
        status: DeliveryStatus.onDuty,
        isLoaded: true,
      );

      final notifier = MockDeliveryNotifierWithSave(agent);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deliveryAgentProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // When profile is incomplete, the "Setup" button is prominently displayed
      final setupButton = find.text('Setup');
      expect(setupButton, findsOneWidget);
      await tester.tap(setupButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile Details'), findsOneWidget);

      final phoneFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Phone Number') ?? false));
      expect(phoneFinder, findsOneWidget);
      final phoneField = tester.widget<TextField>(phoneFinder);

      // Shows 'No phone linked' as hintText
      expect(phoneField.decoration?.hintText, equals('No phone linked'));
      expect(phoneField.readOnly, isTrue);

      // Enter valid fields and save
      final nameFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Full Name') ?? false));
      await tester.enterText(nameFinder, 'New Rider');

      final vehicleFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Model') ?? false));
      await tester.enterText(vehicleFinder, 'Hero Splendor');

      final plateFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Vehicle Plate') ?? false));
      await tester.enterText(plateFinder, 'MP 09 XY 9999');

      final zoneFinder = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText?.contains('Delivery Zone') ?? false));
      await tester.enterText(zoneFinder, 'Bhawarkua');

      // Save without error even when phone is empty
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.updateProfileCalled, isTrue);
      expect(notifier.savedName, equals('New Rider'));
    });
  });
}
