import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

/// Full statutory content covering all 20 DPDP Act (2023) areas from the founder guide
/// using neutral, source-supported language without unverified legal claims.
const String dpdpDataProtectionContent = '''
SAWARIYA SARKAR DAIRY LLP — DPDP & DATA PROTECTION POLICY
Framework Under the Digital Personal Data Protection Act, 2023

IMPORTANT REGULATORY TIMELINE & STAGING DISCLOSURE:
The Digital Personal Data Protection Act, 2023 (DPDP Act) and its statutory rules follow a phased, staged implementation roadmap in India. Under this transition framework, most day-to-day compliance duties and operational obligations detailed in this guide are scheduled for 13 May 2027.

This document outlines the 20 statutory areas described in the DPDP founder framework, explaining the applicable legal principles alongside Sawariya Dairy's operational practices for order delivery and customer communication.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. LAWFUL GROUNDS FOR PROCESSING (CONSENT & LEGITIMATE USE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Under the DPDP Act, digital personal data may only be processed for a lawful purpose upon obtaining the Data Principal's freely given, specific, informed, unconditional, and unambiguous consent with a clear affirmative action, or for certain statutorily recognized legitimate uses. Any request for consent must be accompanied or preceded by an itemised notice in clear and plain language.
• Implementation & Application: Customer personal data (such as name, mobile number, and delivery address) is provided by users upon account creation or order placement to enable milk delivery and subscription services. Data Principals may request account deletion or update their details in the application.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. CERTAIN LEGITIMATE USES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Section 7 of the DPDP Act provides specified grounds where personal data may be processed without obtaining separate consent. These include situations where the Data Principal voluntarily provides personal data for a specified purpose without indicating that they do not consent, compliance with judicial judgments or statutory orders, medical emergencies, safety, and employment or contractor management.
• Implementation & Application: Legitimate use grounds apply where customers voluntarily provide delivery coordinates and instructions for fulfilling requested orders, or where records are maintained to comply with applicable statutory commercial and billing laws.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. GENERAL DUTIES OF THE DATA FIDUCIARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: The Data Fiduciary is responsible for complying with the provisions of the Act for any data processing undertaken by it or on its behalf by a Data Processor.
• Implementation & Application: Sawariya Sarkar Dairy LLP operates as a Data Fiduciary in respect of personal data submitted by users for dairy subscription and order fulfillment services.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. DATA PROCESSORS AND CONTRACTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: A Data Fiduciary may engage or direct a Data Processor to process personal data on its behalf only under a valid contract. Where processors handle personal data, appropriate contracts and security arrangements are required to ensure compliance with the Act.
• Implementation & Application: Where technical service providers or cloud platforms are utilized to host databases or support app functionality, such processing is subject to applicable terms and data protection standards governing service providers.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
5. DATA ACCURACY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Data Fiduciaries must take reasonable measures to ensure that personal data processed by or on behalf of the fiduciary is accurate, complete, and consistent if used to make decisions affecting the Data Principal or if disclosed to another Data Fiduciary.
• Implementation & Application: Customers can review and update their delivery address, phone number, and account details directly in the profile settings before placing orders or cutoff times.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
6. REASONABLE SECURITY SAFEGUARDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Data Fiduciaries are required to implement reasonable security safeguards to protect personal data and prevent personal data breaches, unauthorized access, or loss.
• Implementation & Application: The application uses secure network transmission protocols (HTTPS/TLS) and authentication controls. Transactions operate on a Cash on Delivery (COD) basis, and the application does not collect, process, or store credit card numbers, debit card details, net banking credentials, or UPI payment PINs.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7. TECHNICAL AND ORGANISATIONAL MEASURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Data Fiduciaries must adopt appropriate technical and organizational measures to ensure effective compliance with the provisions of the Act.
• Implementation & Application: Access to order delivery details is restricted based on operational roles, providing delivery personnel with the delivery address and contact information necessary to execute morning deliveries.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8. PERSONAL DATA BREACH NOTIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: In the event of a personal data breach, the Data Fiduciary is mandated to notify the Data Protection Board of India and each affected Data Principal in the form and manner prescribed under the Act and applicable rules.
• Implementation & Application: In the event of a qualifying security breach involving personal data, notification will be provided to the Data Protection Board of India and impacted users in accordance with statutory procedures.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9. RETENTION AND PURPOSE LIMITATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Personal data must be erased when the specified purpose for which it was collected is no longer being served or upon withdrawal of consent by the Data Principal, unless retention is necessary for compliance with applicable laws.
• Implementation & Application: Customer data is maintained for active subscriptions and account management. Users can initiate account deletion through the app, subject to the retention of transaction and invoice records required by statutory commercial or fiscal regulations under Indian law.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
10. CHILDREN'S PERSONAL DATA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Before processing personal data of a child (an individual under 18 years of age), a Data Fiduciary must obtain verifiable consent of the parent or lawful guardian. The Act prohibits tracking, behavioral monitoring, targeted advertising directed at children, and any processing that causes a detrimental effect on the well-being of a child.
• Implementation & Application: Sawariya Dairy's services are intended for household milk purchasing and adult consumers. The application does not intentionally target, profile, or market services to children under 18 years of age.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
11. RIGHT TO ACCESS INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Data Principals have the right to obtain confirmation on whether their data is being processed, a summary of personal data and processing activities, the identities of all other Data Fiduciaries and Processors with whom data has been shared, and any other prescribed information.
• Implementation & Application: Customers can view their account profile, saved addresses, and past order details directly in the application, or submit requests regarding their data by contacting support@sawariyasdairy.com.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
12. GRIEVANCE REDRESSAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Data Fiduciaries must provide a readily available grievance redressal mechanism to respond to Data Principal grievances regarding the performance of obligations under the Act or the exercise of rights.
• Implementation & Application: Data-related questions, requests, and grievances may be submitted using the contact channel:
  • Email: support@sawariyasdairy.com
  • Helpline: 9896703884

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
13. RIGHT TO NOMINATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Under the DPDP Act, a Data Principal has the right to nominate another individual who shall, in the event of death or incapacity of the Data Principal, exercise their rights under the Act in accordance with prescribed rules.
• Implementation & Application: As administrative and regulatory frameworks for nomination are established under DPDP rules scheduled for 13 May 2027, nomination requests or inquiries by authorized representatives may be directed to support@sawariyasdairy.com with appropriate legal verification.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
14. CONSENT MANAGERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: The DPDP Act provides for registered Consent Managers through whom Data Principals can give, manage, review, or withdraw consent through an accessible, transparent, and interoperable platform.
• Implementation & Application: Technical integration with registered Consent Managers will be implemented as interoperability standards and registration processes are formalized by the regulatory authorities. Currently, users manage their account details and consent directly in the application.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
15. PROCESSING OUTSIDE INDIA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Under the DPDP Act, a Data Fiduciary may transfer personal data outside India for processing, except to countries or territories restricted by notifications issued by the Central Government.
• Implementation & Application: Data processing for application hosting and database operations follows applicable general transfer rules and statutory restrictions issued under the Act.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
16. SIGNIFICANT DATA FIDUCIARY (SDF) STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: The Central Government may notify any Data Fiduciary or class of Data Fiduciaries as a Significant Data Fiduciary (SDF) based on factors such as the volume and sensitivity of personal data processed, risk of harm to Data Principals, potential impact on national sovereignty, or public order.
• Implementation & Application: Entities notified or designated as Significant Data Fiduciaries are subject to additional statutory obligations under Section 10 of the Act, including appointing a Data Protection Officer, conducting Data Protection Impact Assessments, and undergoing periodic independent audits. Where an entity is not notified as an SDF, these additional requirements do not apply unless formally designated.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
17. DATA PROTECTION OFFICER (DPO)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: A Significant Data Fiduciary is required to appoint a Data Protection Officer based in India who reports to the governing board and represents the fiduciary in communications with the Data Protection Board of India.
• Implementation & Application: The requirement to appoint a statutory Data Protection Officer applies where an entity is designated as a Significant Data Fiduciary. For data-related communications, inquiries, and grievances, customers can contact the business directly at support@sawariyasdairy.com.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
18. DATA PROTECTION IMPACT ASSESSMENT (DPIA)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Significant Data Fiduciaries must periodically conduct Data Protection Impact Assessments (DPIAs) to assess and mitigate risks of harm before undertaking certain data processing activities.
• Implementation & Application: Formal Data Protection Impact Assessments are required where an entity is classified as a Significant Data Fiduciary. Operational and security reviews of system access and database protections are conducted as part of general technical maintenance.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
19. INDEPENDENT DATA AUDIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: Significant Data Fiduciaries are required to undertake periodic independent data audits conducted by an independent data auditor to evaluate compliance with the Act.
• Implementation & Application: Mandatory independent data audits apply where an entity is designated as a Significant Data Fiduciary. General technical and dependency updates are conducted by development personnel to support application security.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
20. DATA PROTECTION BOARD OF INDIA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Statutory Framework: The Data Protection Board of India is established under the DPDP Act as an independent digital body to inquire into personal data breaches, investigate complaints, issue remedial directions, and impose statutory penalties for non-compliance.
• Implementation & Application: If a Data Principal is not satisfied with the response received through the primary contact channel after exhausting the grievance process, they may approach the Data Protection Board of India in the manner prescribed under the Act and its procedural rules.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DATA PROTECTION CONTACT & GRIEVANCE INQUIRIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
For data protection questions, requests, or grievances, please use the following contact channel:

• Entity: SAWARIYA SARKAR DAIRY LLP
• Email: support@sawariyasdairy.com
• Helpline: 9896703884
• Registered Address:
  Ground Floor, Khewat No. 253/260,
  Farukh Nagar Road, Tajnagar,
  Gurugram, Haryana
''';

