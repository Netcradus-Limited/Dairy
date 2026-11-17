import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import 'account_deletion_screen.dart';
import 'dpdp_data_protection_screen.dart';
import 'terms_and_conditions_screen.dart';

/// Screen displaying in-app legal policies, store disclosures, and web links.
class LegalPoliciesScreen extends StatelessWidget {
  final int initialTabIndex;
  const LegalPoliciesScreen({super.key, this.initialTabIndex = 0});

  void _handleBackOrHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey(initialTabIndex),
      length: 6,
      initialIndex: initialTabIndex.clamp(0, 5),
      child: Title(
        title: 'Legal & Policies | Sawariya Dairy',
        color: AppColors.primary,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: false,
            title: Text(
              'Legal & Policies',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () => _handleBackOrHome(context),
            ),
            actions: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  tabs: const [
                    Tab(text: 'Privacy Policy'),
                    Tab(text: 'Terms & Conditions'),
                    Tab(text: 'Refund & Cancellation'),
                    Tab(text: 'Delivery Policy'),
                    Tab(text: 'Account Deletion'),
                    Tab(text: 'DPDP & Data Protection'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            children: [
              _buildPolicyTab(
                context: context,
                title: 'Privacy Policy',
                content: _privacyPolicyContent,
              ),
              _buildPolicyTab(
                context: context,
                title: 'Terms & Conditions',
                content: _termsContent,
              ),
              _buildPolicyTab(
                context: context,
                title: 'Refund & Cancellation Policy',
                content: _refundContent,
              ),
              _buildPolicyTab(
                context: context,
                title: 'Delivery Policy',
                content: _deliveryContent,
              ),
              _buildAccountDeletionTab(context),
              _buildDpdpTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Sawariya Dairy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'COD ONLY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SelectableText(
        content,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          height: 1.65,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPolicyTab({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabHeader(
                context: context,
                title: title,
                subtitle: 'Entity: SAWARIYA SARKAR DAIRY LLP',
              ),
              const SizedBox(height: AppSizes.p16),
              _buildContentCard(content),
              const SizedBox(height: AppSizes.p20),
              _buildWebFooter(context),
              const SizedBox(height: AppSizes.p32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDeletionTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabHeader(
                context: context,
                title: 'Account Deletion & Data Retention',
                subtitle: 'Entity: SAWARIYA SARKAR DAIRY LLP',
              ),
              const SizedBox(height: AppSizes.p16),
              _buildContentCard(_accountDeletionContent),
              const SizedBox(height: AppSizes.p16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.p20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to delete your account?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You can initiate permanent account deletion immediately inside the app. All active subscriptions will be cancelled.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.5,
                        color: const Color(0xFF7F1D1D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountDeletionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text('Proceed to Account Deletion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCancelled,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p20),
              _buildWebFooter(context),
              const SizedBox(height: AppSizes.p32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDpdpTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildDpdpHeaderCard(),
              const SizedBox(height: AppSizes.p16),
              buildDpdpStagingNoticeCard(),
              const SizedBox(height: AppSizes.p16),
              buildDpdpContentCard(dpdpDataProtectionContent),
              const SizedBox(height: AppSizes.p16),
              buildDpdpContactCard(),
              const SizedBox(height: AppSizes.p20),
              _buildWebFooter(context),
              const SizedBox(height: AppSizes.p32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            '© 2026 SAWARIYA SARKAR DAIRY LLP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          InkWell(
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.go('/privacy-policy');
              }
            },
            child: Text(
              'Privacy Policy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          InkWell(
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.go('/terms-and-conditions');
              }
            },
            child: Text(
              'Terms & Conditions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          InkWell(
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.go('/refund-policy');
              }
            },
            child: Text(
              'Refund Policy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          InkWell(
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.go('/delivery-policy');
              }
            },
            child: Text(
              'Delivery Policy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          InkWell(
            onTap: () {
              if (GoRouter.maybeOf(context) != null) {
                context.go('/home');
              }
            },
            child: Text(
              'Home',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const String _privacyPolicyContent = '''
1. DATA CONTROLLER & APP OVERVIEW
SAWARIYA SARKAR DAIRY LLP ("Sawariya Dairy", "we", "us", or "our") operates this mobile application and web platform to provide fresh milk, curd, paneer, and daily dairy delivery services. This Privacy Policy informs customers and delivery personnel about the categories of personal data we collect, how it is processed and shared, and the rights available under applicable Indian legal frameworks, including the Information Technology Act, 2000, the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011, and the Digital Personal Data Protection Act, 2023 (DPDP Act).

• Data Fiduciary / Operating Entity: SAWARIYA SARKAR DAIRY LLP
• Registered Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
• Contact Email: support@sawariyasdairy.com
• Contact Telephone / WhatsApp: 9896703884

Regulatory Staging Notice: The DPDP Act, 2023 and its statutory rules follow a phased implementation schedule established by the Central Government. We have structured this policy to align in good faith with core data protection principles while accurately reflecting the application's actual operational capabilities.

2. CATEGORIES OF PERSONAL DATA COLLECTED & SOURCES
We collect personal data directly from you and your device when you interact with the Sawariya Dairy platform:

• Authentication & Account Profile: Mobile telephone number used for One-Time Password (OTP) verification through Google Firebase Authentication. Upon profile creation, your name and optional email address are collected to manage your account and deliver service notices.
• Delivery Addresses: House/flat number, apartment or building name, street, locality, landmark, city, state, postal PIN code, and contact phone number, submitted by you to facilitate accurate physical deliveries.
• Device Location Data:
   - Customers: Precise device GPS coordinates are requested strictly on-demand only when you tap "Use Current Location" to assist in auto-populating delivery address details. Customer location is never tracked continuously or in the background. You can decline or revoke location permissions via your device settings at any time and enter address details manually.
   - Delivery Staff: Real-time GPS location is collected from delivery personnel exclusively while authenticated in a delivery partner account and only after the partner has explicitly started location sharing in the app while toggled "On Duty / Online". Sawariya Dairy does NOT request or hold the Android "Allow all the time" (background location) permission. Location sharing runs as an Android foreground service that displays an ongoing notification for the entire time location is being shared; sharing therefore continues between consecutive deliveries during an active shift if the app is minimized or the screen is locked, and is never performed without that notification being posted. (On Android 13 and later the operating system permits users to dismiss foreground-service notifications from the notification shade; dismissing the notification does not stop location sharing, which is stopped from within the app.) Location updates are used to coordinate dispatch routing and display live delivery tracking exclusively to authorized administrators and customers awaiting their currently active assigned order. Tracking ceases immediately when the delivery partner switches "Offline", takes a break, stops sharing, logs out, or closes the app (and completed/cancelled orders immediately revoke customer tracking visibility). Location is never collected when the app is closed or when the partner is off duty.
• Orders & Subscriptions: Ordered items, quantities, delivery slot preferences (morning and evening windows), subscription frequency (Daily, Alternate Day, Weekly, or custom schedules), delivery status history, and timestamps.
• Payments (Cash on Delivery Only): The application operates exclusively on a CASH ON DELIVERY (COD) basis. We record order pricing totals, applicable discounts, and cash collection confirmation upon handover. We do NOT collect, process, or store credit/debit card numbers, CVVs, net banking credentials, or UPI payment PINs, and we do not integrate an online payment gateway.
• Customer Support & Grievances: In-app support tickets collect ticket subject, category (such as late delivery, packaging, or quality concerns), description, and associated order references.
• Profile Photos & Storage: Camera or photo library access is requested through system pickers solely when you choose to upload or update a profile avatar (or delivery staff profile picture). Uploaded photos are stored in Google Firebase Storage. In-app complaint tickets collect text descriptions; photographic documentation requested for product quality verification may be sent directly to customer support via email or WhatsApp.
• Push Notifications: Firebase Cloud Messaging (FCM) device registration tokens are collected to deliver transactional order updates, delivery status alerts, and subscription notices to your device.

3. PURPOSES OF PROCESSING & LEGAL GROUNDS
Your personal data is processed for lawful, specified operational purposes:
• Fulfilling and delivering dairy orders and recurring subscriptions within our active service areas.
• Verifying user identity through SMS OTP for secure account access.
• Communicating order status updates, delivery partner arrival notices, and service alerts.
• Resolving customer inquiries, quality complaints, and grievances.
• Maintaining commercial invoices, billing records, and tax documentation required under applicable Indian statutory laws.
• Detecting, preventing, and addressing fraudulent orders or security incidents.
Processing is based on your consent provided upon account creation or order placement, and legitimate operational use necessary to perform requested delivery services and comply with statutory obligations.

4. THIRD-PARTY DATA PROCESSORS & INFRASTRUCTURE
We do not sell, rent, or trade your personal data to advertisers or third-party data brokers. We engage technical service providers to support specific platform functions:
• Google Cloud & Firebase: Core infrastructure services including Firebase Authentication, Cloud Firestore database, Firebase Cloud Storage, Cloud Functions, and Firebase Cloud Messaging (FCM). Where regional settings are configured, Indian regional data centers (such as Google Cloud's India regions) are utilized. Data processing by Google Cloud is subject to Google's applicable platform terms and security standards.
• India Post API: Public postal directory service (api.postalpincode.in) queried to validate PIN codes and retrieve corresponding post office districts.
• Photon Geocoder (Komoot): Geocoding service utilizing OpenStreetMap data (photon.komoot.io) to resolve GPS coordinates into approximate street and locality names.
• OpenStreetMap: Map tile services (tile.openstreetmap.org) utilized to render interactive delivery tracking maps.
Third-party providers process data solely as necessary to perform their respective technical functions.

5. DATA RETENTION & ACCOUNT DELETION
• Personal Data Erasure: When you initiate account deletion, your Firebase Authentication account is permanently deleted, your profile details (name, email, avatar reference) are de-identified, your saved addresses, shopping cart items, notification records, and FCM tokens are erased, and active subscriptions are cancelled immediately.
• Statutory Retention: In accordance with Indian commercial, tax, and accounting regulations, historical tax invoices, order line items, and Cash on Delivery payment totals are retained in a de-identified format strictly for statutory accounting and legal compliance, after which they are permanently purged.
• Backup Lifecycles: Routine system logs and database backup snapshots expire in accordance with standard cloud infrastructure lifecycle schedules.

6. YOUR PRIVACY RIGHTS & HOW TO EXERCISE THEM
Subject to applicable Indian legal requirements and phased statutory rollout schedules, you have the following rights regarding your personal data:
• Access & Correction: You may view and edit your profile details and saved delivery addresses directly within the application's Profile settings.
• Consent Withdrawal: You may withdraw consent for location access or push notifications at any time through your device operating system permissions.
• Account Deletion: You may request complete erasure of your account and eligible personal data through any of the following channels:
   - In-App: Go to Profile → Delete Account, review the disclosure, and tap "Permanently Delete Account".
   - Web Deletion Page: Visit ${AppStrings.accountDeletionUrl} to review deletion policies and submit a deletion request.
   - Email / Helpline Request: If you cannot log in or have uninstalled the app, email support@sawariyasdairy.com or call 9896703884 with your registered mobile phone number. After ownership verification, your account will be processed for deletion.

7. GRIEVANCE REDRESSAL & CONTACT INFORMATION
For privacy questions, data requests, or grievances concerning personal data processing, you may contact our Grievance Desk:

SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Helpline / WhatsApp: 9896703884
• Registered Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com

We review and address data privacy inquiries in accordance with applicable grievance response timelines under Indian law.
''';

  static String get _termsContent => TermsAndConditionsScreen.termsText;

  static const String _refundContent = '''
1. PAYMENT METHOD (COD ONLY)
• The app currently supports CASH ON DELIVERY ONLY.
• There is no normal online-payment refund process because current payment is COD.

2. ORDER CANCELLATION
• Customers may cancel an order before it enters preparation/delivery, subject to its current order status.
• Once a fresh/perishable order enters preparation or dispatch, cancellation may not be available.
• Subscription cancellation affects future eligible deliveries and does not automatically cancel already prepared or dispatched orders.
• Subscription deliveries may be paused, skipped, or modified prior to the applicable operational cutoff window.

3. QUALITY CONCERNS & DEFECTIVE / MISSING GOODS
• Fresh/perishable dairy products generally cannot be returned after successful delivery.
• Missing, damaged, leaking, spoiled, incorrect, or undelivered items can be reported to Support.
• Customers should report delivery/product issues within 24 hours of the scheduled delivery and provide photographs where relevant.
• Damaged, incorrect, missing, or quality-related complaints are subject to verification by Sawariya Dairy before approving a resolution.

4. RESOLUTION METHODS
• Approved complaints may be resolved through replacement, order adjustment, or another appropriate resolution agreed with Support.
• No refund is provided solely because a customer changes their mind after successful delivery of a perishable product.
• Approved adjustments or replacements are processed according to operational schedules in coordination with customer support.

5. CONTACT & GRIEVANCE REDRESSAL
• Company: SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone: 9896703884
• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';

  static const String _deliveryContent = '''
1. SERVICE AREAS & OPERATIONAL AVAILABILITY
• Delivery is available only in active Sawariya Dairy service areas and delivery corridors.
• Available delivery slots are shown during checkout according to operational availability (typically morning and evening delivery windows).

2. ACCURATE ADDRESS & PHONE NUMBER
• Customers must provide an accurate delivery address and reachable phone number.
• Customers must ensure reasonable physical access for the delivery agent (e.g., gate clearance, security access, designated drop area).

3. SUBSCRIPTIONS & CUTOFF TIMES
• Subscription deliveries may be paused or skipped prior to the applicable operational cutoff window.

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
1. RIGHT TO REQUEST DELETION
You have the right to request permanent deletion of your Sawariya Dairy account and erasure of your personal data.

2. WHAT IS ERASED UPON DELETION
• Firebase Authentication credentials and active session tokens.
• Profile personal details (customer name, email address, profile avatar reference).
• Saved delivery addresses and associated location coordinates.
• Active shopping cart items and saved delivery preferences.
• Push notification registration tokens (FCM tokens).
• Active recurring subscriptions are immediately cancelled so no future deliveries are scheduled.

3. WHAT IS RETAINED & STATUTORY LIMITATIONS
• Historical tax invoices, completed order line items, and Cash on Delivery payment totals are retained in a de-identified format to comply with statutory commercial accounting, taxation, and legal audit requirements under Indian law.
• Standard system infrastructure logs and database backup snapshots cycle out automatically in accordance with cloud service lifecycle schedules.

4. HOW TO INITIATE DELETION
• In-App (Recommended): Log in, navigate to Profile → Delete Account, review the confirmation details, and tap "Permanently Delete Account".
• Public Web Page: Visit our deletion page at ${AppStrings.accountDeletionUrl} to review deletion procedures and initiate your request.
• Email or Telephone Request: If you cannot access the application or have uninstalled it, you may submit a deletion request by emailing support@sawariyasdairy.com or calling 9896703884 with your registered mobile number. Following verification of account ownership, your deletion request will be processed.

5. GRIEVANCE & PRIVACY CONTACT
SAWARIYA SARKAR DAIRY LLP
• Support Email: support@sawariyasdairy.com
• Support Phone / WhatsApp: 9896703884
• Registered Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana
• Official Website: https://sawariyasdairy.com
''';
}
