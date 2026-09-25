import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_network_image.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_storage_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    debugPrint(
        'EditProfileScreen initState: user.profileImageUrl = ${user.profileImageUrl}');
    final isDummyName = user.name == 'Sawariya Customer' ||
        user.name == 'Guest Customer' ||
        user.name.trim().toLowerCase() == 'sarkar';
    final isDummyEmail = (user.email ?? '').contains('sawariyadairy.com') ||
        (user.email ?? '').isEmpty;

    _nameController = TextEditingController(text: isDummyName ? '' : user.name);
    _emailController =
        TextEditingController(text: isDummyEmail ? '' : (user.email ?? ''));
    _phoneController = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final rawName = _nameController.text;
    final nameError = AppValidators.validateFullName(rawName);
    if (nameError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nameError),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final normalizedName = AppValidators.normalizeName(rawName);

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(userProvider.notifier).updateProfile(
            name: normalizedName,
            email: _emailController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.freshGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update profile: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadPhoto(String uid) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUid = (uid.trim().isNotEmpty) ? uid.trim() : (authUid ?? '');

    debugPrint(
        '[PROFILE DEBUG T0] 1. Firebase Auth UID: $authUid (effective: $effectiveUid)');
    debugPrint(
        '[PROFILE DEBUG T0] profileImageUrl before upload: ${ref.read(userProvider).profileImageUrl}');

    if (effectiveUid.isEmpty) {
      debugPrint('[PROFILE DEBUG] Upload aborted: no authenticated user found');
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
        debugPrint('[PROFILE DEBUG] Image picker cancelled');
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
        if (mounted) {
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
        if (mounted) {
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
        if (mounted) {
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

      setState(() => _isUploadingPhoto = true);

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

      debugPrint(
          '[PROFILE DEBUG T3] 7. Firestore profileImageUrl after write: $safeUrlSummary');
      debugPrint(
          '[PROFILE DEBUG T3] 8. userProvider.profileImageUrl immediately after updateProfile(): $safeUrlSummary');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.freshGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PROFILE DEBUG] Failed to upload photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload photo: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFFE2EFE7),
                      child: ClipOval(
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: (user.profileImageUrl != null &&
                                  user.profileImageUrl!.trim().isNotEmpty &&
                                  user.profileImageUrl!
                                      .trim()
                                      .startsWith('http'))
                              ? Builder(
                                  builder: (context) {
                                    debugPrint(
                                        '[PROFILE DEBUG] 10. EditProfileScreen rendering: AppNetworkImage');
                                    return AppNetworkImage(
                                      imageUrl: user.profileImageUrl!.trim(),
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
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
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        debugPrint(
                                            '[PROFILE DEBUG] 12. EditProfileScreen image error: $error');
                                        return const Center(
                                          child: Icon(
                                            Icons.person_rounded,
                                            size: 55,
                                            color: Color(0xFF005F38),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 55,
                                    color: Color(0xFF005F38),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploadingPhoto
                            ? null
                            : () => _uploadPhoto(user.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.freshGreen,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Name Input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: AppValidators.validateFullName,
              ),
              const SizedBox(height: 16),
              // Email Input
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'Enter your email address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Phone Input (Read-only as it is the auth identifier)
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Verified)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  filled: true,
                ),
                enabled: false,
              ),
              const SizedBox(height: 24),
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.freshGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
