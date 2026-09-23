import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_live_location_provider.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/localization/app_language.dart';

/// Profile Tab - Delivery agent info, photo upload, online/offline toggle
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final agent = ref.read(deliveryAgentProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (agent.id.isEmpty || authUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to upload your profile photo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cardBgOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.plusJakartaSans()),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: Text('Take a Photo',
                    style: GoogleFonts.plusJakartaSans()),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked == null) {
        // User cancelled image picking
        return;
      }

      // 1. Validate file extension
      final fileName = picked.name.isNotEmpty ? picked.name : picked.path;
      final dotIndex = fileName.lastIndexOf('.');
      final ext =
          dotIndex != -1 ? fileName.substring(dotIndex).toLowerCase() : '';
      final hasValidExt = ext == '.jpg' ||
          ext == '.jpeg' ||
          ext == '.png' ||
          ext == '.webp';

      if (!hasValidExt) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid file type. Please upload only JPG, JPEG, PNG, or WEBP images.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final bytes = await picked.readAsBytes();

      // 2. Validate file size (Maximum 5 MB = 5 * 1024 * 1024 bytes)
      const maxSizeBytes = 5 * 1024 * 1024;
      if (bytes.length > maxSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Image is too large. Please select an image smaller than 5 MB.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // 3. Validate MIME / Magic Bytes signature
      // JPEG SOI: FF D8 FF
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      // WEBP: 52 49 46 46
      final isJpeg = bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF;
      final isPng = bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A;
      final isWebp = bytes.length >= 4 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46;

      if (!isJpeg && !isPng && !isWebp) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid image format. Please select a valid photo file.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final detectedContentType = isPng
          ? 'image/png'
          : (isWebp ? 'image/webp' : 'image/jpeg');

      setState(() {
        _isUploadingPhoto = true;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading profile photo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await ref.read(deliveryAgentProvider.notifier).uploadProfilePhoto(
            bytes: bytes,
            contentType: detectedContentType,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Profile photo upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final errorStr = e.toString();
        final displayMsg = errorStr.contains('Storage permission denied')
            ? 'Failed to upload profile photo: Storage permission denied. Please deploy storage.rules to Firebase.'
            : 'Failed to upload profile photo: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showEditProfileDialog(BuildContext context, DeliveryAgent agent) {
    final authPhone = () {
      try {
        if (Firebase.apps.isNotEmpty) {
          return FirebaseAuth.instance.currentUser?.phoneNumber?.trim();
        }
      } catch (_) {}
      return null;
    }();

    final effectivePhone = (authPhone != null && authPhone.isNotEmpty)
        ? authPhone
        : (agent.phone.trim().isNotEmpty
            ? agent.phone.trim()
            : ref.read(userProvider).phone.trim());

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: agent.name);
    final phoneCtrl = TextEditingController(text: effectivePhone);
    final vehicleCtrl = TextEditingController(text: agent.vehicle);
    final vehicleNumCtrl = TextEditingController(text: agent.vehicleNumber);
    final zoneCtrl = TextEditingController(text: agent.assignedZone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBgOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Profile Details',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    validator: AppValidators.validateFullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Devendra Singh',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Read-Only)',
                      hintText: effectivePhone.isNotEmpty
                          ? effectivePhone
                          : 'No phone linked',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      suffixIcon: const Tooltip(
                        message:
                            'Phone number is linked to your authenticated account and cannot be modified.',
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.12),
                      helperText: 'Linked to authenticated account',
                      helperStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: vehicleCtrl,
                    validator: AppValidators.validateVehicleModel,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Model / Type *',
                      hintText: 'e.g. Honda Activa, Pulsar, Splendor',
                      prefixIcon: Icon(Icons.electric_rickshaw_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: vehicleNumCtrl,
                    validator: AppValidators.validateVehicleNumber,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Plate Number *',
                      hintText: 'e.g. MP 09 AB 1234',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: zoneCtrl,
                    validator: AppValidators.validateDeliveryZone,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Zone *',
                      hintText: 'e.g. Vijay Nagar, Palasia',
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              final normalizedPlate =
                  AppValidators.normalizeVehicleNumber(vehicleNumCtrl.text);
              final normalizedName =
                  AppValidators.normalizeName(nameCtrl.text);

              Navigator.pop(ctx);
              try {
                await ref.read(deliveryAgentProvider.notifier).updateProfile(
                      name: normalizedName,
                      phone: effectivePhone,
                      vehicle: vehicleCtrl.text.trim(),
                      vehicleNumber: normalizedPlate,
                      assignedZone: zoneCtrl.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // 1. Loading State: show proper loading state while profile is streaming
    if (!agent.isLoaded) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading profile details...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      children: [
        // Profile Header
        Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar with camera change button
              Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: _isUploadingPhoto
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : (agent.profileImageUrl != null &&
                                agent.profileImageUrl!.isNotEmpty
                            ? ClipOval(
                                child: AppNetworkImage(
                                  imageUrl: agent.profileImageUrl!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_rounded,
                                size: 48, color: Colors.white)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isUploadingPhoto
                            ? null
                            : () => _pickAndUploadPhoto(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                agent.name.isNotEmpty ? agent.name : tr('Delivery Partner'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (agent.email != null && agent.email!.isNotEmpty)
                    ? agent.email!
                    : (agent.phone.isNotEmpty
                        ? agent.phone
                        : (agent.name.isNotEmpty ? '' : tr('Delivery Partner'))),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? tr('Online') : tr('Offline'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Empty / Setup State Banner: if profile is incomplete
        if (!agent.isProfileComplete) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Please provide your full name, phone number, and vehicle details to get verified.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _showEditProfileDialog(context, agent),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Setup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Quick Stats
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    context,
                    tr('Rating'),
                    agent.rating != null
                        ? agent.rating!.toStringAsFixed(1)
                        : '—',
                    Icons.star_rounded,
                    Colors.amber,
                    isDesktop)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    context,
                    tr("Today's Deliveries"),
                    '${agent.completedDeliveriesToday}/${agent.totalDeliveriesToday}',
                    Icons.local_shipping_rounded,
                    AppColors.success,
                    isDesktop)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    context,
                    tr("Today's Earnings"),
                    '₹${agent.earningsToday.toStringAsFixed(0)}',
                    Icons.account_balance_wallet,
                    AppColors.primary,
                    isDesktop)),
          ],
        ),
        const SizedBox(height: 24),

        // Duty Toggle
        _buildDutyToggleCard(context, agent, isDesktop),
        const SizedBox(height: 24),

        // Details Section (Real Firestore Profile Data)
        _buildSectionCard(
          context,
          'Details',
          [
            _buildDetailRow(
              context,
              'Phone',
              agent.phone.isNotEmpty ? agent.phone : tr('Not set'),
              Icons.phone_rounded,
            ),
            _buildDetailRow(
              context,
              'Vehicle',
              agent.vehicle.isNotEmpty
                  ? '${agent.vehicle}${agent.vehicleNumber.isNotEmpty ? ' (${agent.vehicleNumber})' : ''}'
                  : tr('Not set'),
              Icons.electric_rickshaw_rounded,
            ),
            _buildDetailRow(
              context,
              'Assigned Zone',
              agent.assignedZone.isNotEmpty
                  ? agent.assignedZone
                  : tr('Unassigned'),
              Icons.location_on_rounded,
            ),
            _buildDetailRow(
              context,
              'Partner ID',
              agent.id.isNotEmpty ? agent.id : tr('Unregistered'),
              Icons.badge_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showEditProfileDialog(context, agent),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
          isDesktop,
        ),
        const SizedBox(height: 16),

        // App Settings
        _buildSectionCard(
          context,
          'App Settings',
          [
            _buildSettingsRow(
              context,
              'Notifications',
              'Manage notification preferences',
              Icons.notifications_outlined,
              null,
              trailing: Switch(
                value: settings.notificationsEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: settingsNotifier.updateNotifications,
              ),
            ),
            _buildSettingsRow(
              context,
              'Navigation',
              _navLabel(settings.navigationApp),
              Icons.navigation_outlined,
              () => _showNavigationDialog(context, ref),
            ),
          ],
          isDesktop,
        ),
        const SizedBox(height: 16),

        // Logout Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDesktop,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDutyToggleCard(
      BuildContext context, DeliveryAgent agent, bool isDesktop) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final isOnline = agent.status == DeliveryStatus.onDuty;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duty Status',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'Currently Online' : 'Currently Offline',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline
                          ? 'You\'re receiving delivery requests'
                          : 'Go online to start receiving requests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: isDesktop ? 1.0 : 0.9,
                child: Switch(
                  value: isOnline,
                  onChanged: (_) =>
                      ref.read(deliveryAgentProvider.notifier).toggleDuty(),
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                  inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          if (isOnline) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'ll receive delivery requests for your assigned zone. Tap "Accept" to start a delivery.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.info,
                      ),
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

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
    bool isDesktop,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final cardBorder = AppColors.cardBorderOf(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final textPrimary = AppColors.textPrimaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedOf(context),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    Widget? trailing,
    bool enabled = true,
  }) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final cardBorder = AppColors.cardBorderOf(context);
    final muted = AppColors.textMutedOf(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cardBorder)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled ? muted : muted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled ? textPrimary : muted,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? muted : muted.withValues(alpha: 0.5),
                ),
          ],
        ),
      ),
    );
  }

  String _navLabel(NavigationApp app) {
    switch (app) {
      case NavigationApp.googleMaps:
        return 'Google Maps';
      case NavigationApp.appleMaps:
        return 'Apple Maps';
      case NavigationApp.waze:
        return 'Waze';
    }
  }

  void _showNavigationDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).navigationApp;
    showDialog<NavigationApp>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Default Navigation App',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NavigationApp.values.map((app) {
            return RadioListTile<NavigationApp>(
              title: Text(_navLabel(app), style: GoogleFonts.plusJakartaSans()),
              value: app,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateNavigationApp(value);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondaryOf(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ref.read(agentLiveLocationProvider.notifier).stopTracking();
              ref.read(cartProvider.notifier).clearLocalCart();
              await ref.read(userProvider.notifier).clearSession();
              // Navigation will be handled by router redirect
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Logout', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }
}
