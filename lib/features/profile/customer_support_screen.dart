import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/responsive/responsive.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/status_badge.dart';

// ── Support Contact Configuration ─────────────────────────────────────────────
// Replace these with official contact values when available:
// e.g. const String SUPPORT_PHONE = '+91XXXXXXXXXX';
//      const String SUPPORT_EMAIL = 'support@yourdomain.com';
//      const String SUPPORT_WHATSAPP = '+91XXXXXXXXXX';
// ignore: constant_identifier_names
const String SUPPORT_PHONE = '';
// ignore: constant_identifier_names
const String SUPPORT_EMAIL = '';
// ignore: constant_identifier_names
const String SUPPORT_WHATSAPP = '';

const List<String> _complaintCategories = [
  'Late Delivery',
  'Damaged Pouch / Seal',
  'Wrong Quantity / Item',
  'Quality Concern',
  'Billing / Payment Issue',
  'Subscription Issue',
  'Other',
];

class CustomerSupportScreen extends ConsumerStatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  ConsumerState<CustomerSupportScreen> createState() =>
      _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends ConsumerState<CustomerSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _orderIdController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedCategory = _complaintCategories.first;
  final String _selectedPriority = 'Medium';
  bool _submitting = false;
  bool _initializedUser = false;

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I modify or pause my milk subscription?',
      'a': 'Open Profile → Daily Milk Subscriptions to pause, resume or change '
          'your delivery frequency at any time.',
    },
    {
      'q': 'What are your delivery timings?',
      'a':
          'Fresh dairy is delivered every morning between 6:00 AM and 9:00 AM, '
              'and evening slots between 5:00 PM and 8:00 PM.',
    },
    {
      'q': 'What if I receive a damaged or spoiled product?',
      'a': 'Raise a query using the form below or call us directly. We offer '
          'instant replacement or refund for genuine quality issues.',
    },
    {
      'q': 'Can I change my delivery address?',
      'a': 'Yes. Go to Profile → Saved Delivery Addresses to add or update '
          'addresses for your orders.',
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedUser) {
      final user = ref.read(userProvider);
      if (user.name.isNotEmpty && user.name != 'Guest Customer') {
        _nameController.text = user.name;
      }
      if (user.phone.isNotEmpty) {
        _phoneController.text = user.phone;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
      }
      _initializedUser = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _orderIdController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    if (SUPPORT_PHONE.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support phone number is not configured yet.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
      return;
    }

    try {
      await Clipboard.setData(const ClipboardData(text: SUPPORT_PHONE));
    } catch (_) {}

    final telUri =
        Uri.parse('tel:${SUPPORT_PHONE.replaceAll(RegExp(r'[^\d+]'), '')}');
    try {
      if (await canLaunchUrl(telUri)) {
        final launched =
            await launchUrl(telUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number copied to clipboard: $SUPPORT_PHONE'),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number copied to clipboard: $SUPPORT_PHONE'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number copied to clipboard: $SUPPORT_PHONE'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
    }
  }

  Future<void> _email() async {
    if (SUPPORT_EMAIL.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support email is not configured yet.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
      return;
    }

    // 1. Always copy the support email to clipboard as immediate guarantee
    try {
      await Clipboard.setData(const ClipboardData(text: SUPPORT_EMAIL));
    } catch (_) {}

    final mailtoUri = Uri(
      scheme: 'mailto',
      path: SUPPORT_EMAIL,
      queryParameters: {
        'subject': 'Sawariya Dairy Support Request',
      },
    );

    // 2. Try launching standard system mail handler
    try {
      if (await canLaunchUrl(mailtoUri)) {
        final launched = await launchUrl(
          mailtoUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Opening email app... ($SUPPORT_EMAIL copied to clipboard)'),
                backgroundColor: AppColors.primaryBlue,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    // 3. Fallback on Web: Open Gmail Web Composer in new tab
    if (kIsWeb) {
      final gmailWebUri = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&to=$SUPPORT_EMAIL&su=${Uri.encodeComponent('Sawariya Dairy Support Request')}',
      );
      try {
        if (await canLaunchUrl(gmailWebUri)) {
          final launched = await launchUrl(
            gmailWebUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Opening Gmail in new tab... ($SUPPORT_EMAIL copied to clipboard)'),
                backgroundColor: AppColors.primaryBlue,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        }
      } catch (_) {}
    }

    // 4. Final Fallback: Inform user that address is copied
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address copied to clipboard: $SUPPORT_EMAIL'),
          backgroundColor: AppColors.primaryBlue,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _whatsapp() async {
    final whatsappTarget =
        SUPPORT_WHATSAPP.isNotEmpty ? SUPPORT_WHATSAPP : SUPPORT_PHONE;

    if (whatsappTarget.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp support is not configured yet.'),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
      }
      return;
    }

    final cleanPhone = whatsappTarget.replaceAll(RegExp(r'[^\d]'), '');
    final waUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent('Hi Sawariya Dairy, I need help with my order.')}',
    );
    try {
      if (await canLaunchUrl(waUri)) {
        final launched =
            await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open WhatsApp for $whatsappTarget'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp for $whatsappTarget'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitQuery() async {
    if (_submitting) return; // Prevent duplicate submission
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final user = ref.read(userProvider);
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final customerId =
          (authUid != null && authUid.isNotEmpty) ? authUid : user.id;

      if (customerId.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please log in to submit a complaint or support ticket.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final customerName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (user.name.isNotEmpty ? user.name : 'Customer');
      final phone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : user.phone;
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : (user.email ?? '');

      final complaintService = ref.read(complaintServiceProvider);

      final newTicket = await complaintService.createComplaint(
        customerId: customerId,
        customerName: customerName,
        phone: phone,
        email: email,
        subject: _subjectController.text.trim(),
        description: _messageController.text.trim(),
        category: _selectedCategory,
        orderId: _orderIdController.text.trim().isNotEmpty
            ? _orderIdController.text.trim()
            : null,
        priority: _selectedPriority,
      );

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _subjectController.clear();
        _orderIdController.clear();
        _messageController.clear();
        _selectedCategory = _complaintCategories.first;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complaint ${newTicket.displayTicketId} submitted! Our team is reviewing it.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit complaint: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: AppSizes.borderMedium,
        child: InkWell(
          borderRadius: AppSizes.borderMedium,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.p14),
            decoration: BoxDecoration(
              borderRadius: AppSizes.borderMedium,
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primaryBlue, size: 26),
                const SizedBox(height: AppSizes.p8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final maxWidth = isDesktop ? 760.0 : double.infinity;
    final complaintsAsync = ref.watch(customerComplaintsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Support & Complaints'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHorizontalPadding,
              vertical: AppSizes.p24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Contact banner
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: AppSizes.borderXLarge,
                    gradient: AppColors.brandGradient,
                    boxShadow: AppColors.primaryShadow,
                  ),
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'We are here to help',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reach the Sawariya Dairy team anytime for orders, '
                        'deliveries and product support.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      Row(
                        children: [
                          _actionButton(
                            icon: Icons.call_rounded,
                            label: 'Call',
                            onTap: _call,
                          ),
                          const SizedBox(width: AppSizes.p12),
                          _actionButton(
                            icon: Icons.mail_rounded,
                            label: 'Email',
                            onTap: _email,
                          ),
                          const SizedBox(width: AppSizes.p12),
                          _actionButton(
                            icon: Icons.chat_rounded,
                            label: 'WhatsApp',
                            onTap: _whatsapp,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.p14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: AppSizes.borderMedium,
                        ),
                        child: Column(
                          children: [
                            _contactRow(
                              Icons.phone_rounded,
                              SUPPORT_PHONE.isNotEmpty
                                  ? SUPPORT_PHONE
                                  : 'Phone: Not configured yet',
                              onTap: _call,
                            ),
                            const SizedBox(height: 6),
                            _contactRow(
                              Icons.email_rounded,
                              SUPPORT_EMAIL.isNotEmpty
                                  ? SUPPORT_EMAIL
                                  : 'Email: Not configured yet',
                              onTap: _email,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p32),

                // 2. Raise a complaint / query form
                const Text(
                  'Raise a Complaint / Query',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fill in the details below. Our support team will resolve it promptly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.p12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSizes.borderLarge,
                    border: Border.all(color: AppColors.border, width: 1.0),
                    boxShadow: AppColors.cardShadowSm,
                  ),
                  padding: const EdgeInsets.all(AppSizes.p20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Phone row
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration('Your Name *'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: AppSizes.p14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Phone Number *'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (v.trim().length < 10) {
                              return 'Enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p14),

                        // Email Address (Optional)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(
                              'Email Address (Optional, e.g. name@example.com)'),
                        ),
                        const SizedBox(height: AppSizes.p14),

                        // Issue Category Dropdown
                        const Text(
                          'Issue Category *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius: AppSizes.borderMedium,
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppColors.textPrimary),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              items: _complaintCategories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p14),

                        // Subject / Title
                        TextFormField(
                          controller: _subjectController,
                          decoration: _inputDecoration(
                              'Subject / Brief Title * (e.g. Pouch damaged)'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please provide a subject'
                              : null,
                        ),
                        const SizedBox(height: AppSizes.p14),

                        // Related Order ID (Optional)
                        TextFormField(
                          controller: _orderIdController,
                          decoration: _inputDecoration(
                              'Related Order ID (Optional, e.g. KRT482)'),
                        ),
                        const SizedBox(height: AppSizes.p14),

                        // Description
                        TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          decoration: _inputDecoration(
                              'Detailed Description * (How can we help?)'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please describe your issue'
                              : null,
                        ),
                        const SizedBox(height: AppSizes.p20),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submitQuery,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppSizes.borderMedium,
                              ),
                              elevation: 0,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Submit Complaint',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p32),

                // 3. My Support Tickets Section (Real-time Firestore)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'My Support Tickets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    complaintsAsync.maybeWhen(
                      data: (list) => list.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${list.length} Tickets',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.p12),

                complaintsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: AppSizes.borderLarge,
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Failed to load tickets: $err',
                      style:
                          TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                  data: (tickets) {
                    if (tickets.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppSizes.borderLarge,
                          border:
                              Border.all(color: AppColors.border, width: 1.0),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.mark_email_read_outlined,
                                size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'No tickets raised yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Any query or complaint you submit will appear here with live status updates.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickets.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSizes.p12),
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return _buildTicketCard(ticket);
                      },
                    );
                  },
                ),

                const SizedBox(height: AppSizes.p32),

                // 4. FAQ Section
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.p12),
                Material(
                  color: AppColors.surface,
                  borderRadius: AppSizes.borderLarge,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppSizes.borderLarge,
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _faqs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final faq = _faqs[index];
                      return ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p16,
                        ),
                        title: Text(
                          faq['q']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.p16,
                              0,
                              AppSizes.p16,
                              AppSizes.p16,
                            ),
                            child: Text(
                              faq['a']!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(CustomerComplaint ticket) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSizes.borderLarge,
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: AppColors.cardShadowSm,
      ),
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Ticket ID, Date & Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.displayTicketId,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.formattedCreatedAt,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              StatusBadge.fromString(ticket.status),
            ],
          ),
          const SizedBox(height: 10),

          // Subject & Category
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject.isNotEmpty ? ticket.subject : ticket.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.customersOrangeBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ticket.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.customersOrange,
                  ),
                ),
              ),
            ],
          ),

          if (ticket.orderId != null && ticket.orderId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.receipt_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Order #${ticket.orderId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Message
          Text(
            ticket.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),

          // Admin Response Bubble (if replied)
          if (ticket.adminReply != null && ticket.adminReply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent_rounded,
                          size: 15, color: Color(0xFF15803D)),
                      SizedBox(width: 6),
                      Text(
                        'Sawariya Dairy Support Team',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.adminReply!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: AppSizes.p8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
            const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p14,
        vertical: AppSizes.p12,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppSizes.borderMedium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppSizes.borderMedium,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppSizes.borderMedium,
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }
}
