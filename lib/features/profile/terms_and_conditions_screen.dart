import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

/// Public Web & In-App Terms & Conditions Screen for Sawariya Dairy.
///
/// Route: /terms-and-conditions
/// Accessible publicly on https://sawariyasdairy.com/terms-and-conditions
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  Future<void> _launchExternalUrl(BuildContext context, String url) async {
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

  void _handleBackOrHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Title(
      title: 'Terms & Conditions | Sawariya Dairy',
      color: AppColors.primary,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () => _handleBackOrHome(context),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.policy_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Terms & Conditions',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Home'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: AppColors.divider,
              height: 1,
            ),
          ),
        ),
        body: SingleChildScrollView(
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
                  // ─── Header Info Card ───
                  _buildHeaderCard(context),
                  const SizedBox(height: AppSizes.p20),

                  // ─── Document Content (23 Sections) ───
                  _buildSectionsCard(),
                  const SizedBox(height: AppSizes.p20),

                  // ─── Contact & Support Card ───
                  _buildContactCard(context),
                  const SizedBox(height: AppSizes.p24),

                  // ─── Web Footer ───
                  _buildWebFooter(context),
                  const SizedBox(height: AppSizes.p20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Official Legal Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'COD ONLY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'SAWARIYA SARKAR DAIRY LLP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Terms & Conditions of Service',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _buildMetaItem(
                icon: Icons.language_rounded,
                label: 'Website',
                value: 'sawariyasdairy.com',
              ),
              _buildMetaItem(
                icon: Icons.payments_outlined,
                label: 'Payment Mode',
                value: 'Cash on Delivery Only',
              ),
              _buildMetaItem(
                icon: Icons.email_outlined,
                label: 'Support Email',
                value: 'support@sawariyasdairy.com',
              ),
              _buildMetaItem(
                icon: Icons.phone_outlined,
                label: 'Helpline',
                value: '9896703884',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p24),
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
        children: termsSections.map((sec) => _buildSectionItem(sec)).toList(),
      ),
    );
  }

  Widget _buildSectionItem(_TermsSection sec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${sec.number}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sec.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Text(
              sec.body,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                height: 1.65,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Customer Support & Inquiries',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'For any questions or clarifications regarding these Terms & Conditions, please reach out to our support team:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _launchExternalUrl(
                  context,
                  'mailto:${AppStrings.supportEmail}',
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: const Text('Email Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _launchExternalUrl(
                  context,
                  'tel:${AppStrings.supportPhone}',
                ),
                icon: const Icon(Icons.phone_outlined, size: 16),
                label: const Text('Call 9896703884'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
      child: Column(
        children: [
          Wrap(
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
                onTap: () => context.go('/terms-and-conditions'),
                child: Text(
                  'Terms & Conditions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Text('•', style: TextStyle(color: AppColors.textSecondary)),
              InkWell(
                onTap: () => _launchExternalUrl(
                  context,
                  AppStrings.privacyPolicyUrl,
                ),
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
                onTap: () => context.go('/home'),
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
        ],
      ),
    );
  }

  /// Full 23-section plain text for reuse in LegalPoliciesScreen or exports.
  static String get termsText {
    final buffer = StringBuffer();
    for (final sec in termsSections) {
      buffer.writeln('${sec.number}. ${sec.title.toUpperCase()}');
      buffer.writeln(sec.body);
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// The 23 structured sections matching all confirmed operational rules.
  static const List<_TermsSection> termsSections = [
    _TermsSection(
      1,
      'Introduction',
      'Welcome to Sawariya Dairy. These Terms and Conditions ("Terms") govern your access to and use of the Sawariya Dairy website located at https://sawariyasdairy.com, our mobile application, and all related dairy ordering and fulfillment services (collectively, the "Services"). The Services are owned and operated by SAWARIYA SARKAR DAIRY LLP ("Sawariya Dairy", "we", "us", or "our"). Please read these Terms thoroughly before using our Services.',
    ),
    _TermsSection(
      2,
      'Acceptance of Terms',
      'By accessing, browsing, registering for, or using our website, mobile application, or ordering services, you acknowledge that you have read, understood, and agree to be legally bound by these Terms and Conditions and our Privacy Policy. If you do not agree to these Terms, you must discontinue your access and refrain from using the Services.',
    ),
    _TermsSection(
      3,
      'About Sawariya Dairy',
      'Sawariya Dairy is operated by SAWARIYA SARKAR DAIRY LLP, a dairy delivery business offering fresh milk, curd, paneer, and other farm-sourced dairy essentials.\n'
          '• Business Entity: SAWARIYA SARKAR DAIRY LLP\n'
          '• Registered Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana\n'
          '• Official Website: https://sawariyasdairy.com\n'
          '• Support Email: support@sawariyasdairy.com\n'
          '• Support Phone: 9896703884',
    ),
    _TermsSection(
      4,
      'Eligibility and Customer Account',
      'To access our Services and place orders, you must be legally capable of entering into binding contracts under applicable law.\n'
          '• Registration: Account creation requires a valid Indian mobile telephone number verified through One-Time Password (OTP).\n'
          '• Account Security: You are solely responsible for maintaining the confidentiality of your device and login credentials, and for all activities conducted under your account.\n'
          '• Accurate Profile: You agree to provide true, accurate, current, and complete profile information and promptly update your details upon any changes.',
    ),
    _TermsSection(
      5,
      'Customer Responsibilities',
      '• Delivery Address: Customers must provide a complete and accurate delivery address, including building/flat number, street, landmark, and valid postal PIN code, together with an active and reachable contact phone number.\n'
          '• Physical Access: Customers must ensure reasonable physical access for our delivery partners at the delivery premises, including society gate clearances or designated drop spots.\n'
          '• Order Verification: Customers are responsible for inspecting delivered goods upon handover to verify item counts and packaging condition.',
    ),
    _TermsSection(
      6,
      'Products and Availability',
      '• Fresh Farm Dairy: We supply fresh milk, curd, paneer, and related dairy products. As these are natural dairy items, minor variations in taste, appearance, or seasonal fat composition may occur.\n'
          '• Informational Listings: Images and descriptions on the website and app are provided for reference; physical packaging may differ.\n'
          '• Availability: All products are subject to operational and inventory availability. In the event an ordered item is unavailable, we will notify you and adjust the order accordingly.',
    ),
    _TermsSection(
      7,
      'Orders',
      '• Placing Orders: Customers may place single on-demand orders or configure recurring subscriptions through the Sawariya Dairy platform.\n'
          '• Operational Acceptance: All orders placed through the platform are subject to product availability and operational availability.\n'
          '• Confirmation Process: Order confirmation depends on the business\'s operational process, route capacity, and delivery partner assignment. Sawariya Dairy reserves the right to decline or cancel any order that cannot be fulfilled due to supply constraints or unserviceable locations.',
    ),
    _TermsSection(
      8,
      'Pricing and Charges',
      '• Price Display: Product prices are stated in Indian Rupees (₹) and displayed on product and checkout screens prior to order placement.\n'
          '• Taxes and Delivery: Stated prices include applicable taxes. Any applicable delivery charges are clearly presented before order confirmation.\n'
          '• Price Adjustments: Prices are subject to revision based on seasonal market rates and operational costs. Updated prices apply to future orders and subsequent subscription delivery cycles.',
    ),
    _TermsSection(
      9,
      'Cash on Delivery (COD Only)',
      '• Sole Payment Method: Sawariya Dairy operates on a CASH ON DELIVERY (COD) ONLY basis.\n'
          '• Payment at Handover: Payment must be made in cash directly to the authorized delivery partner upon physical receipt of goods.\n'
          '• No Online Payment Gateway: We do not integrate, process, or support online payment gateways. We do not accept credit cards, debit cards, net banking, or online UPI gateway payments. No financial card or banking credentials are ever collected or stored on our platform.\n'
          '• Cash Readiness: Customers must ensure they have exact or appropriate cash ready when receiving their delivery to facilitate timely handover.',
    ),
    _TermsSection(
      10,
      'Delivery',
      '• Active Service Areas: Delivery is available only within designated active Sawariya Dairy service areas.\n'
          '• Operational Slots: Available delivery slots depend on operational availability and route scheduling.\n'
          '• Contactability: Customers must provide an accurate delivery address and reachable phone number to ensure successful delivery.\n'
          '• No Guaranteed Delivery Time: While we endeavor to deliver fresh dairy during scheduled windows, we do not promise or guarantee a specific delivery time due to factors such as weather, traffic, or road conditions.\n'
          '• Customer Unavailability: If a customer is unavailable at the delivery address at the scheduled delivery time, the order may be handled according to the company\'s operational/retry process.',
    ),
    _TermsSection(
      11,
      'Subscription Orders',
      '• Recurring Services: Subscription services may be available for eligible dairy products (e.g., Daily, Alternate Day, or custom schedules).\n'
          '• Operational Cutoff: Pausing, skipping, or modifying subscription deliveries is subject to the applicable operational cutoff window.\n'
          '• Future Deliveries: Cancelling a subscription applies to eligible future deliveries and does not automatically cancel orders that have already entered preparation or dispatch.',
    ),
    _TermsSection(
      12,
      'Cancellation',
      '• Order Status Timing: Customers may request order cancellation before preparation/dispatch, subject to the order\'s current status.\n'
          '• In-Flight Orders: Once an order has entered preparation or dispatch, cancellation may no longer be available.\n'
          '• Preparation Cutoff: Cancellation cannot be guaranteed after fresh perishable items have been prepared and packed for delivery.',
    ),
    _TermsSection(
      13,
      'Fresh and Perishable Products',
      '• Perishable Nature: Fresh dairy products (milk, curd, paneer) are highly perishable food items requiring immediate and proper refrigeration upon delivery.\n'
          '• Non-Returnable: Perishable products generally cannot be returned after successful delivery.\n'
          '• Change-of-Mind: Change-of-mind returns or refunds are not available after successful delivery of perishable products.',
    ),
    _TermsSection(
      14,
      'Complaints and Quality Issues',
      '• Inspection: Customers should inspect their delivered dairy items immediately upon delivery.\n'
          '• 24-Hour Window: Customers must report missing items, damaged items, leaking items, spoiled/quality issues, incorrect items, or undelivered orders within 24 hours of the scheduled delivery.\n'
          '• Evidence: Photographic evidence of the issue may be requested where relevant to assist verification.\n'
          '• Verification: All complaints and quality reports are subject to verification by Sawariya Dairy before any resolution is approved.',
    ),
    _TermsSection(
      15,
      'Refunds, Replacements and Order Adjustments',
      '• COD Resolution: Because transactions are conducted exclusively via Cash on Delivery, there is no online payment refund mechanism.\n'
          '• Resolution Options: Depending on the verified issue and circumstances, Sawariya Dairy may provide a replacement, an order adjustment on an upcoming delivery, or another appropriate operational resolution.\n'
          '• No Guaranteed Timeline: We do not promise a fixed refund or resolution timeline, but approved claims are handled in accordance with operational schedules.',
    ),
    _TermsSection(
      16,
      'User Conduct',
      'Users agree to utilize the Services for lawful, personal purposes and agree NOT to:\n'
          '• Provide fictitious, inaccurate, or deceptive delivery addresses or contact details;\n'
          '• Harass, abuse, threaten, or mistreat delivery personnel, customer service representatives, or staff;\n'
          '• Place fraudulent orders or repeatedly refuse to receive and pay for legitimate Cash on Delivery orders;\n'
          '• Attempt to disrupt, compromise, or reverse-engineer the platform\'s technology infrastructure or security.',
    ),
    _TermsSection(
      17,
      'Account Suspension or Termination',
      '• Termination Rights: Sawariya Dairy reserves the right to suspend or terminate accounts, refuse orders, or restrict service access in instances of suspected fraud, abusive conduct towards staff or delivery partners, repeated refusal of COD orders, or violation of these Terms.\n'
          '• Account Deletion: Customers may delete their account at any time using the in-app profile settings or our web account deletion request page.',
    ),
    _TermsSection(
      18,
      'Intellectual Property',
      'All content, trademarks, logos, brand names, graphics, interface elements, and software associated with Sawariya Dairy and SAWARIYA SARKAR DAIRY LLP are our proprietary property or licensed to us. Unauthorized copying, modification, or distribution of platform materials without prior written consent is strictly prohibited.',
    ),
    _TermsSection(
      19,
      'Third-Party Services',
      'Our Services may link to or rely on third-party technological infrastructure, including cloud database hosting, telecommunications carriers, postal pincode databases, or mapping services. Sawariya Dairy is not responsible for independent third-party service interruptions or terms.',
    ),
    _TermsSection(
      20,
      'Privacy',
      'Your privacy is important to us. Our data handling practices, including information collection, address usage, and data security, are described in our Privacy Policy accessible at https://sawariyasdairy.com/privacy-policy and within the app. By using the Services, you consent to such processing.',
    ),
    _TermsSection(
      21,
      'Limitation of Liability',
      'To the fullest extent permitted by applicable law, SAWARIYA SARKAR DAIRY LLP, its partners, employees, and agents shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your access to or use of the Services.\n'
          '• Storage: Sawariya Dairy is not liable for spoilage or degradation caused by a customer\'s failure to refrigerate perishable products promptly upon delivery.',
    ),
    _TermsSection(
      22,
      'Changes to These Terms',
      'Sawariya Dairy reserves the right to update or modify these Terms and Conditions periodically to reflect changes in our operational procedures, services, or legal obligations. Updated Terms will be posted on this page with an updated effective date. Continued use of our Services following any updates constitutes acceptance of the modified Terms.',
    ),
    _TermsSection(
      23,
      'Contact Information',
      'For any questions, concerns, complaints, or legal notices regarding these Terms & Conditions, please contact us:\n'
          '• Operating Entity: SAWARIYA SARKAR DAIRY LLP\n'
          '• Official Website: https://sawariyasdairy.com\n'
          '• Support Email: support@sawariyasdairy.com\n'
          '• Support Phone: 9896703884\n'
          '• Business Address: Ground Floor, Khewat No. 253/260, Farukh Nagar Road, Tajnagar, Gurugram, Haryana\n'
          '• Payment Method: CASH ON DELIVERY ONLY',
    ),
  ];
}

class _TermsSection {
  final int number;
  final String title;
  final String body;

  const _TermsSection(this.number, this.title, this.body);
}
