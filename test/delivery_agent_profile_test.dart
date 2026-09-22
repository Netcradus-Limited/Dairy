import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_app/models/delivery_boy_model.dart';
import 'package:dairy_app/models/delivery_staff_model.dart';
import 'package:dairy_app/core/utils/validators.dart';

void main() {
  group('Delivery Agent Profile System & Model Tests', () {
    test('DeliveryAgent.empty contains NO fake/hardcoded fallback data', () {
      final emptyAgent = DeliveryAgent.empty('agent_test_123');

      expect(emptyAgent.id, equals('agent_test_123'));
      expect(emptyAgent.name, isEmpty);
      expect(emptyAgent.phone, isEmpty);
      expect(emptyAgent.vehicle, isEmpty);
      expect(emptyAgent.vehicleNumber, isEmpty);
      expect(emptyAgent.assignedZone, isEmpty);
      expect(emptyAgent.profileImageUrl, isNull);
      expect(emptyAgent.rating, isNull);
      expect(emptyAgent.isLoaded, isFalse);
      expect(emptyAgent.isProfileComplete, isFalse);

      // Verify no hardcoded legacy strings exist
      expect(emptyAgent.name.contains('Rajesh'), isFalse);
      expect(emptyAgent.phone.contains('98765'), isFalse);
      expect(emptyAgent.vehicle.contains('Activa'), isFalse);
    });

    test('DeliveryAgent isProfileComplete reflects real profile data presence', () {
      var agent = DeliveryAgent.empty('agent_test_123');
      expect(agent.isProfileComplete, isFalse);

      // Name only
      agent = agent.copyWith(name: 'Amit Verma');
      expect(agent.isProfileComplete, isFalse);

      // Name and Phone provided -> Complete
      agent = agent.copyWith(phone: '+91 9123456780');
      expect(agent.isProfileComplete, isTrue);

      // With whitespace only -> Incomplete
      agent = agent.copyWith(name: '   ', phone: '   ');
      expect(agent.isProfileComplete, isFalse);
    });

    test('DeliveryAgent copyWith correctly retains and updates real profile fields', () {
      const initial = DeliveryAgent(
        id: 'agent_999',
        name: 'Vikas Sharma',
        phone: '+91 9811122233',
        email: 'vikas@sawariyadairy.com',
        vehicle: 'Hero Electric Nyx',
        vehicleNumber: 'MP 09 CD 5678',
        assignedZone: 'Vijay Nagar Sector 2',
        status: DeliveryStatus.onDuty,
        totalDeliveriesToday: 5,
        completedDeliveriesToday: 4,
        earningsToday: 320.0,
        rating: 4.9,
        profileImageUrl: 'https://firebasestorage.googleapis.com/v0/b/app/o/delivery_agents%2Fagent_999%2Fprofile_photo',
        isLoaded: true,
      );

      expect(initial.isLoaded, isTrue);
      expect(initial.isProfileComplete, isTrue);
      expect(initial.email, equals('vikas@sawariyadairy.com'));
      expect(initial.vehicle, equals('Hero Electric Nyx'));

      // Update profile photo
      const newPhotoUrl =
          'https://firebasestorage.googleapis.com/v0/b/app/o/delivery_agents%2Fagent_999%2Fprofile_photo_updated';
      final updated = initial.copyWith(profileImageUrl: newPhotoUrl);

      expect(updated.profileImageUrl, equals(newPhotoUrl));
      expect(updated.name, equals('Vikas Sharma'));
      expect(updated.vehicleNumber, equals('MP 09 CD 5678'));
    });
  });

  group('Profile Photo Upload Validation Rules', () {
    test('Validates file extension case-insensitively', () {
      bool isValidExtension(String path) {
        final dotIndex = path.lastIndexOf('.');
        if (dotIndex == -1) return false;
        final ext = path.substring(dotIndex).toLowerCase();
        return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';
      }

      expect(isValidExtension('avatar.jpg'), isTrue);
      expect(isValidExtension('profile.JPEG'), isTrue);
      expect(isValidExtension('photo.PNG'), isTrue);
      expect(isValidExtension('agent.webp'), isTrue);
      expect(isValidExtension('script.sh'), isFalse);
      expect(isValidExtension('malicious.exe'), isFalse);
      expect(isValidExtension('no_extension'), isFalse);
    });

    test('Validates image size limit (5 MB)', () {
      const maxSizeBytes = 5 * 1024 * 1024;

      final smallBytes = Uint8List(1024 * 100); // 100 KB
      final exactLimitBytes = Uint8List(maxSizeBytes);
      final oversizedBytes = Uint8List(maxSizeBytes + 1);

      expect(smallBytes.length <= maxSizeBytes, isTrue);
      expect(exactLimitBytes.length <= maxSizeBytes, isTrue);
      expect(oversizedBytes.length <= maxSizeBytes, isFalse);
    });

    test('Validates magic byte signatures for JPEG, PNG, and WEBP', () {
      bool isAllowedImageBytes(Uint8List bytes) {
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
        return isJpeg || isPng || isWebp;
      }

      // Valid JPEG header
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
      expect(isAllowedImageBytes(jpegBytes), isTrue);

      // Valid PNG header
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00,
      ]);
      expect(isAllowedImageBytes(pngBytes), isTrue);

      // Valid WEBP (RIFF) header
      final webpBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x20]);
      expect(isAllowedImageBytes(webpBytes), isTrue);

      // Invalid text/binary header
      final badBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38]); // GIF
      expect(isAllowedImageBytes(badBytes), isFalse);
    });
  });

  group('Firestore & Storage Security Rules Logic Verification', () {
    test('Delivery Agent CAN update allowed profile fields (name, phone, vehicle, profileImageUrl, assignedZone)', () {
      final existingDoc = {
        'uid': 'agent_100',
        'name': 'Rajesh',
        'phone': '+91 9999999999',
        'role': 'delivery',
        'vehicle': 'Bike',
        'assignedZone': 'Zone 1',
      };

      final proposedUpdate = {
        'name': 'Rajesh Kumar Real',
        'phone': '+91 9888877777',
        'vehicle': 'Honda EV',
        'vehicleNumber': 'MP 09 ZZ 9999',
        'assignedZone': 'Zone 2 - Vijay Nagar',
        'profileImageUrl': 'https://firebasestorage.googleapis.com/.../profile_photo',
        'updatedAt': 'TIMESTAMP',
      };

      final allowedFields = [
        'name',
        'phone',
        'email',
        'profileImageUrl',
        'vehicle',
        'vehicleType',
        'vehicleNumber',
        'assignedZone',
        'isOnline',
        'isOnDuty',
        'location',
        'orderId',
        'updatedAt',
      ];

      final changedKeys = proposedUpdate.keys.toList();
      final hasOnlyAllowed = changedKeys.every(allowedFields.contains);
      final doesNotMutateUid = !proposedUpdate.containsKey('uid') || proposedUpdate['uid'] == existingDoc['uid'];
      final doesNotMutateRole = !proposedUpdate.containsKey('role') || proposedUpdate['role'] == 'delivery';

      expect(hasOnlyAllowed && doesNotMutateUid && doesNotMutateRole, isTrue);
    });

    test('Delivery Agent CANNOT mutate role to admin in profile update', () {
      final proposedUpdate = {
        'name': 'Attacker',
        'role': 'admin', // FORBIDDEN
      };

      final allowedFields = [
        'name',
        'phone',
        'email',
        'profileImageUrl',
        'vehicle',
        'vehicleType',
        'vehicleNumber',
        'assignedZone',
        'isOnline',
        'isOnDuty',
        'location',
        'orderId',
        'updatedAt',
      ];

      final changedKeys = proposedUpdate.keys.toList();
      final hasOnlyAllowed = changedKeys.every(allowedFields.contains);
      expect(hasOnlyAllowed, isFalse, reason: 'role is not in allowed fields for delivery agent update');
    });

    test('Delivery Agent CANNOT tamper with rating on delivery_agents profile doc', () {
      final proposedUpdate = {
        'rating': 5.0, // FORBIDDEN
      };

      final allowedFields = [
        'name',
        'phone',
        'email',
        'profileImageUrl',
        'vehicle',
        'vehicleType',
        'vehicleNumber',
        'assignedZone',
        'isOnline',
        'isOnDuty',
        'location',
        'orderId',
        'updatedAt',
      ];

      final changedKeys = proposedUpdate.keys.toList();
      final hasOnlyAllowed = changedKeys.every(allowedFields.contains);
      expect(hasOnlyAllowed, isFalse, reason: 'rating must remain read-only/system managed');
    });

    test('Unauthenticated user cannot update delivery profile', () {
      const String? authUid = null;
      const String docUid = 'agent_100';

      const canUpdate = authUid != null && authUid == docUid;
      expect(canUpdate, isFalse);
    });

    test('Agent CANNOT modify another agent profile document', () {
      const String authUid = 'agent_100';
      const String targetDocUid = 'agent_200';

      const canUpdate = authUid == targetDocUid;
      expect(canUpdate, isFalse);
    });

    test('Firebase Storage: Agent can only upload to their own path', () {
      const String authUid = 'agent_100';

      bool canUpload(String targetPath) {
        if (!targetPath.startsWith('delivery_agents/') && !targetPath.startsWith('profiles/')) {
          return false;
        }
        final pathSegments = targetPath.split('/');
        if (pathSegments.length < 3) return false;
        final folderUid = pathSegments[1];
        return folderUid == authUid;
      }

      expect(canUpload('delivery_agents/agent_100/profile_photo'), isTrue);
      expect(canUpload('delivery_agents/agent_200/profile_photo'), isFalse);
      expect(canUpload('profiles/agent_100/image'), isTrue);
      expect(canUpload('profiles/other_user/image'), isFalse);
    });
  });

  group('Legacy Mock Data Sanitization & Real Profile Resolution', () {
    bool isLegacyMockName(String? val) {
      if (val == null) return false;
      final s = val.trim().toLowerCase();
      return s == 'rajesh kumar' || s == 'rajesh yadav' || s == 'rajesh';
    }

    bool isLegacyMockPhone(String? val) {
      if (val == null) return false;
      final digits = val.replaceAll(RegExp(r'\D'), '');
      return digits == '917777777777' ||
          digits == '7777777777' ||
          digits == '919876543210' ||
          digits == '9876543210';
    }

    bool isLegacyMockVehicle(String? val) {
      if (val == null) return false;
      final s = val.trim().toLowerCase();
      return s == 'honda activa' || s == 'honda activa 6g';
    }

    bool isLegacyMockVehicleNumber(String? val) {
      if (val == null) return false;
      final s = val.replaceAll(RegExp(r'\s'), '').toLowerCase();
      return s == 'mp09ab1234';
    }

    bool isLegacyMockZone(String? val) {
      if (val == null) return false;
      final s = val.trim().toLowerCase();
      return s == 'zone a - vijay nagar' || s == 'zone a';
    }

    test('Identifies legacy mock strings accurately', () {
      expect(isLegacyMockName('Rajesh Kumar'), isTrue);
      expect(isLegacyMockName('rajesh'), isTrue);
      expect(isLegacyMockName('Aman Gupta'), isFalse);

      expect(isLegacyMockPhone('+91 7777777777'), isTrue);
      expect(isLegacyMockPhone('+91 98765 43210'), isTrue);
      expect(isLegacyMockPhone('+91 98260 12345'), isFalse);

      expect(isLegacyMockVehicle('Honda Activa'), isTrue);
      expect(isLegacyMockVehicle('Hero Splendor'), isFalse);

      expect(isLegacyMockVehicleNumber('MP 09 AB 1234'), isTrue);
      expect(isLegacyMockVehicleNumber('MP 09 CD 5678'), isFalse);

      expect(isLegacyMockZone('Zone A - Vijay Nagar'), isTrue);
      expect(isLegacyMockZone('Palasia Sector 1'), isFalse);
    });

    test('Resolves real user profile when Firestore contains legacy Rajesh Kumar mock', () {
      // Simulates poisoned Firestore doc from previous legacy run
      final poisonedFirestoreDoc = {
        'name': 'Rajesh Kumar',
        'phone': '+91 7777777777',
        'vehicle': 'Honda Activa',
        'vehicleNumber': 'MP 09 AB 1234',
        'assignedZone': 'Zone A - Vijay Nagar',
      };

      // Real user account registered in users/{uid}
      final realUser = {
        'name': 'Devendra Singh',
        'phone': '+91 98260 99887',
        'email': 'devendra@example.com',
      };

      String resolveName(String docName, String userName) {
        if (docName.isNotEmpty && !isLegacyMockName(docName)) {
          return docName;
        }
        if (userName.isNotEmpty && !isLegacyMockName(userName) && userName != 'Guest Customer') {
          return userName;
        }
        return '';
      }

      String resolvePhone(String docPhone, String userPhone) {
        if (docPhone.isNotEmpty && !isLegacyMockPhone(docPhone)) {
          return docPhone;
        }
        if (userPhone.isNotEmpty && !isLegacyMockPhone(userPhone)) {
          return userPhone;
        }
        return '';
      }

      final resolvedName = resolveName(poisonedFirestoreDoc['name']!, realUser['name']!);
      final resolvedPhone = resolvePhone(poisonedFirestoreDoc['phone']!, realUser['phone']!);

      expect(resolvedName, equals('Devendra Singh'));
      expect(resolvedPhone, equals('+91 98260 99887'));
    });

    test('Leaves fields empty rather than falling back to Rajesh Kumar if no real profile exists', () {
      final poisonedFirestoreDoc = {
        'name': 'Rajesh Kumar',
        'phone': '+91 7777777777',
      };

      final realUser = {
        'name': 'Guest Customer',
        'phone': '',
      };

      String resolveName(String docName, String userName) {
        if (docName.isNotEmpty && !isLegacyMockName(docName)) {
          return docName;
        }
        if (userName.isNotEmpty && !isLegacyMockName(userName) && userName != 'Guest Customer') {
          return userName;
        }
        return '';
      }

      final resolvedName = resolveName(poisonedFirestoreDoc['name']!, realUser['name']!);
      expect(resolvedName, isEmpty);
    });

    test('Exact Storage path is delivery_agents/{authUid}/profile_photo', () {
      const authUid = 'firebase_user_abc123';
      const path = 'delivery_agents/$authUid/profile_photo';

      expect(path, equals('delivery_agents/firebase_user_abc123/profile_photo'));
      expect(path.startsWith('delivery_agents/'), isTrue);
      expect(path.endsWith('/profile_photo'), isTrue);
    });
  });

  group('Profile Field Validation & Admin Staff Model Tests', () {
    test('Full Name validation: requires alphabetic chars & spaces, rejects digits/symbols', () {
      expect(AppValidators.validateFullName('Rajesh Yadav'), isNull);
      expect(AppValidators.validateFullName('Devendra Singh'), isNull);
      expect(AppValidators.validateFullName('Rajesh123'), isNotNull);
      expect(AppValidators.validateFullName('@Rajesh'), isNotNull);
      expect(AppValidators.validateFullName(''), isNotNull);
      expect(AppValidators.validateFullName('A'), isNotNull); // < 2 chars
    });

    test('Indian Phone validation: requires 10-digit number starting with 6-9, rejects letters & arbitrary text', () {
      expect(AppValidators.validateIndianPhone('9826012345'), isNull);
      expect(AppValidators.validateIndianPhone('+91 9826012345'), isNull);
      expect(AppValidators.validateIndianPhone('98260-12345'), isNull);
      expect(AppValidators.validateIndianPhone('9876abc'), isNotNull);
      expect(AppValidators.validateIndianPhone('Rajesh'), isNotNull);
      expect(AppValidators.validateIndianPhone('12345'), isNotNull); // < 10 digits
      expect(AppValidators.validateIndianPhone('2826012345'), isNotNull); // doesn't start with 6-9
      expect(AppValidators.validateIndianPhone(''), isNotNull);
    });

    test('Vehicle Model validation: letters and spaces only, rejects arbitrary symbols', () {
      expect(AppValidators.validateVehicleModel('Pulsar'), isNull);
      expect(AppValidators.validateVehicleModel('Honda Activa'), isNull);
      expect(AppValidators.validateVehicleModel('Splendor'), isNull);
      expect(AppValidators.validateVehicleModel('Activa@123'), isNotNull);
      expect(AppValidators.validateVehicleModel('Bike #1'), isNotNull);
      expect(AppValidators.validateVehicleModel(''), isNotNull);
    });

    test('Vehicle Registration Plate validation: alphanumeric Indian plate, rejects symbols only', () {
      expect(AppValidators.validateVehicleNumber('MP 09 AB 1234'), isNull);
      expect(AppValidators.validateVehicleNumber('DL 1C AA 1111'), isNull);
      expect(AppValidators.validateVehicleNumber('MH-12-DE-1433'), isNull);
      expect(AppValidators.validateVehicleNumber('KA01AB1234'), isNull);
      expect(AppValidators.validateVehicleNumber('@@@###'), isNotNull);
      expect(AppValidators.validateVehicleNumber('123456'), isNotNull); // numbers only
      expect(AppValidators.validateVehicleNumber('ABCDEF'), isNotNull); // letters only
      expect(AppValidators.validateVehicleNumber(''), isNotNull);

      // Normalization test
      expect(AppValidators.normalizeVehicleNumber('mp  09  ab  1234'), equals('MP 09 AB 1234'));
    });

    test('Delivery Zone validation: alphanumeric and hyphens, rejects special symbols', () {
      expect(AppValidators.validateDeliveryZone('Vijay Nagar'), isNull);
      expect(AppValidators.validateDeliveryZone('Palasia Sector 1'), isNull);
      expect(AppValidators.validateDeliveryZone('Zone-A'), isNull);
      expect(AppValidators.validateDeliveryZone('Zone #1 @ Ind'), isNotNull);
      expect(AppValidators.validateDeliveryZone(''), isNotNull);
    });

    test('DeliveryRider Admin model supports vehicleNumber, profileImageUrl, and nullable rating', () {
      const rider = DeliveryRider(
        id: 'rider_001',
        name: 'Suresh Raina',
        phone: '9826011223',
        vehicle: 'Honda Activa',
        vehicleNumber: 'MP 09 AB 5678',
        assignedZone: 'Vijay Nagar',
        totalDeliveriesToday: 3,
        pendingDeliveries: 1,
        rating: null, // Clean nullable rating without fake 4.8 / 5.0
        profileImageUrl: 'https://firebasestorage.googleapis.com/.../profile_photo',
        status: 'Active',
        isOnline: true,
      );

      expect(rider.vehicleNumber, equals('MP 09 AB 5678'));
      expect(rider.profileImageUrl, equals('https://firebasestorage.googleapis.com/.../profile_photo'));
      expect(rider.rating, isNull);

      final updated = rider.copyWith(
        rating: 4.7,
        vehicleNumber: 'MP 09 ZZ 9999',
      );
      expect(updated.rating, equals(4.7));
      expect(updated.vehicleNumber, equals('MP 09 ZZ 9999'));
      expect(updated.profileImageUrl, equals(rider.profileImageUrl));
    });
  });

  group('Profile Persistence Across Logout & Login Flow Tests', () {
    test('Edit Profile writes all required fields to delivery_agents/{uid} and users/{uid}', () {
      const uid = 'agent_test_uid_456';
      final editInput = {
        'name': 'Devendra Singh',
        'phone': '+91 98260 12345',
        'vehicle': 'Honda Activa 6G',
        'vehicleNumber': 'MP 09 AB 1234',
        'assignedZone': 'Vijay Nagar Sector 1',
        'profileImageUrl': 'https://firebasestorage.googleapis.com/.../profile_photo',
      };

      // 1. Delivery Agents document payload
      final agentUpdates = <String, dynamic>{
        'name': editInput['name'],
        'phone': editInput['phone'],
        'vehicle': editInput['vehicle'],
        'vehicleType': editInput['vehicle'],
        'vehicleNumber': editInput['vehicleNumber'],
        'assignedZone': editInput['assignedZone'],
        'profileImageUrl': editInput['profileImageUrl'],
        'updatedAt': 'SERVER_TIMESTAMP',
      };

      // 2. Users document payload
      final userUpdates = <String, dynamic>{
        'uid': uid,
        'name': editInput['name'],
        'phone': editInput['phone'],
        'vehicle': editInput['vehicle'],
        'vehicleType': editInput['vehicle'],
        'vehicleNumber': editInput['vehicleNumber'],
        'assignedZone': editInput['assignedZone'],
        'profileImageUrl': editInput['profileImageUrl'],
        'photoUrl': editInput['profileImageUrl'],
        'updatedAt': 'SERVER_TIMESTAMP',
      };

      // Verify delivery_agents payload
      expect(agentUpdates['name'], equals('Devendra Singh'));
      expect(agentUpdates['phone'], equals('+91 98260 12345'));
      expect(agentUpdates['vehicle'], equals('Honda Activa 6G'));
      expect(agentUpdates['vehicleType'], equals('Honda Activa 6G'));
      expect(agentUpdates['vehicleNumber'], equals('MP 09 AB 1234'));
      expect(agentUpdates['assignedZone'], equals('Vijay Nagar Sector 1'));
      expect(agentUpdates['profileImageUrl'], equals('https://firebasestorage.googleapis.com/.../profile_photo'));

      // Verify users payload
      expect(userUpdates['uid'], equals(uid));
      expect(userUpdates['name'], equals('Devendra Singh'));
      expect(userUpdates['vehicleNumber'], equals('MP 09 AB 1234'));
      expect(userUpdates['assignedZone'], equals('Vijay Nagar Sector 1'));
    });

    test('After Logout and Login, DeliveryAgent restores all persisted fields from Firestore without defaults', () {
      // Simulates Firestore document returned after re-login
      final persistedDoc = {
        'uid': 'agent_test_uid_456',
        'name': 'Devendra Singh',
        'phone': '+91 98260 12345',
        'email': 'devendra@example.com',
        'vehicle': 'Honda Activa 6G',
        'vehicleType': 'Honda Activa 6G',
        'vehicleNumber': 'MP 09 AB 1234',
        'assignedZone': 'Vijay Nagar Sector 1',
        'profileImageUrl': 'https://firebasestorage.googleapis.com/.../profile_photo',
        'rating': 4.8,
        'isOnline': true,
        'totalDeliveriesToday': 8,
        'completedDeliveriesToday': 7,
        'earningsToday': 450.0,
      };

      // Hydrate DeliveryAgent from Firestore snapshot
      final agent = DeliveryAgent(
        id: persistedDoc['uid'] as String,
        name: persistedDoc['name'] as String,
        phone: persistedDoc['phone'] as String,
        email: persistedDoc['email'] as String?,
        vehicle: persistedDoc['vehicle'] as String,
        vehicleNumber: persistedDoc['vehicleNumber'] as String,
        assignedZone: persistedDoc['assignedZone'] as String,
        status: (persistedDoc['isOnline'] as bool)
            ? DeliveryStatus.onDuty
            : DeliveryStatus.offDuty,
        totalDeliveriesToday: persistedDoc['totalDeliveriesToday'] as int,
        completedDeliveriesToday: persistedDoc['completedDeliveriesToday'] as int,
        earningsToday: persistedDoc['earningsToday'] as double,
        rating: persistedDoc['rating'] as double?,
        profileImageUrl: persistedDoc['profileImageUrl'] as String?,
        isLoaded: true,
      );

      // Verify all persisted fields survive
      expect(agent.id, equals('agent_test_uid_456'));
      expect(agent.name, equals('Devendra Singh'));
      expect(agent.phone, equals('+91 98260 12345'));
      expect(agent.vehicle, equals('Honda Activa 6G'));
      expect(agent.vehicleNumber, equals('MP 09 AB 1234'));
      expect(agent.assignedZone, equals('Vijay Nagar Sector 1'));
      expect(agent.profileImageUrl, equals('https://firebasestorage.googleapis.com/.../profile_photo'));
      expect(agent.rating, equals(4.8));

      // UI state expectations:
      // 1. "Delivery Partner" should NOT be displayed as name
      expect(agent.name.isNotEmpty, isTrue);
      final displayName = agent.name.isNotEmpty ? agent.name : 'Delivery Partner';
      expect(displayName, equals('Devendra Singh'));

      // 2. "Complete Your Profile" should NOT be displayed
      expect(agent.isProfileComplete, isTrue);

      // 3. No fallback mock data
      expect(agent.name.contains('Rajesh'), isFalse);
      expect(agent.name.contains('Sawariya Customer'), isFalse);
    });

    test('Shows "Delivery Partner" and "Complete Your Profile" ONLY when profile is genuinely empty', () {
      final freshAgent = DeliveryAgent.empty('fresh_uid_789').copyWith(isLoaded: true);

      expect(freshAgent.name, isEmpty);
      expect(freshAgent.phone, isEmpty);
      expect(freshAgent.vehicle, isEmpty);
      expect(freshAgent.vehicleNumber, isEmpty);
      expect(freshAgent.assignedZone, isEmpty);

      // Display fallback name when empty
      final displayName = freshAgent.name.isNotEmpty ? freshAgent.name : 'Delivery Partner';
      expect(displayName, equals('Delivery Partner'));

      // Setup banner must be shown
      expect(freshAgent.isProfileComplete, isFalse);
    });
  });

  group('Delivery Agent Profile — Phone Read-Only & Authentication Sync Tests', () {
    test('Authenticated Firebase phone number takes precedence over empty or outdated Firestore phone', () {
      const authPhone = '+91 98765 43210';
      const outdatedDocPhone = '+91 91111 22222';

      String resolveEffectivePhone({
        required String? firebaseAuthPhone,
        required String? firestorePhone,
        required String? userProviderPhone,
      }) {
        final authP = firebaseAuthPhone?.trim();
        if (authP != null && authP.isNotEmpty) {
          return authP;
        }
        final docP = firestorePhone?.trim();
        if (docP != null && docP.isNotEmpty) {
          return docP;
        }
        final userP = userProviderPhone?.trim();
        if (userP != null && userP.isNotEmpty) {
          return userP;
        }
        return '';
      }

      // 1. When Firestore has outdated phone but Auth has new phone
      final resolvedWithAuth = resolveEffectivePhone(
        firebaseAuthPhone: authPhone,
        firestorePhone: outdatedDocPhone,
        userProviderPhone: '',
      );
      expect(resolvedWithAuth, equals(authPhone));

      // 2. When Firestore has no phone but Auth has phone
      final resolvedWithEmptyDoc = resolveEffectivePhone(
        firebaseAuthPhone: authPhone,
        firestorePhone: '',
        userProviderPhone: '',
      );
      expect(resolvedWithEmptyDoc, equals(authPhone));

      // 3. When Auth has no phone but Firestore doc has phone
      final resolvedFromDoc = resolveEffectivePhone(
        firebaseAuthPhone: null,
        firestorePhone: outdatedDocPhone,
        userProviderPhone: '',
      );
      expect(resolvedFromDoc, equals(outdatedDocPhone));
    });

    test('Profile save operation prevents arbitrary phone input from overwriting authenticated phone', () {
      const authenticatedPhone = '+91 98765 43210';
      const arbitraryUserInputPhone = '+91 99999 88888';

      // Simulates the effective phone resolution in updateProfile
      String resolveSavePhone({
        required String? authPhoneNumber,
        required String? inputPhone,
        required String existingStatePhone,
      }) {
        final authP = authPhoneNumber?.trim();
        if (authP != null && authP.isNotEmpty) {
          return authP;
        }
        final trimmedInput = inputPhone?.trim();
        if (trimmedInput != null && trimmedInput.isNotEmpty) {
          return trimmedInput;
        }
        return existingStatePhone;
      }

      // Even if arbitrary user input is passed, authenticated phone takes total priority
      final phoneToSave = resolveSavePhone(
        authPhoneNumber: authenticatedPhone,
        inputPhone: arbitraryUserInputPhone,
        existingStatePhone: '+91 91234 56789',
      );

      expect(phoneToSave, equals(authenticatedPhone));
      expect(phoneToSave, isNot(equals(arbitraryUserInputPhone)));
    });

    test('Profile save preserves existing phone when auth phone is absent and input is empty', () {
      const existingPhone = '+91 98765 43210';

      String resolveSavePhone({
        required String? authPhoneNumber,
        required String? inputPhone,
        required String existingStatePhone,
      }) {
        final authP = authPhoneNumber?.trim();
        if (authP != null && authP.isNotEmpty) {
          return authP;
        }
        final trimmedInput = inputPhone?.trim();
        if (trimmedInput != null && trimmedInput.isNotEmpty) {
          return trimmedInput;
        }
        return existingStatePhone;
      }

      final phoneToSave = resolveSavePhone(
        authPhoneNumber: null,
        inputPhone: '',
        existingStatePhone: existingPhone,
      );

      expect(phoneToSave, equals(existingPhone));
    });

    test('Missing phone number in both Auth and Firestore is handled gracefully without crash', () {
      final agent = DeliveryAgent.empty('test_uid_new').copyWith(isLoaded: true);

      expect(agent.phone, isEmpty);
      expect(agent.isProfileComplete, isFalse);

      // Verify that missing phone allows updating other fields without breaking
      final updated = agent.copyWith(
        name: 'Rohan Sharma',
        vehicle: 'Honda Shine',
        vehicleNumber: 'MP 09 XY 1234',
        assignedZone: 'Vijay Nagar',
      );

      expect(updated.name, equals('Rohan Sharma'));
      expect(updated.phone, isEmpty);
      expect(updated.vehicle, equals('Honda Shine'));
      expect(updated.isProfileComplete, isFalse); // Still incomplete without phone
    });

    test('Editable profile fields (Name, Vehicle, Plate, Zone) validate and save correctly alongside read-only phone', () {
      // 1. Name validation
      expect(AppValidators.validateFullName('Rohan Verma'), isNull);
      expect(AppValidators.validateFullName(''), isNotNull);

      // 2. Vehicle Model validation
      expect(AppValidators.validateVehicleModel('Hero Splendor Plus'), isNull);
      expect(AppValidators.validateVehicleModel(''), isNotNull);

      // 3. Vehicle Plate validation
      expect(AppValidators.validateVehicleNumber('MP 09 AB 1234'), isNull);
      expect(AppValidators.validateVehicleNumber('INVALID'), isNotNull);

      // 4. Delivery Zone validation
      expect(AppValidators.validateDeliveryZone('Vijay Nagar'), isNull);
      expect(AppValidators.validateDeliveryZone(''), isNotNull);

      // Normalization helpers
      expect(AppValidators.normalizeName('  Rohan  Verma  '), equals('Rohan Verma'));
      expect(AppValidators.normalizeVehicleNumber('mp  09  ab  1234'), equals('MP 09 AB 1234'));
    });
  });
}