/// Standalone Public Web & In-App DPDP & Data Protection Screen
class DpdpDataProtectionScreen extends StatelessWidget {
  const DpdpDataProtectionScreen({super.key});

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
      title: 'DPDP & Data Protection | Sawariya Dairy',
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
                  Icons.security_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'DPDP & Data Protection',
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
                  buildDpdpHeaderCard(),
                  const SizedBox(height: AppSizes.p16),
                  buildDpdpStagingNoticeCard(),
                  const SizedBox(height: AppSizes.p16),
                  buildDpdpContentCard(dpdpDataProtectionContent),
                  const SizedBox(height: AppSizes.p16),
                  buildDpdpContactCard(),
                  const SizedBox(height: AppSizes.p24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header card for the DPDP section
Widget buildDpdpHeaderCard() {
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          'DPDP & Data Protection',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entity: SAWARIYA SARKAR DAIRY LLP • Digital Personal Data Protection Act, 2023',
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

/// Regulatory Staging & Roadmap notice card highlighting the 13 May 2027 milestone
Widget buildDpdpStagingNoticeCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSizes.p16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB45309),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staged Regulatory Implementation Notice',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The DPDP Act, 2023 provides a phased implementation schedule with full enforcement of day-to-day duties scheduled for 13 May 2027. This page outlines the statutory standards and applicable requirements under the source guide alongside our operational procedures.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.5,
                  color: const Color(0xFF78350F),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Content card rendering the 20 DPDP areas with selectable text
Widget buildDpdpContentCard(String content) {
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

/// Contact details card displaying verified company address and contact details
Widget buildDpdpContactCard() {
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Protection Contact & Inquiries',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'For data-related requests, questions, or grievances, please use the following contact channel:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _buildContactRow(
          icon: Icons.business_outlined,
          label: 'Entity',
          value: AppStrings.companyName,
        ),
        const SizedBox(height: 10),
        _buildContactRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: AppStrings.supportEmail,
        ),
        const SizedBox(height: 10),
        _buildContactRow(
          icon: Icons.phone_outlined,
          label: 'Helpline',
          value: AppStrings.supportPhone,
        ),
        const SizedBox(height: 10),
        _buildContactRow(
          icon: Icons.location_on_outlined,
          label: 'Address',
          value: AppStrings.businessAddress,
        ),
      ],
    ),
  );
}

Widget _buildContactRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    ],
  );
}
