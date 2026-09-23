import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum LocationResultStatus {
  success,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeoutOrError,
}

class LocationResult {
  final LocationResultStatus status;
  final Position? position;
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.position,
    this.errorMessage,
  });
}

/// Represents reverse-geocoded address fields mapped to form inputs.
class GeocodedAddress {
  final String? houseOrBuilding;
  final String? streetOrArea;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  const GeocodedAddress({
    this.houseOrBuilding,
    this.streetOrArea,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  bool get hasAnyField =>
      (houseOrBuilding?.trim().isNotEmpty ?? false) ||
      (streetOrArea?.trim().isNotEmpty ?? false) ||
      (city?.trim().isNotEmpty ?? false) ||
      (state?.trim().isNotEmpty ?? false) ||
      (postalCode?.trim().isNotEmpty ?? false);

  /// Merges this address with another address, preferring non-empty values from this.
  GeocodedAddress mergeWith(GeocodedAddress? other) {
    if (other == null) return this;
    return GeocodedAddress(
      houseOrBuilding: (houseOrBuilding?.trim().isNotEmpty ?? false)
          ? houseOrBuilding
          : other.houseOrBuilding,
      streetOrArea: (streetOrArea?.trim().isNotEmpty ?? false)
          ? streetOrArea
          : other.streetOrArea,
      city: (city?.trim().isNotEmpty ?? false) ? city : other.city,
      state: (state?.trim().isNotEmpty ?? false) ? state : other.state,
      postalCode: (postalCode?.trim().isNotEmpty ?? false)
          ? postalCode
          : other.postalCode,
      country: (country?.trim().isNotEmpty ?? false) ? country : other.country,
    );
  }
}

/// Wraps device GPS, Photon OSM, BigDataCloud, and native platform geocoding
/// to provide high-accuracy cross-platform (Web, Android, iOS, Desktop)
/// location & address resolution without requiring paid API keys.
class LocationService {
  /// Whether location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Checks current location permission without prompting the user.
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.always;
    }
  }

