import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/responsive/responsive.dart';
import '../../core/widgets/app_network_image.dart';
import '../../providers/cart_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_storage_service.dart';
import 'edit_profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../subscription/subscriptions_screen.dart';
import 'about_screen.dart';
import '../../core/localization/app_language.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = context.isDesktop;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 700 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── 1. Header Card (Splash/Gradient Green with User Profile Info) ───
                  _buildProfileHeaderCard(context, ref),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── 4. Account Settings Menu ───
                        Text(
                          tr('Account Settings'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFF1F5F9), width: 1.0),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _buildMenuTile(
                                  context,
                                  Icons.person_outline_rounded,
                                  tr('My Profile'),
                                  tr('Manage your personal details'),
                                  () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const EditProfileScreen()));
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.location_on_outlined,
                                  tr('Delivery Addresses'),
                                  tr('Add or edit delivery addresses'),
                                  () {
                                    context.push('/address');
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.payment_outlined,
                                  'Payment Methods',
                                  'Manage your payment options',
                                  () {},
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.autorenew_rounded,
                                  'My Subscriptions',
                                  'Manage milk & product subscriptions',
                                  () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SubscriptionsScreen()));
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.notifications_none_rounded,
                                  'Notifications',
                                  'Manage your notification preferences',
                                  () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const NotificationsScreen()));
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.support_agent_rounded,
                                  'Support / Complaints',
                                  'Raise queries & view ticket status',
                                  () {
                                    context.push('/support');
                                  },
                                ),
                                const Divider(
                                    height: 1, color: Color(0xFFF1F5F9)),
                                _buildMenuTile(
                                  context,
                                  Icons.info_outline_rounded,
                                  'About Sawariya Dairy',
                                  'Know more about us',
                                  () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AboutScreen()));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Logout Button
                        _buildLogoutTile(context, ref),
                        const SizedBox(height: 70),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDesktop = context.isDesktop;
    debugPrint(
        '[PROFILE DEBUG T5] ProfileScreen: profileImageUrl received: ${user.profileImageUrl}');
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF5EF), Color(0xFFF1F9F5), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDesktop ? 24 : 20,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User Avatar with Camera edit button
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF005F38).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: const Color(0xFFE2EFE7),
                        child: (user.profileImageUrl != null &&
                                user.profileImageUrl!.trim().isNotEmpty &&
                                user.profileImageUrl!.trim().startsWith('http'))
                            ? Builder(
                                builder: (context) {
                                  debugPrint(
                                      '[PROFILE DEBUG] 10. Rendering avatar widget: AppNetworkImage');
                                  return AppNetworkImage(
                                    imageUrl: user.profileImageUrl!.trim(),
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        debugPrint(
                                            '[PROFILE DEBUG] 11. Image loading state: LOADED');
                                        return child;
                                      }
                                      debugPrint(
                                          '[PROFILE DEBUG] 11. Image loading state: IN PROGRESS');
                                      return const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF005F38),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                          '[PROFILE DEBUG] 12. Image error: $error');
                                      return const Center(
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 52,
                                          color: Color(0xFF005F38),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )
                            : Builder(
                                builder: (context) {
                                  debugPrint(
                                      '[PROFILE DEBUG] 10. Rendering avatar widget: Fallback Person Icon (profileImageUrl is null/empty)');
                                  return const Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: Color(0xFF005F38),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _uploadProfilePhoto(context, ref, user.id),
                        customBorder: const CircleBorder(),
                        mouseCursor: SystemMouseCursors.click,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE2EFE7), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Color(0xFF005F38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Name
            Text(
              user.name.isEmpty ? 'Sawariya Customer' : user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Phone Number
            Text(
              user.phone.isEmpty ? '+91 98765 43210' : user.phone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 10),

            // Membership Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF005F38), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF005F38).withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'Fresh Member',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF005F38),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFFEAF5EF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF005F38), size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172033),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF98A2B3),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFCBD5E1),
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutTile(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 18),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
          subtitle: const Text(
            'Log out of your account',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF98A2B3),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 18,
          ),
          onTap: () => showLogoutDialog(context, ref),
        ),
      ),
    );
  }

  void showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content:
            const Text('Are you sure you want to log out of Sawariya Dairy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clearLocalCart();
              ref.read(userProvider.notifier).clearSession();
            },
            child: const Text('Log Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadProfilePhoto(
      BuildContext context, WidgetRef ref, String uid) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUid = (uid.trim().isNotEmpty) ? uid.trim() : (authUid ?? '');

    debugPrint(
        '[PROFILE DEBUG T0] 1. Firebase Auth UID: $authUid (effective: $effectiveUid)');
    debugPrint(
        '[PROFILE DEBUG T0] profileImageUrl before upload: ${ref.read(userProvider).profileImageUrl}');

    if (effectiveUid.isEmpty) {
      debugPrint('[PROFILE DEBUG] Upload aborted: no authenticated user found');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to update your profile photo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) {
        debugPrint('[PROFILE DEBUG] Image picker cancelled by user');
        return;
      }

      // 1. Validate file extension (case-insensitive: .jpg, .jpeg, .png)
      final fileName = picked.name.isNotEmpty ? picked.name : picked.path;
      final dotIndex = fileName.lastIndexOf('.');
      final ext =
          dotIndex != -1 ? fileName.substring(dotIndex).toLowerCase() : '';
      final hasValidExt = ext == '.jpg' || ext == '.jpeg' || ext == '.png';

      if (!hasValidExt) {
        debugPrint('[PROFILE DEBUG] Upload rejected: invalid extension "$ext"');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid file type. Please upload only JPG, JPEG, or PNG images.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bytes = await picked.readAsBytes();

      // 2. Validate file size limit (Maximum 5 MB = 5 * 1024 * 1024 bytes)
      const maxSizeBytes = 5 * 1024 * 1024;
      if (bytes.length > maxSizeBytes) {
        debugPrint(
            '[PROFILE DEBUG] Upload rejected: file size ${bytes.length} exceeds 5 MB');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Image is too large. Please select an image smaller than 5 MB.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 3. Validate MIME / Magic Bytes signature
      // JPEG SOI marker: FF D8 FF
      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
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

      if (!isJpeg && !isPng) {
        debugPrint(
            '[PROFILE DEBUG] Upload rejected: magic bytes do not match JPEG or PNG');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid file type. Please upload only JPG, JPEG, or PNG images.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final detectedContentType = isPng ? 'image/png' : 'image/jpeg';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading profile photo...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final storagePath = 'profiles/$effectiveUid/image';
      debugPrint('[PROFILE DEBUG] 2. Storage upload path: $storagePath');

      final downloadUrl =
          await FirebaseStorageService.instance.uploadProfileImage(
        uid: effectiveUid,
        bytes: bytes,
        contentType: detectedContentType,
      );

      final uri = Uri.tryParse(downloadUrl);
      final safeUrlSummary = uri != null
          ? '${uri.scheme}://${uri.host}${uri.path}'
          : '[unparseable]';
      debugPrint('[PROFILE DEBUG T1] 3. Storage upload succeeded: true');
      debugPrint(
          '[PROFILE DEBUG T1] 4. downloadUrl exists: ${downloadUrl.isNotEmpty}');
      debugPrint(
          '[PROFILE DEBUG T1] 5. Download URL host/path: $safeUrlSummary');

      debugPrint(
          '[PROFILE DEBUG T2] 6. Firestore document path: users/$effectiveUid');
      await ref
          .read(userProvider.notifier)
          .updateProfile(profileImageUrl: downloadUrl);

      final userAfter = ref.read(userProvider);
      debugPrint(
          '[PROFILE DEBUG T3] 7. Firestore profileImageUrl after write: $safeUrlSummary');
      debugPrint(
          '[PROFILE DEBUG T3] 8. userProvider.profileImageUrl immediately after updateProfile(): ${userAfter.profileImageUrl}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFF005F38),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PROFILE DEBUG] Failed to upload photo error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile photo: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
