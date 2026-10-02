import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/features/profile/legal_policies_screen.dart';
import 'package:dairy_app/features/profile/dpdp_data_protection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DPDP & Data Protection Content & Legal Rules Verification', () {
    test('Contains all 20 required DPDP statutory areas', () {
      const content = dpdpDataProtectionContent;

      expect(content.contains('1. LAWFUL GROUNDS FOR PROCESSING'), isTrue);
      expect(content.contains('2. CERTAIN LEGITIMATE USES'), isTrue);
      expect(content.contains('3. GENERAL DUTIES OF THE DATA FIDUCIARY'), isTrue);
      expect(content.contains('4. DATA PROCESSORS AND CONTRACTS'), isTrue);
      expect(content.contains('5. DATA ACCURACY'), isTrue);
      expect(content.contains('6. REASONABLE SECURITY SAFEGUARDS'), isTrue);
      expect(content.contains('7. TECHNICAL AND ORGANISATIONAL MEASURES'), isTrue);
      expect(content.contains('8. PERSONAL DATA BREACH NOTIFICATION'), isTrue);
      expect(content.contains('9. RETENTION AND PURPOSE LIMITATION'), isTrue);
      expect(content.contains("10. CHILDREN'S PERSONAL DATA"), isTrue);
      expect(content.contains('11. RIGHT TO ACCESS INFORMATION'), isTrue);
      expect(content.contains('12. GRIEVANCE REDRESSAL'), isTrue);
      expect(content.contains('13. RIGHT TO NOMINATE'), isTrue);
      expect(content.contains('14. CONSENT MANAGERS'), isTrue);
      expect(content.contains('15. PROCESSING OUTSIDE INDIA'), isTrue);
      expect(content.contains('16. SIGNIFICANT DATA FIDUCIARY (SDF) STATUS'), isTrue);
      expect(content.contains('17. DATA PROTECTION OFFICER (DPO)'), isTrue);
      expect(content.contains('18. DATA PROTECTION IMPACT ASSESSMENT (DPIA)'), isTrue);
      expect(content.contains('19. INDEPENDENT DATA AUDIT'), isTrue);
      expect(content.contains('20. DATA PROTECTION BOARD OF INDIA'), isTrue);
    });

    test('Strictly adheres to neutral source-supported wording and disclaimers', () {
      const content = dpdpDataProtectionContent;

      // 1. Phased regulatory staging with 13 May 2027 milestone
      expect(content.contains('13 May 2027'), isTrue);

      // 2. Uses full official terminology without inventing DPBI abbreviation
      expect(content.contains('Data Protection Board of India'), isTrue);
      expect(content.contains('DPBI'), isFalse);

      // 3. Neutral source-supported SDF requirements (not independently classifying Sawariya Dairy)
      expect(
        content.contains('Entities notified or designated as Significant Data Fiduciaries are subject to additional statutory obligations'),
        isTrue,
      );

      // 4. Neutral source-supported DPO requirement
      expect(
        content.contains('The requirement to appoint a statutory Data Protection Officer applies where an entity is designated as a Significant Data Fiduciary'),
        isTrue,
      );

      // 5. Neutral source-supported DPIA requirement
      expect(
        content.contains('Formal Data Protection Impact Assessments are required where an entity is classified as a Significant Data Fiduciary'),
        isTrue,
      );

      // 6. Neutral source-supported independent data audit requirement
      expect(
        content.contains('Mandatory independent data audits apply where an entity is designated as a Significant Data Fiduciary'),
        isTrue,
      );

      // 7. Verified contact channel without inventing a Grievance Team or DPO
      expect(content.contains('SAWARIYA SARKAR DAIRY LLP'), isTrue);
      expect(content.contains('support@sawariyasdairy.com'), isTrue);
      expect(content.contains('9896703884'), isTrue);
      expect(content.contains('Ground Floor, Khewat No. 253/260'), isTrue);
      expect(content.contains('Farukh Nagar Road, Tajnagar'), isTrue);
      expect(content.contains('Gurugram, Haryana'), isTrue);
    });

    test('Specifically prevents unsupported company-specific legal claims', () {
      const content = dpdpDataProtectionContent;

      // Prohibited: claiming Sawariya Dairy is not an SDF
      expect(content.contains('is not an SDF'), isFalse);
      expect(content.contains('NOT classified as a Significant Data Fiduciary'), isFalse);
      expect(content.contains('not an SDF'), isFalse);

      // Prohibited: claiming no DPO exists
      expect(content.contains('no statutory DPO'), isFalse);
      expect(content.contains('no DPO'), isFalse);
      expect(content.contains('not legally mandated to appoint a statutory DPO'), isFalse);

      // Prohibited: claiming DPIA is not mandated for the company
      expect(content.contains('DPIA not mandated'), isFalse);
      expect(content.contains('formal statutory DPIAs are not legally required'), isFalse);

      // Prohibited: claiming independent audit is not mandated for the company
      expect(content.contains('independent audit not mandated'), isFalse);
      expect(content.contains('formal independent statutory data audits are not required by law'), isFalse);

      // Prohibited: claiming strict non-collection of children's data
      expect(content.contains('strict non-collection'), isFalse);

      // Prohibited: claiming verified enterprise cloud processing agreements
      expect(content.contains('enterprise cloud processing agreements'), isFalse);

      // Prohibited: claiming verified standard contractual safeguards for cross-border
      expect(content.contains('standard contractual safeguards'), isFalse);

      // Prohibited: inventing a dedicated Grievance Team
      expect(content.contains('Grievance Team'), isFalse);
    });
  });

  group('LegalPoliciesScreen Tab 5 (DPDP & Data Protection) Integration Tests', () {
    testWidgets('Tab 5 renders DPDP & Data Protection header and all sections',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPoliciesScreen(initialTabIndex: 5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tab bar and Header
      expect(find.text('DPDP & Data Protection'), findsWidgets);

      // Notice Card
      expect(
        find.text('Staged Regulatory Implementation Notice'),
        findsOneWidget,
      );

      // Key content presence
      expect(
        find.textContaining('LAWFUL GROUNDS FOR PROCESSING'),
        findsOneWidget,
      );
      expect(
        find.textContaining('DATA PROTECTION BOARD OF INDIA'),
        findsOneWidget,
      );

      // Verified contact card
      expect(
        find.text('Data Protection Contact & Inquiries'),
        findsOneWidget,
      );
      expect(find.textContaining('support@sawariyasdairy.com'), findsWidgets);
      expect(find.textContaining('9896703884'), findsWidgets);

      // Preservation of "Open Online" removal
      expect(find.text('Open Online'), findsNothing);
    });

    testWidgets('LegalPoliciesScreen Tab 5 is responsive on mobile viewport (360x800)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: LegalPoliciesScreen(initialTabIndex: 5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DPDP & Data Protection'), findsWidgets);
    });

    testWidgets('Standalone DpdpDataProtectionScreen renders with zero overflow on desktop (1200x800)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DpdpDataProtectionScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DPDP & Data Protection'), findsWidgets);
      expect(find.text('Open Online'), findsNothing);
    });
  });
}
