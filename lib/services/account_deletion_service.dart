import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

/// Result status of an account deletion operation.
enum AccountDeletionResultStatus {
  success,
  requiresRecentLogin,
  unauthenticated,
  failure,
}

/// Structured response from [AccountDeletionService.deleteAccount].
class AccountDeletionResult {
  final AccountDeletionResultStatus status;
  final String? errorMessage;

  const AccountDeletionResult({
    required this.status,
    this.errorMessage,
  });

  bool get isSuccess => status == AccountDeletionResultStatus.success;
}

/// Service dedicated to handling user account deletion and data anonymization.
///
/// Implements store-compliant erasure of customer personal data while
/// safely preserving statutory financial order and payment records.
class AccountDeletionService {
  final FirebaseFirestore? _firestoreOverride;
  final fb.FirebaseAuth? _authOverride;

  AccountDeletionService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  FirebaseFirestore get _firestore {
    if (_firestoreOverride != null) return _firestoreOverride;
    return FirebaseFirestore.instance;
  }

  fb.FirebaseAuth? get _auth {
    if (_authOverride != null) return _authOverride;
    try {
      return fb.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Executes the complete account deletion and de-identification workflow:
  ///
  /// 1. Verifies the authenticated user.
  /// 2. Cancels active recurring subscriptions in `/subscriptions`.
  /// 3. Deletes saved delivery addresses in `/users/{uid}/addresses`.
  /// 4. Deletes active cart items in `/users/{uid}/cart`.
  /// 5. Deletes in-app notification records in `/users/{uid}/notifications`.
  /// 6. Deletes skipped dates and delivery records subcollections.
  /// 7. Clears FCM tokens and anonymizes `/users/{uid}` personal data.
  /// 8. Permanently deletes the user from Firebase Authentication (`user.delete()`).
  ///
  /// Note: Historical `/orders` and `/payments` are retained in accordance with
  /// legal accounting, tax, and audit requirements.
  Future<AccountDeletionResult> deleteAccount() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (user == null) {
      return const AccountDeletionResult(
        status: AccountDeletionResultStatus.unauthenticated,
        errorMessage: 'No authenticated user session found.',
      );
    }

    final uid = user.uid;

    try {
      // 1. Cancel active subscriptions so scheduled Cloud Functions cease order generation
      try {
        final subsSnap = await _firestore
            .collection('subscriptions')
            .where('userId', isEqualTo: uid)
            .get();

        for (final doc in subsSnap.docs) {
          final status = doc.data()['status']?.toString().toLowerCase();
          if (status == 'active' || status == 'paused') {
            await doc.reference.update({
              'status': 'Cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancellationReason': 'Account deleted by customer',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Subscription cancellation notice: $e');
      }

      // 2. Delete saved delivery addresses subcollection
      try {
        final addressesSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('addresses')
            .get();
        for (final doc in addressesSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Address deletion notice: $e');
      }

      // 3. Delete cart items subcollection
      try {
        final cartSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('cart')
            .get();
        for (final doc in cartSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Cart deletion notice: $e');
      }

      // 4. Delete notifications subcollection
      try {
        final notifSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .get();
        for (final doc in notifSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Notification deletion notice: $e');
      }

      // 5. Delete skipped dates & subscription subcollections under users/{uid}
      try {
        final skippedSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('skipped_dates')
            .get();
        for (final doc in skippedSnap.docs) {
          await doc.reference.delete();
        }

        final userSubsSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('subscription')
            .get();
        for (final doc in userSubsSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Subcollection deletion notice: $e');
      }

      // 6. De-identify and anonymize the user's root profile document
      try {
        await _firestore.collection('users').doc(uid).set({
          'name': 'Deleted User',
          'phone': '',
          'email': '',
          'profileImageUrl': null,
          'accountStatus': 'deleted',
          'fcmTokens': [],
          'fcmToken': FieldValue.delete(),
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[ACCOUNT DELETION] Profile de-identification notice: $e');
      }

      // 7. Permanently delete the Firebase Authentication account
      await user.delete();

      return const AccountDeletionResult(
        status: AccountDeletionResultStatus.success,
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return const AccountDeletionResult(
          status: AccountDeletionResultStatus.requiresRecentLogin,
          errorMessage:
              'For your security, deleting your account requires recent authentication. Please log out, log back in with SMS OTP, and try again.',
        );
      }
      return AccountDeletionResult(
        status: AccountDeletionResultStatus.failure,
        errorMessage: e.message ?? 'Authentication error during account deletion.',
      );
    } catch (e) {
      return AccountDeletionResult(
        status: AccountDeletionResultStatus.failure,
        errorMessage: 'Failed to complete account deletion: $e',
      );
    }
  }
}