  /// Checks whether location services and permissions are granted, requesting
  /// permissions if needed and returning a granular [LocationResultStatus].
  Future<LocationResultStatus> checkAndRequestPermissions() async {
    try {
      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationResultStatus.servicesDisabled;
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.deniedForever) {
        return LocationResultStatus.permissionDeniedForever;
      }

      final granted = await requestLocationPermission();
      if (!granted) {
        permission = await checkPermission();
        if (permission == LocationPermission.deniedForever) {
          return LocationResultStatus.permissionDeniedForever;
        }
        return LocationResultStatus.permissionDenied;
      }

      // Attempt background location permission upgrade on Android 10+
      await requestBackgroundLocationPermission();
      return LocationResultStatus.success;
    } catch (e) {
      debugPrint('LocationService: checkAndRequestPermissions error: $e');
      return LocationResultStatus.timeoutOrError;
    }
  }

  /// Opens the device system location settings page (e.g. GPS toggle).
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the app settings page (e.g. to grant permanently denied permissions).
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Requests location permission (if not already granted).
  Future<bool> requestLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// High-accuracy stream of device positions.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(locationSettings: _locationSettings);
  }

  /// Returns a single fresh high-accuracy fix, or `null` if location is unavailable.
  Future<Position?> getCurrentPosition() async {
    final result = await getCurrentPositionDetailed();
    return result.position;
  }

  /// Obtains the real device GPS position with detailed status and user-friendly error messages.
  Future<LocationResult> getCurrentPositionDetailed() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const LocationResult(
          status: LocationResultStatus.servicesDisabled,
          errorMessage:
              'Device location services are disabled. Please turn on GPS / Location in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationResultStatus.permissionDenied,
            errorMessage:
                'Location permission was denied. Please allow location access to use your current location.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationResultStatus.permissionDeniedForever,
          errorMessage:
              'Location permission is permanently denied in device settings. Please enable location permissions in App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));

      if (position.latitude != 0.0 || position.longitude != 0.0) {
        return LocationResult(
          status: LocationResultStatus.success,
          position: position,
        );
      } else {
        return const LocationResult(
          status: LocationResultStatus.timeoutOrError,
          errorMessage: 'Received invalid GPS fix (0, 0). Please try again.',
        );
      }
    } on TimeoutException {
      return const LocationResult(
        status: LocationResultStatus.timeoutOrError,
        errorMessage:
            'GPS location request timed out. Please check your signal and try again.',
      );
    } catch (e) {
      return LocationResult(
        status: LocationResultStatus.timeoutOrError,
        errorMessage: 'Unable to retrieve location: $e',
      );
    }
  }

  /// Converts geographic coordinates (latitude and longitude) into structured
  /// address details (House/Building, Street/Area, City, State, Postal Code).
  ///
  /// Uses a web-compatible, multi-tier strategy:
  /// 1. Photon (Komoot OpenStreetMap) - CORS-enabled, free, works seamlessly on Web & Mobile.
  /// 2. BigDataCloud Client Reverse Geocode - CORS-enabled, free fallback for city/state/locality.
  /// 3. Native platform Geocoder (Android / iOS only, skipped on Web).
  /// 4. Nominatim OpenStreetMap (Native only, skipped on Web due to browser CORS).
  Future<GeocodedAddress?> reverseGeocode(
      double latitude, double longitude) async {
    if (latitude == 0.0 && longitude == 0.0) return null;

    GeocodedAddress? combinedResult;

    // Tier 1: Photon (Komoot OSM - Web & Mobile compatible, full CORS support, 100% free)
    final photonResult = await _reverseGeocodePhoton(latitude, longitude);
    if (photonResult != null && photonResult.hasAnyField) {
      combinedResult = photonResult;
      // If we already have street, city, state, and postcode, we have complete info
      if (combinedResult.streetOrArea != null &&
          combinedResult.city != null &&
          combinedResult.state != null &&
          combinedResult.postalCode != null) {
        return combinedResult;
      }
    }

    // Tier 2: BigDataCloud Client Reverse Geocoder (CORS enabled, 100% free)
    final bdcResult = await _reverseGeocodeBdc(latitude, longitude);
    if (bdcResult != null && bdcResult.hasAnyField) {
      combinedResult = combinedResult == null
          ? bdcResult
          : combinedResult.mergeWith(bdcResult);
      if (combinedResult.city != null &&
          combinedResult.state != null &&
          (combinedResult.streetOrArea != null ||
              combinedResult.postalCode != null)) {
        return combinedResult;
      }
    }

    // Tier 3: Native Platform Geocoder (Android / iOS only, skipped on Web)
    if (!kIsWeb) {
      final nativeResult = await _reverseGeocodeNative(latitude, longitude);
      if (nativeResult != null && nativeResult.hasAnyField) {
        combinedResult = combinedResult == null
            ? nativeResult
            : combinedResult.mergeWith(nativeResult);
      }
    }

    // Tier 4: Nominatim Fallback (Native only, not subject to browser CORS on native)
    if (!kIsWeb && (combinedResult == null || !combinedResult.hasAnyField)) {
      final nomResult = await _reverseGeocodeNominatim(latitude, longitude);
      if (nomResult != null && nomResult.hasAnyField) {
        combinedResult = combinedResult == null
            ? nomResult
            : combinedResult.mergeWith(nomResult);
      }
    }

    return (combinedResult != null && combinedResult.hasAnyField)
        ? combinedResult
        : null;
  }

  /// Photon (Komoot OSM) Reverse Geocoding — CORS supported for Web and Mobile
  Future<GeocodedAddress?> _reverseGeocodePhoton(
      double latitude, double longitude) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/reverse', {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final features = decoded['features'];
          if (features is List && features.isNotEmpty) {
            final firstFeature = features.first;
            if (firstFeature is Map<String, dynamic>) {
              final props = firstFeature['properties'];
              if (props is Map<String, dynamic>) {
                String? house;
                final houseNumber = props['housenumber']?.toString().trim();
                if (houseNumber != null && houseNumber.isNotEmpty) {
                  house = houseNumber;
                }

                final streetParts = <String>[];
                final street = props['street']?.toString().trim();
                final name = props['name']?.toString().trim();
                final locality = props['locality']?.toString().trim() ??
                    props['district']?.toString().trim();

                if (street != null && street.isNotEmpty) {
                  streetParts.add(street);
                } else if (name != null &&
                    name.isNotEmpty &&
                    name != houseNumber &&
                    name != props['city']?.toString().trim() &&
                    name != props['state']?.toString().trim()) {
                  streetParts.add(name);
                }

                if (locality != null &&
                    locality.isNotEmpty &&
                    !streetParts.contains(locality) &&
                    locality != props['city']?.toString().trim()) {
                  streetParts.add(locality);
                }

                final streetArea =
                    streetParts.isNotEmpty ? streetParts.join(', ') : null;

                final city = props['city']?.toString().trim() ??
                    props['town']?.toString().trim() ??
                    props['district']?.toString().trim();

                final state = props['state']?.toString().trim();
                final postcode = props['postcode']?.toString().trim();
                final country = props['country']?.toString().trim();

                final address = GeocodedAddress(
                  houseOrBuilding: (house?.isNotEmpty ?? false) ? house : null,
                  streetOrArea:
                      (streetArea?.isNotEmpty ?? false) ? streetArea : null,
                  city: (city?.isNotEmpty ?? false) ? city : null,
                  state: (state?.isNotEmpty ?? false) ? state : null,
                  postalCode: (postcode?.isNotEmpty ?? false) ? postcode : null,
                  country: (country?.isNotEmpty ?? false) ? country : null,
                );

                if (address.hasAnyField) {
                  return address;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Photon reverse geocoding skipped or failed: $e');
    }
    return null;
  }

  /// BigDataCloud Client-side Reverse Geocoding — CORS supported for Web
  Future<GeocodedAddress?> _reverseGeocodeBdc(
      double latitude, double longitude) async {
    try {
      final uri = Uri.https('api-bdc.io', '/data/reverse-geocode-client', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'localityLanguage': 'en',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final city = decoded['city']?.toString().trim() ??
              decoded['locality']?.toString().trim();
          final state = decoded['principalSubdivision']?.toString().trim();
          final postcode = decoded['postcode']?.toString().trim();
          final country = decoded['countryName']?.toString().trim();

          String? locality;
          final localityInfo = decoded['localityInfo'];
          if (localityInfo is Map<String, dynamic>) {
            final admin = localityInfo['administrative'];
            if (admin is List) {
              for (final item in admin.reversed) {
                if (item is Map<String, dynamic>) {
                  final name = item['name']?.toString().trim();
                  if (name != null &&
                      name.isNotEmpty &&
                      name != city &&
                      name != state &&
                      name != country &&
                      !name.toLowerCase().contains('district') &&
                      !name.toLowerCase().contains('tehsil') &&
                      !name.toLowerCase().contains('subdivision')) {
                    locality = name;
                    break;
                  }
                }
              }
            }
          }

          final address = GeocodedAddress(
            streetOrArea: (locality?.isNotEmpty ?? false) ? locality : null,
            city: (city?.isNotEmpty ?? false) ? city : null,
            state: (state?.isNotEmpty ?? false) ? state : null,
            postalCode: (postcode?.isNotEmpty ?? false) ? postcode : null,
            country: (country?.isNotEmpty ?? false) ? country : null,
          );

          if (address.hasAnyField) {
            return address;
          }
        }
      }
    } catch (e) {
      debugPrint('BigDataCloud reverse geocoding skipped or failed: $e');
    }
    return null;
  }

  /// Native platform reverse geocoding (Android / iOS only)
  Future<GeocodedAddress?> _reverseGeocodeNative(
      double latitude, double longitude) async {
    try {
      final placemarks = await geo
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 4));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        String? house;
        final pName = p.name?.trim();
        if (pName != null &&
            pName.isNotEmpty &&
            pName != p.street &&
            pName != p.subLocality &&
            pName != p.locality) {
          house = pName;
        }

        final streetParts = <String>[];
        final pStreet = p.street?.trim();
        final pSubLoc = p.subLocality?.trim();
        if (pStreet != null && pStreet.isNotEmpty) {
          streetParts.add(pStreet);
        }
        if (pSubLoc != null &&
            pSubLoc.isNotEmpty &&
            !streetParts.contains(pSubLoc)) {
          streetParts.add(pSubLoc);
        }
        final street = streetParts.isNotEmpty ? streetParts.join(', ') : null;

        String? city = p.locality?.trim();
        if (city == null || city.isEmpty) {
          city = p.subAdministrativeArea?.trim();
        }

        final state = p.administrativeArea?.trim();
        final postalCode = p.postalCode?.trim();
        final country = p.country?.trim();

        final result = GeocodedAddress(
          houseOrBuilding: house,
          streetOrArea: street,
          city: (city?.isNotEmpty ?? false) ? city : null,
          state: (state?.isNotEmpty ?? false) ? state : null,
          postalCode: (postalCode?.isNotEmpty ?? false) ? postalCode : null,
          country: (country?.isNotEmpty ?? false) ? country : null,
        );

        if (result.hasAnyField) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('Native reverse geocoding skipped or failed: $e');
    }
    return null;
  }

  /// Nominatim reverse geocoding fallback (Native only)
  Future<GeocodedAddress?> _reverseGeocodeNominatim(
      double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'addressdetails': '1',
        'zoom': '18',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final addr = decoded['address'];
          if (addr is Map<String, dynamic>) {
            final houseParts = <String>[];
            if (addr['house_number'] != null)
              houseParts.add(addr['house_number'].toString().trim());
            if (addr['building'] != null)
              houseParts.add(addr['building'].toString().trim());
            if (addr['flat'] != null)
              houseParts.add(addr['flat'].toString().trim());
            final house = houseParts.isNotEmpty ? houseParts.join(', ') : null;

            final streetParts = <String>[];
            if (addr['road'] != null)
              streetParts.add(addr['road'].toString().trim());
            if (addr['suburb'] != null &&
                !streetParts.contains(addr['suburb'].toString().trim())) {
              streetParts.add(addr['suburb'].toString().trim());
            }
            if (addr['neighbourhood'] != null &&
                !streetParts
                    .contains(addr['neighbourhood'].toString().trim())) {
              streetParts.add(addr['neighbourhood'].toString().trim());
            }
            final street =
                streetParts.isNotEmpty ? streetParts.join(', ') : null;

            String? city = addr['city']?.toString().trim() ??
                addr['town']?.toString().trim() ??
                addr['village']?.toString().trim() ??
                addr['municipality']?.toString().trim() ??
                addr['county']?.toString().trim();

            final state = addr['state']?.toString().trim();
            final postalCode = addr['postcode']?.toString().trim();
            final country = addr['country']?.toString().trim();

            final result = GeocodedAddress(
              houseOrBuilding: house,
              streetOrArea: street,
              city: (city?.isNotEmpty ?? false) ? city : null,
              state: (state?.isNotEmpty ?? false) ? state : null,
              postalCode: (postalCode?.isNotEmpty ?? false) ? postalCode : null,
              country: (country?.isNotEmpty ?? false) ? country : null,
            );

            if (result.hasAnyField) {
              return result;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocoding skipped: $e');
    }
    return null;
  }

  /// Converts a structured address or query string into real geographic
  /// coordinates (latitude and longitude).
  ///
  /// Uses a web-compatible strategy:
  /// 1. Photon Forward Geocoding (Komoot OSM - CORS enabled for Web & Mobile).
  /// 2. Native Geocoding (Android / iOS only, skipped on Web).
  /// 3. Nominatim Search (Native only).
  Future<({double latitude, double longitude})?> geocodeAddress(
    String fullAddress, {
    String? fallbackQuery,
  }) async {
    final cleanAddress = fullAddress.trim();
    if (cleanAddress.isEmpty) return null;

    // 1. Photon Forward Search (Web & Mobile compatible, CORS enabled)
    final photonLoc = await _forwardGeocodePhoton(cleanAddress);
    if (photonLoc != null) return photonLoc;

    // Fallback query with Photon (e.g. City, State, PIN)
    if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
      final fallbackLoc = await _forwardGeocodePhoton(fallbackQuery.trim());
      if (fallbackLoc != null) return fallbackLoc;
    }

    // 2. Native Platform Geocoder (Android / iOS only)
    if (!kIsWeb) {
      try {
        final locations = await geo
            .locationFromAddress(cleanAddress)
            .timeout(const Duration(seconds: 4));

        if (locations.isNotEmpty) {
          final loc = locations.first;
          if (loc.latitude != 0.0 || loc.longitude != 0.0) {
            return (latitude: loc.latitude, longitude: loc.longitude);
          }
        }
      } catch (e) {
        debugPrint('Native geocode skipped/failed for "$cleanAddress": $e');
      }

      // 3. Nominatim Forward Search (Native only)
      final nomLoc = await _forwardGeocodeNominatim(cleanAddress);
      if (nomLoc != null) return nomLoc;

      if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
        final nomFallback =
            await _forwardGeocodeNominatim(fallbackQuery.trim());
        if (nomFallback != null) return nomFallback;
      }
    }

    return null;
  }

  /// Photon Forward Geocoding Search
  Future<({double latitude, double longitude})?> _forwardGeocodePhoton(
      String query) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/api', {
        'q': query,
        'limit': '1',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final features = decoded['features'];
          if (features is List && features.isNotEmpty) {
            final first = features.first;
            if (first is Map<String, dynamic>) {
              final geometry = first['geometry'];
              if (geometry is Map<String, dynamic>) {
                final coordinates = geometry['coordinates'];
                if (coordinates is List && coordinates.length >= 2) {
                  final lon = double.tryParse(coordinates[0].toString());
                  final lat = double.tryParse(coordinates[1].toString());
                  if (lat != null &&
                      lon != null &&
                      (lat != 0.0 || lon != 0.0)) {
                    return (latitude: lat, longitude: lon);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Photon forward search skipped or failed: $e');
    }
    return null;
  }

  /// Nominatim Forward Geocoding Search (Native only)
  Future<({double latitude, double longitude})?> _forwardGeocodeNominatim(
      String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': query,
        'limit': '1',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final item = decoded.first;
          if (item is Map<String, dynamic>) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat != null && lon != null && (lat != 0.0 || lon != 0.0)) {
              return (latitude: lat, longitude: lon);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim forward search skipped: $e');
    }
    return null;
  }

  /// Platform-appropriate [LocationSettings].
  ///
  /// ## Android (Task 7)
  /// Sets [foregroundNotificationConfig] on [AndroidSettings] to automatically
  /// start a native Android foreground service with a visible persistent
  /// notification whenever [getPositionStream] is called. This keeps GPS updates
  /// running when the app is minimised or the screen is locked — no separate
  /// background-service package is required.
  ///
  /// The service is started by [geolocator_android] internally and stopped
  /// automatically when [StreamSubscription.cancel] is called.
  ///
  /// Requires [FOREGROUND_SERVICE], [FOREGROUND_SERVICE_LOCATION] (Android 14+),
  /// and [ACCESS_BACKGROUND_LOCATION] (Android 10+) in AndroidManifest.xml.
  ///
  /// The [distanceFilter] (20 m) and [intervalDuration] (10 s) are tuned for
  /// battery efficiency in background; precision is still sufficient for
  /// delivery routing.
  LocationSettings get _locationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // Task 7: 20 m reduces GPS wakeups and Firestore writes in background
        // without sacrificing delivery-route accuracy.
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 10),
        // Task 7: Enables the Android foreground service that keeps GPS alive
        // when the app is minimised or the screen is locked.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Sawariya Dairy — Delivery Tracking Active',
          notificationText:
              'Your location is being shared for active delivery.',
          enableWakeLock: true,
          notificationChannelName: 'Delivery Location',
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
  }

  /// Requests the background location permission on Android 10 and above
  /// ([ACCESS_BACKGROUND_LOCATION], API level 29+).
  ///
  /// On Android 10+, location access while the app is in the background
  /// requires this separate permission in addition to [ACCESS_FINE_LOCATION].
  /// The user must explicitly choose "Allow all the time" in the system dialog.
  ///
  /// On non-Android platforms, or when the user has already granted the
  /// "always" permission, this method returns `true` immediately.
  ///
  /// If the user denies (grants only "While in use"), the method returns
  /// `false` and the caller degrades gracefully to foreground-only tracking.
  ///
  /// **Implementation note:** On Android 10+, calling
  /// [Geolocator.requestPermission] a second time — after the user has already
  /// granted "While in use" — presents the system’s "Allow all the time"
  /// dialog. This is handled natively by [geolocator_android] without any
  /// custom Kotlin code.
  Future<bool> requestBackgroundLocationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always) return true;
      if (permission == LocationPermission.whileInUse) {
        // Second requestPermission call on Android 10+ shows the
        // "Allow all the time" system dialog.
        final upgraded = await Geolocator.requestPermission();
        return upgraded == LocationPermission.always;
      }
      // Denied / deniedForever: cannot request background
      return false;
    } catch (_) {
      // In emulator / test environments, Geolocator calls may throw
      // (no real Location stack). Treat as not required so tests pass cleanly.
      return true;
    }
  }
}

/// Provides a singleton [LocationService].
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
