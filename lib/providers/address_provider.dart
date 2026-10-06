import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/address.dart';
import '../services/location_service.dart';
import 'user_provider.dart';

final addressLoadingProvider = StateProvider<bool>((ref) => false);
final addressErrorProvider = StateProvider<String?>((ref) => null);

class AddressNotifier extends StateNotifier<List<Address>> {
  final String _userId;
  final Ref _ref;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  AddressNotifier(
    this._userId,
    this._ref, {
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth,
        super([]) {
    _loadAddresses();
  }

  FirebaseFirestore? get _firestore {
    try {
      return _firestoreOverride ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return _authOverride ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String get _activeUid {
    try {
      final firebaseUid = _auth?.currentUser?.uid;
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        return firebaseUid;
      }
    } catch (_) {}
    return _userId;
  }

  Future<void> _loadAddresses() async {
    final activeId = _activeUid;
    if (activeId.isEmpty) {
      state = [];
      return;
    }

    try {
      final firestore = _firestore;
      if (firestore == null) {
        state = [];
        return;
      }

      Future.microtask(() {
        _ref.read(addressLoadingProvider.notifier).state = true;
        _ref.read(addressErrorProvider.notifier).state = null;
      });

      final snapshot = await firestore
          .collection('users')
          .doc(activeId)
          .collection('addresses')
          .get();

      final list = snapshot.docs.map((doc) {
        return Address.fromMap(doc.data(), doc.id);
      }).toList();

      state = list;
    } catch (e) {
      state = [];
      Future.microtask(() {
        _ref.read(addressErrorProvider.notifier).state = e.toString();
      });
    } finally {
      Future.microtask(() {
        _ref.read(addressLoadingProvider.notifier).state = false;
      });
    }
  }

  Future<void> addAddress(Address address) async {
    final activeId = _activeUid;
    if (activeId.isEmpty) return;
    try {
      final firestore = _firestore;
      if (firestore == null) return;

      final colRef =
          firestore.collection('users').doc(activeId).collection('addresses');

      final data = {
        'label': address.label,
        'fullName': address.fullName,
        'mobileNumber': address.mobileNumber,
        'houseFlat': address.houseFlat,
        'streetArea': address.streetArea,
        'city': address.city,
        'state': address.state,
        'pinCode': address.pinCode,
        'isDefault': address.isDefault,
        if (address.latitude != null) 'latitude': address.latitude,
        if (address.longitude != null) 'longitude': address.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (address.isDefault) {
        final batch = firestore.batch();
        for (var a in state) {
          if (a.isDefault) {
            batch.update(colRef.doc(a.id), {'isDefault': false});
          }
        }
        final docRef = colRef.doc(address.id);
        batch.set(docRef, data);
        await batch.commit();
      } else {
        await colRef.doc(address.id).set(data);
      }

      await _loadAddresses();
    } catch (_) {}
  }

  Future<void> updateAddress(Address address) async {
    final activeId = _activeUid;
    if (activeId.isEmpty) return;
    try {
      final firestore = _firestore;
      if (firestore == null) return;

      final colRef =
          firestore.collection('users').doc(activeId).collection('addresses');

      final data = {
        'label': address.label,
        'fullName': address.fullName,
        'mobileNumber': address.mobileNumber,
        'houseFlat': address.houseFlat,
        'streetArea': address.streetArea,
        'city': address.city,
        'state': address.state,
        'pinCode': address.pinCode,
        'isDefault': address.isDefault,
        if (address.latitude != null) 'latitude': address.latitude,
        if (address.longitude != null) 'longitude': address.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (address.isDefault) {
        final batch = firestore.batch();
        for (var a in state) {
          if (a.isDefault && a.id != address.id) {
            batch.update(colRef.doc(a.id), {'isDefault': false});
          }
        }
        batch.update(colRef.doc(address.id), data);
        await batch.commit();
      } else {
        await colRef.doc(address.id).update(data);
      }

      await _loadAddresses();
    } catch (_) {}
  }

  Future<void> removeAddress(String id) async {
    final activeId = _activeUid;
    if (activeId.isEmpty) return;
    try {
      final firestore = _firestore;
      if (firestore == null) return;

      await firestore
          .collection('users')
          .doc(activeId)
          .collection('addresses')
          .doc(id)
          .delete();
      await _loadAddresses();
    } catch (_) {}
  }

  Future<void> setDefault(String id) async {
    final activeId = _activeUid;
    if (activeId.isEmpty) return;
    try {
      final firestore = _firestore;
      if (firestore == null) return;

      final colRef =
          firestore.collection('users').doc(activeId).collection('addresses');
      final batch = firestore.batch();
      for (var a in state) {
        batch.update(colRef.doc(a.id), {'isDefault': a.id == id});
      }
      await batch.commit();
      await _loadAddresses();
    } catch (_) {}
  }
}

final addressesProvider =
    StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
  final user = ref.watch(userProvider);
  return AddressNotifier(user.id, ref);
});

/// Currently selected address ID for checkout
final selectedAddressIdProvider = StateProvider<String>((ref) {
  final addresses = ref.watch(addressesProvider);
  if (addresses.isEmpty) return '';
  final defaultAddress = addresses.firstWhere(
    (a) => a.isDefault,
    orElse: () => addresses.first,
  );
  return defaultAddress.id;
});

/// Selected address object getter provider
final selectedAddressProvider = Provider<Address?>((ref) {
  final addresses = ref.watch(addressesProvider);
  final selectedId = ref.watch(selectedAddressIdProvider);
  if (addresses.isEmpty) return null;
  return addresses.firstWhere(
    (a) => a.id == selectedId,
    orElse: () => addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    ),
  );
});

/// Formats an [Address] model into a short, elegant header string.
/// E.g. "Sector 45, Gurugram" or "Gurugram, 122001" or "Indore, 452001".
String formatAddressForHeader(Address a) {
  final street = a.streetArea.trim();
  final city = a.city.trim();
  final pin = a.pinCode.trim();
  if (street.isNotEmpty &&
      city.isNotEmpty &&
      street.toLowerCase() != city.toLowerCase()) {
    return '$street, $city';
  } else if (city.isNotEmpty && pin.isNotEmpty) {
    return '$city, $pin';
  } else if (city.isNotEmpty) {
    return city;
  } else if (street.isNotEmpty) {
    return street;
  } else if (a.houseFlat.trim().isNotEmpty) {
    return a.houseFlat.trim();
  }
  return 'Select location';
}

/// Provider for reverse-geocoded current device GPS location string (e.g. "Noida, 201301").
final currentGpsAddressProvider = FutureProvider<String?>((ref) async {
  try {
    final locationService = ref.read(locationServiceProvider);

    // Fast path: check device's last known location first without waiting for a new GPS fix
    final lastKnown = await locationService.getLastKnownPosition();
    if (lastKnown != null &&
        (lastKnown.latitude != 0.0 || lastKnown.longitude != 0.0)) {
      final geo = await locationService.reverseGeocode(
        lastKnown.latitude,
        lastKnown.longitude,
      );
      if (geo != null) {
        final street = geo.streetOrArea?.trim() ?? '';
        final city = geo.city?.trim() ?? '';
        final pin = geo.postalCode?.trim() ?? '';
        if (street.isNotEmpty &&
            city.isNotEmpty &&
            street.toLowerCase() != city.toLowerCase()) {
          return '$street, $city';
        } else if (city.isNotEmpty && pin.isNotEmpty) {
          return '$city, $pin';
        } else if (city.isNotEmpty) {
          return city;
        } else if (street.isNotEmpty) {
          return street;
        } else if (geo.state?.trim().isNotEmpty ?? false) {
          return geo.state!.trim();
        }
      }
    }

    final result = await locationService.getCurrentPositionDetailed();
    if (result.status == LocationResultStatus.success &&
        result.position != null) {
      final geo = await locationService.reverseGeocode(
        result.position!.latitude,
        result.position!.longitude,
      );
      if (geo != null) {
        final street = geo.streetOrArea?.trim() ?? '';
        final city = geo.city?.trim() ?? '';
        final pin = geo.postalCode?.trim() ?? '';
        if (street.isNotEmpty &&
            city.isNotEmpty &&
            street.toLowerCase() != city.toLowerCase()) {
          return '$street, $city';
        } else if (city.isNotEmpty && pin.isNotEmpty) {
          return '$city, $pin';
        } else if (city.isNotEmpty) {
          return city;
        } else if (street.isNotEmpty) {
          return street;
        } else if (geo.state?.trim().isNotEmpty ?? false) {
          return geo.state!.trim();
        }
      }
    }
  } catch (_) {
    // Gracefully handle GPS/geocoding failure or denial
  }
  return null;
});

/// High-level delivery location text for the header app bar.
/// Priority:
/// 1. Selected or default saved delivery address
/// 2. Current reverse-geocoded GPS location (asynchronous)
/// 3. "Select location"
final deliveryLocationDisplayProvider = Provider<String>((ref) {
  final selectedAddress = ref.watch(selectedAddressProvider);
  if (selectedAddress != null) {
    final formatted = formatAddressForHeader(selectedAddress);
    if (formatted.isNotEmpty && formatted != 'Select location') {
      return formatted;
    }
  }

  // If user has an active session and saved addresses are currently loading from Firestore,
  // do not trigger a GPS hardware/network acquisition while saved addresses are loading.
  final isLoadingAddresses = ref.watch(addressLoadingProvider);
  final user = ref.watch(userProvider);
  if (user.id.isNotEmpty && isLoadingAddresses) {
    return 'Select location';
  }

  final gpsAsync = ref.watch(currentGpsAddressProvider);
  return gpsAsync.maybeWhen(
    data: (gpsLoc) =>
        (gpsLoc != null && gpsLoc.isNotEmpty) ? gpsLoc : 'Select location',
    orElse: () => 'Select location',
  );
});
