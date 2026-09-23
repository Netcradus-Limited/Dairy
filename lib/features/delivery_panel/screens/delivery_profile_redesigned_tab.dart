import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../../../services/firebase_storage_service.dart';
import '../theme/delivery_theme.dart';
import 'delivery_history_redesigned_screen.dart';
import 'delivery_settings_redesigned_screen.dart';

/// Screen 6 — Profile Tab matching the reference design.
class DeliveryProfileRedesignedTab extends ConsumerStatefulWidget {
  const DeliveryProfileRedesignedTab({super.key});

  @override
  ConsumerState<DeliveryProfileRedesignedTab> createState() =>
      _DeliveryProfileRedesignedTabState();
}

class _DeliveryProfileRedesignedTabState
    extends ConsumerState<DeliveryProfileRedesignedTab> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null) return;

    final agent = ref.read(deliveryAgentProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? agent.id;
    if (uid.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Cannot upload photo: user is not authenticated.'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final downloadUrl = await FirebaseStorageService.instance
          .uploadDeliveryAgentProfileImage(uid: uid, bytes: bytes);

      await ref
          .read(deliveryAgentProvider.notifier)
          .updateProfile(profileImageUrl: downloadUrl);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully.'),
            backgroundColor: DeliveryTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: DeliveryTheme.statusCancelledText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showAgentDetailsDialog(DeliveryAgent agent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Agent Profile Details',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailField('Full Name',
                agent.name.isNotEmpty ? agent.name : 'Delivery Agent'),
            _buildDetailField('Phone',
                agent.phone.isNotEmpty ? agent.phone : 'Not configured'),
            _buildDetailField(
                'Vehicle',
                agent.vehicle.isNotEmpty
                    ? '${agent.vehicle} • ${agent.vehicleNumber}'
                    : 'Not assigned'),
            _buildDetailField(
                'Active Zone',
                agent.assignedZone.isNotEmpty
                    ? agent.assignedZone
                    : 'Indore Hub'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: DeliveryTheme.textMuted,
            ),
          ),
          Text(
            value.isNotEmpty ? value : '—',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DeliveryTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded,
                color: DeliveryTheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Help & Support',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Need assistance with an active delivery or payment query?\n\nHelpline: +91 98765 43210\nHub: Vijay Nagar, Indore\nHours: 5:00 AM – 9:00 PM',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                color: DeliveryTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(deliveryAgentProvider);
    final isOnline = agent.status == DeliveryStatus.onDuty;

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Curved Green Top Banner with Leaves
            Container(
              width: double.infinity,
              height: 140,
              decoration: const BoxDecoration(
                gradient: DeliveryTheme.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    right: 0,
                    width: 140,
                    height: 100,
                    child: CustomPaint(
                      painter: BotanicalLeafPainter(
                        leafColor: Color(0x28FFFFFF),
                        isRightAligned: true,
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              Scaffold.maybeOf(context)?.openDrawer();
                            },
                            icon: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 26),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DeliverySettingsRedesignedScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings_outlined,
                                color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Overlapping Circular Avatar + Name + Online Pill
            Transform.translate(
              offset: const Offset(0, -50),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFFE8F5E9),
                          backgroundImage: agent.profileImageUrl != null &&
                                  agent.profileImageUrl!.isNotEmpty
                              ? NetworkImage(agent.profileImageUrl!)
                              : null,
                          child: agent.profileImageUrl == null ||
                                  agent.profileImageUrl!.isEmpty
                              ? const Icon(Icons.person_rounded,
                                  size: 48, color: DeliveryTheme.primary)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: InkWell(
                          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: DeliveryTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    agent.name.isNotEmpty ? agent.name : 'Delivery Partner',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DeliveryTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Delivery Partner',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: DeliveryTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Online/Offline Pill (interactive)
                  InkWell(
                    onTap: () {
                      ref.read(deliveryAgentProvider.notifier).toggleDuty();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnline
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFFFCDD2),
                          width: 1.0,
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
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isOnline
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Menu Options List matching Screen 6
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: DeliveryTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        icon: Icons.person_outline_rounded,
                        title: 'My Profile',
                        onTap: () => _showAgentDetailsDialog(agent),
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildMenuTile(
                        icon: Icons.assignment_outlined,
                        title: 'Delivery History',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DeliveryHistoryRedesignedScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildMenuTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Earnings',
                        onTap: () {
                          ref.read(deliveryPanelTabProvider.notifier).setTab(3);
                        },
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildMenuTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        onTap: _showSupportDialog,
                      ),
                      const Divider(
                          height: 1, indent: 54, color: Color(0xFFECEFF1)),
                      _buildMenuTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DeliverySettingsRedesignedScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Bottom Branding matching Screen 6
            Transform.translate(
              offset: const Offset(0, -10),
              child: Column(
                children: [
                  Image.asset(
                    AppAssets.sawariyaLogo,
                    height: 52,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.eco_rounded,
                      size: 40,
                      color: DeliveryTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SAWARIYA DAIRY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: DeliveryTheme.primaryDark,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pure Goodness Every Day',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: DeliveryTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: DeliveryTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DeliveryTheme.textDark,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFB0BEC5),
        size: 20,
      ),
    );
  }
}
