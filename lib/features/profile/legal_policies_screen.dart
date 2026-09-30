import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import 'account_deletion_screen.dart';

/// Screen displaying in-app legal policies, store disclosures, and web links.
class LegalPoliciesScreen extends StatelessWidget {
  const LegalPoliciesScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $url'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Legal & Policies',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Privacy Policy'),
              Tab(text: 'Terms & Conditions'),
              Tab(text: 'Refund & Cancellation'),
              Tab(text: 'Delivery Policy'),
              Tab(text: 'Account Deletion'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPolicyTab(
              context: context,
              title: 'Privacy Policy',
              webUrl: AppStrings.privacyPolicyUrl,
              content: _privacyPolicyContent,
            ),
            _buildPolicyTab(
              context: context,
              title: 'Terms & Conditions',
              webUrl: AppStrings.termsConditionsUrl,
              content: _termsContent,
            ),
            _buildPolicyTab(
              context: context,
              title: 'Refund & Cancellation Policy',
              webUrl: AppStrings.refundPolicyUrl,
              content: _refundContent,
            ),
            _buildPolicyTab(
              context: context,
              title: 'Delivery Policy',
              webUrl: AppStrings.deliveryPolicyUrl,
              content: _deliveryContent,
            ),
            _buildAccountDeletionTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTab({
    required BuildContext context,
    required String title,
    required String webUrl,
    required String content,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(context, webUrl),
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Open Online'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Entity: SAWARIYA SARKAR DAIRY LLP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(height: 24),
              Text(
                content,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDeletionTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Account Deletion & Data Retention',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(context, AppStrings.accountDeletionUrl),
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Web Request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Entity: SAWARIYA SARKAR DAIRY LLP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(height: 24),
              Text(
                _accountDeletionContent,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.p16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to delete your account?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You can initiate permanent account deletion immediately inside the app. All active subscriptions will be cancelled.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF7F1D1D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountDeletionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCancelled,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Proceed to Account Deletion'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static const String _privacyPolicyContent = '''
1. DATA CONTROLLER & APP OVERVIEW
SAWARIYA SARKAR DAIRY LLP ("Sawariya Dairy") operates this mobile application to deliver fresh milk, curd, paneer, and dairy products to consumers. This policy explains what information is collected, how it is used, and your rights under applicable Indian data protection laws.
• Business Entity: SAWARIYA SARKAR DAIRY LLP [BUSINESS DECISION REQUIRED: Specify Registration / LLPIN / GSTIN]

2. INFORMATION WE COLLECT
• Authentication & Identity: Mobile phone number for SMS OTP login via Google Firebase Authentication. Customer name and optional email are collected to personalize your account.
• Delivery Addresses: House number, street/area, landmark, city, state, postal PIN code, and contact phone number.
• Location Data:
   - Customers: Device location is requested on-demand only when you tap "Use Current Location" to assist with delivery address entry.
   - Delivery Staff: Real-time GPS location is collected while on duty and online to provide active order tracking to customers.
• Orders & Subscriptions: Products ordered, quantities, delivery time slots, recurring subscription frequency (Daily, Alternate Day, Weekly), and order timestamps.
• Payments: The application supports CASH ON DELIVERY ONLY. We record order totals and collection status. We do NOT collect credit/debit card numbers, UPI PINs, or net banking credentials.
• Customer Support: Ticket subject, category, description, and order reference submitted through the in-app support module.
• Photos: Accessed via Camera or Photo Library solely when you upload a profile avatar or submit photographic evidence for missing, damaged, leaking, spoiled, or incorrect dairy items. Stored in Google Firebase Storage.
• Push Notifications: Firebase Cloud Messaging (FCM) tokens to deliver order status and delivery alerts.

3. HOW WE USE INFORMATION
Your data is used strictly to fulfill orders, schedule dairy subscriptions, deliver goods to active service zones [BUSINESS DECISION REQUIRED: Specify Active Service Areas], provide customer grievance redressal, and maintain statutory financial records.

4. THIRD-PARTY DATA PROCESSORS
We do not sell personal data. Technical service providers include:
• Google Cloud / Firebase (Authentication, Cloud Firestore database in India, Cloud Storage, Push Notifications)
• India Post API & Photon (postal PIN code lookup)
• OpenStreetMap (map tile rendering)

5. YOUR RIGHTS & ACCOUNT DELETION
You may review, update, or permanently delete your account and personal data at any time via Profile → Delete Account in the app or via our web deletion resource:
${AppStrings.accountDeletionUrl}
Data retention follows statutory compliance requirements [BUSINESS DECISION REQUIRED: Specify Retention Period, e.g., 7–8 years under statutory commercial law].

6. GRIEVANCE DESK & CONTACT DETAILS
SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';

  static const String _termsContent = '''
1. ACCEPTANCE OF TERMS
By accessing or using Sawariya Dairy, you agree to be bound by these Terms and Conditions governed by SAWARIYA SARKAR DAIRY LLP ("Sawariya Dairy").

2. ACCOUNT REGISTRATION & ACCURACY
• You must provide a valid Indian mobile number to register and receive OTP verification. You are responsible for maintaining the security of your device.
• Customers must provide an accurate delivery address and a reachable phone number to ensure successful delivery.

3. PAYMENT METHOD (CASH ON DELIVERY ONLY)
• The app currently supports CASH ON DELIVERY ONLY.
• Payment must be made directly to the delivery partner upon receipt of goods. Online payment gateways are not supported.

4. SERVICE AREAS & OPERATIONAL AVAILABILITY
• Delivery is available only in active Sawariya Dairy service areas [BUSINESS DECISION REQUIRED: Specify Active Service Zones / Cities].
• Available delivery slots are shown according to operational availability [BUSINESS DECISION REQUIRED: Specify Delivery Operating Hours].

5. PERISHABLE GOODS & RETURN RESTRICTIONS
• All milk, curd, paneer, and related dairy items are fresh, perishable food products.
• Fresh/perishable dairy products generally cannot be returned after successful delivery.
• No refund is provided solely because a customer changes their mind after successful delivery of a perishable product.

6. SUBSCRIPTIONS & CANCELLATIONS
• Subscription deliveries may be paused or skipped only when the applicable cutoff allows it [BUSINESS DECISION REQUIRED: Specify Daily Cutoff Time, e.g., 8:00 PM previous day].
• Customers may cancel an order before it enters preparation/delivery, subject to its current order status.
• Once a fresh/perishable order enters preparation or dispatch, cancellation may not be available.
• Subscription cancellation affects future eligible deliveries and does not automatically cancel already prepared or dispatched orders.

7. COMPLAINTS & ISSUE REPORTING
• Missing, damaged, leaking, spoiled, incorrect, or undelivered items can be reported to Support.
• Customers should report delivery/product issues within 24 hours of the scheduled delivery and provide photographs where relevant.
• Sawariya Dairy may verify the order before approving a replacement or appropriate resolution.

8. GOVERNING LAW & JURISDICTION
• These terms are governed by the laws of India.
• Any disputes are subject to the exclusive jurisdiction of the courts at [BUSINESS DECISION REQUIRED: Specify Legal Jurisdiction City, e.g., Gurugram, Haryana].

9. CONTACT INFORMATION
• Company: SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';

  static const String _refundContent = '''
1. PAYMENT METHOD (COD ONLY)
• The app currently supports CASH ON DELIVERY ONLY.
• There is no normal online-payment refund process because current payment is COD.

2. ORDER CANCELLATION
• Customers may cancel an order before it enters preparation/delivery, subject to its current order status.
• Once a fresh/perishable order enters preparation or dispatch, cancellation may not be available.
• Subscription cancellation affects future eligible deliveries and does not automatically cancel already prepared or dispatched orders.
• Subscription deliveries may be paused, skipped, or modified only when the applicable cutoff allows it [BUSINESS DECISION REQUIRED: Specify Cancellation Cutoff Time, e.g., 8:00 PM previous day].

3. QUALITY CONCERNS & DEFECTIVE / MISSING GOODS
• Fresh/perishable dairy products generally cannot be returned after successful delivery.
• Missing, damaged, leaking, spoiled, incorrect, or undelivered items can be reported to Support.
• Customers should report delivery/product issues within 24 hours of the scheduled delivery and provide photographs where relevant.
• Damaged, incorrect, missing, or quality-related complaints are subject to verification by Sawariya Dairy before approving a resolution.

4. RESOLUTION METHODS
• Approved complaints may be resolved through replacement, order adjustment, or another appropriate resolution agreed with Support.
• No refund is provided solely because a customer changes their mind after successful delivery of a perishable product.
• Approved adjustments or replacements are processed according to operational schedules [BUSINESS DECISION REQUIRED: Specify Resolution / Adjustment Timeline, e.g., 2–3 business days].

5. CONTACT & GRIEVANCE REDRESSAL
• Company: SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';

  static const String _deliveryContent = '''
1. SERVICE AREAS & OPERATIONAL AVAILABILITY
• Delivery is available only in active Sawariya Dairy service areas [BUSINESS DECISION REQUIRED: Specify Active Service Zones / Cities].
• Available delivery slots are shown according to operational availability [BUSINESS DECISION REQUIRED: Specify Delivery Operating Hours].

2. ACCURATE ADDRESS & PHONE NUMBER
• Customers must provide an accurate delivery address and reachable phone number.
• Customers must ensure reasonable physical access for the delivery agent (e.g., gate clearance, security access, designated drop area).

3. SUBSCRIPTIONS & CUTOFF TIMES
• Subscription deliveries may be paused or skipped only when the applicable cutoff allows it [BUSINESS DECISION REQUIRED: Specify Daily Cutoff Time, e.g., 8:00 PM previous day].

4. CUSTOMER UNAVAILABILITY & ATTEMPTED DELIVERY
• If the customer is unavailable, delivery may be retried or marked unsuccessful according to operational availability.

5. NON-RETURNABLE PERISHABLE GOODS
• Fresh/perishable dairy products generally cannot be returned after successful delivery.

6. REPORTING DELIVERY & PRODUCT ISSUES
• Missing, damaged, leaking, spoiled, incorrect, or undelivered items can be reported to Support.
• Customers should report delivery/product issues within 24 hours of the scheduled delivery and provide photographs where relevant.
• Sawariya Dairy may verify the order before approving a replacement or refund resolution.

7. CONTACT & SUPPORT
• Company: SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';

  static const String _accountDeletionContent = '''
1. RIGHT TO ERASURE
You have the right to permanently delete your Sawariya Dairy account and erase your personal data.

2. WHAT IS DELETED IMMEDIATELY
• Firebase Authentication credentials and active login sessions.
• Personal profile information (name, avatar, email).
• Saved delivery addresses and GPS coordinates.
• Shopping cart items and device push notification registration tokens.
• Active recurring subscriptions are immediately cancelled.

3. WHAT IS RETAINED & STATUTORY JUSTIFICATION
In accordance with Indian tax, GST, and commercial accounting regulations, historical invoices, order line items, and Cash on Delivery payment records are retained in a de-identified format strictly for statutory accounting compliance [BUSINESS DECISION REQUIRED: Specify Retention Period, e.g., 7–8 years under statutory commercial law].

4. HOW TO INITIATE DELETION
• In-App: Tap the "Proceed to Account Deletion" button below.
• Web Request: Visit our public deletion page:
  ${AppStrings.accountDeletionUrl}

5. GRIEVANCE & PRIVACY DESK
SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';
}
