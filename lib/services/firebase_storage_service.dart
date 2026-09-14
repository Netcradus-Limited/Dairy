import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service dedicated to handling Firebase Storage uploads across Sawariya Dairy.
/// Standardizes cloud storage paths and error handling:
/// - Products: `products/{productId}/image`
/// - Categories: `categories/{categoryId}/image`
/// - Profiles: `profiles/{uid}/image`
/// - Banners: `banners/{bannerId}/image`
class FirebaseStorageService {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  static final FirebaseStorageService _instance = FirebaseStorageService();
  static FirebaseStorageService get instance => _instance;

  /// Core helper to upload raw byte data to any path in Firebase Storage.
  /// Works uniformly across Mobile, Web, and Desktop platforms.
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Cannot upload empty image data.');
    }

    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      final trimmedUrl = downloadUrl.trim();

      if (trimmedUrl.isEmpty ||
          (!trimmedUrl.startsWith('http://') &&
              !trimmedUrl.startsWith('https://'))) {
        throw StateError(
            'Firebase Storage returned an invalid download URL: $downloadUrl');
      }

      debugPrint(
          'FirebaseStorageService: Uploaded to $path successfully. Download URL: $trimmedUrl');
      return trimmedUrl;
    } on FirebaseException catch (e) {
      debugPrint(
          'FirebaseStorageService: FirebaseException at $path: ${e.code} - ${e.message}');
      throw Exception(_formatFirebaseError(e));
    } catch (e) {
      debugPrint('FirebaseStorageService: Unexpected error at $path: $e');
      throw Exception(
          'Failed to upload image. Please check your network connection and try again.');
    }
  }

  /// Uploads a product image to `products/{productId}/image`.
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final sanitizedId = productId.trim().isEmpty
        ? 'prod_${DateTime.now().millisecondsSinceEpoch}'
        : productId.trim();
    return uploadBytes(
      path: 'products/$sanitizedId/image',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Uploads a category image to `categories/{categoryId}/image`.
  Future<String> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final sanitizedId = categoryId.trim().isEmpty
        ? 'cat_${DateTime.now().millisecondsSinceEpoch}'
        : categoryId.trim();
    return uploadBytes(
      path: 'categories/$sanitizedId/image',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Uploads a profile image to `profiles/{uid}/image`.
  Future<String> uploadProfileImage({
    required String uid,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError(
          'User ID cannot be empty when uploading profile image.');
    }
    return uploadBytes(
      path: 'profiles/${uid.trim()}/image',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Uploads a delivery agent profile image to dedicated path `delivery_agents/{uid}/profile_photo`.
  Future<String> uploadDeliveryAgentProfileImage({
    required String uid,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final sanitizedUid = uid.trim();
    if (sanitizedUid.isEmpty) {
      throw ArgumentError(
          'Delivery Agent UID cannot be empty when uploading profile image.');
    }
    return uploadBytes(
      path: 'delivery_agents/$sanitizedUid/profile_photo',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Uploads a banner image to `banners/{bannerId}/image`.
  Future<String> uploadBannerImage({
    required String bannerId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final sanitizedId = bannerId.trim().isEmpty
        ? 'banner_${DateTime.now().millisecondsSinceEpoch}'
        : bannerId.trim();
    return uploadBytes(
      path: 'banners/$sanitizedId/image',
      bytes: bytes,
      contentType: contentType,
    );
  }

  String _formatFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Storage permission denied. Please check your Firebase Storage security rules.';
      case 'quota-exceeded':
        return 'Storage quota exceeded on Firebase.';
      case 'object-not-found':
        return 'The requested storage file was not found.';
      case 'retry-limit-exceeded':
        return 'Upload took too long. Please check your network connection and try again.';
      case 'canceled':
        return 'Upload was canceled.';
      default:
        return e.message ?? 'Firebase Storage error (${e.code}).';
    }
  }
}
