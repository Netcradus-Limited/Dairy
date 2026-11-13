import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

enum PinCodeValidationStatus {
  valid,
  invalidFormat,
  mismatch,
  networkError,
}

class PinCodeValidationResult {
  final PinCodeValidationStatus status;
  final String? errorMessage;
  final List<String> matchedCities;
  final List<String> matchedDistricts;
  final String? state;

  const PinCodeValidationResult({
    required this.status,
    this.errorMessage,
    this.matchedCities = const [],
    this.matchedDistricts = const [],
    this.state,
  });

  bool get isValid => status == PinCodeValidationStatus.valid;
}

/// Service dedicated to validating Indian Postal PIN Codes against City, District, and State.
/// Uses the authoritative India Post postal database via api.postalpincode.in with
/// Photon geocoding fallback for maximum reliability across Web, Mobile, and Desktop.
class PinCodeService {
  final http.Client _client;

  PinCodeService({http.Client? client}) : _client = client ?? http.Client();

  static final PinCodeService _instance = PinCodeService();
  static PinCodeService get instance => _instance;

  static const Map<String, List<String>> _cityAliases = {
    'gurgaon': ['gurgaon', 'gurugram'],
    'gurugram': ['gurgaon', 'gurugram'],
    'bangalore': ['bangalore', 'bengaluru'],
    'bengaluru': ['bangalore', 'bengaluru'],
    'mumbai': ['mumbai', 'bombay'],
    'bombay': ['mumbai', 'bombay'],
    'kolkata': ['kolkata', 'calcutta'],
    'calcutta': ['kolkata', 'calcutta'],
    'chennai': ['chennai', 'madras'],
    'madras': ['chennai', 'madras'],
    'prayagraj': ['prayagraj', 'allahabad'],
    'allahabad': ['prayagraj', 'allahabad'],
    'varanasi': ['varanasi', 'banaras', 'benares', 'kashi'],
    'banaras': ['varanasi', 'banaras', 'benares', 'kashi'],
    'benares': ['varanasi', 'banaras', 'benares', 'kashi'],
    'puducherry': ['puducherry', 'pondicherry'],
    'pondicherry': ['puducherry', 'pondicherry'],
    'vadodara': ['vadodara', 'baroda'],
    'baroda': ['vadodara', 'baroda'],
    'kochi': ['kochi', 'cochin'],
    'cochin': ['kochi', 'cochin'],
    'thiruvananthapuram': ['thiruvananthapuram', 'trivandrum'],
    'trivandrum': ['thiruvananthapuram', 'trivandrum'],
    'kozhikode': ['kozhikode', 'calicut'],
    'calicut': ['kozhikode', 'calicut'],
    'mysuru': ['mysuru', 'mysore'],
    'mysore': ['mysuru', 'mysore'],
    'pune': ['pune', 'poona'],
    'poona': ['pune', 'poona'],
    'belagavi': ['belagavi', 'belgaum'],
    'belgaum': ['belgaum', 'belagavi'],
    'delhi': ['delhi', 'newdelhi', 'nctofdelhi'],
    'newdelhi': ['delhi', 'newdelhi', 'nctofdelhi'],
    'gautambuddhanagar': ['gautambuddhanagar', 'noida', 'greaternoida'],
    'noida': ['gautambuddhanagar', 'noida', 'greaternoida'],
    'greaternoida': ['gautambuddhanagar', 'noida', 'greaternoida'],
  };

  /// Normalizes a place name for flexible comparison
  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll('district', '')
        .replaceAll('city', '')
        .replaceAll('nagar', '')
        .replaceAll('zone', '')
        .replaceAll('rural', '')
        .replaceAll('urban', '')
        .replaceAll('east', '')
        .replaceAll('west', '')
        .replaceAll('north', '')
        .replaceAll('south', '')
        .replaceAll('central', '')
        .trim();
  }

  /// Validates an Indian PIN code against entered city, district, and state.
  Future<PinCodeValidationResult> validatePinCode({
    required String pinCode,
    required String city,
    String? state,
  }) async {
    final cleanPin = pinCode.trim();
    final cleanCity = city.trim();
    final cleanState = state?.trim() ?? '';

    // 1. Format check: Exactly 6 digits, numeric only
    if (!RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      return const PinCodeValidationResult(
        status: PinCodeValidationStatus.invalidFormat,
        errorMessage: 'Please enter a valid 6-digit PIN code.',
      );
    }

    if (cleanCity.isEmpty) {
      return const PinCodeValidationResult(
        status: PinCodeValidationStatus.mismatch,
        errorMessage: 'Please enter a valid city name.',
      );
    }

    // 2. Query India Post Database
    try {
      final uri = Uri.parse('https://api.postalpincode.in/pincode/$cleanPin');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List &&
            decoded.isNotEmpty &&
            decoded.first is Map<String, dynamic>) {
          final entry = decoded.first as Map<String, dynamic>;
          final status = entry['Status']?.toString();

          if (status == 'Success') {
            final postOffices = entry['PostOffice'];
            if (postOffices is List && postOffices.isNotEmpty) {
              final returnedDistricts = <String>{};
              final returnedNames = <String>{};
              final returnedBlocks = <String>{};
              final returnedDivisions = <String>{};
              final returnedStates = <String>{};

              for (final po in postOffices) {
                if (po is Map<String, dynamic>) {
                  if (po['District'] != null) {
                    returnedDistricts.add(po['District'].toString());
                  }
                  if (po['Name'] != null) {
                    returnedNames.add(po['Name'].toString());
                  }
                  if (po['Block'] != null) {
                    returnedBlocks.add(po['Block'].toString());
                  }
                  if (po['Division'] != null) {
                    returnedDivisions.add(po['Division'].toString());
                  }
                  if (po['State'] != null) {
                    returnedStates.add(po['State'].toString());
                  }
                }
              }

              // Check if city matches any district, post office, block, or division
              final isCityMatch = _matchesLocation(
                cleanCity,
                districts: returnedDistricts,
                names: returnedNames,
                blocks: returnedBlocks,
                divisions: returnedDivisions,
              );

              // Check state if provided
              final isStateMatch = cleanState.isEmpty ||
                  _matchesState(cleanState, returnedStates);

              if (isCityMatch && isStateMatch) {
                return PinCodeValidationResult(
                  status: PinCodeValidationStatus.valid,
                  matchedCities: returnedNames.toList(),
                  matchedDistricts: returnedDistricts.toList(),
                  state:
                      returnedStates.isNotEmpty ? returnedStates.first : null,
                );
              } else {
                return const PinCodeValidationResult(
                  status: PinCodeValidationStatus.mismatch,
                  errorMessage:
                      'This PIN code does not match the selected city.',
                );
              }
            }
          } else {
            // e.g. "Status": "Error" -> No records found
            return const PinCodeValidationResult(
              status: PinCodeValidationStatus.mismatch,
              errorMessage: 'This PIN code does not match the selected city.',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('api.postalpincode.in query failed or timed out: $e');
    }

    // 3. Fallback: Query Photon Geocoder
    try {
      final photonResult =
          await _verifyWithPhoton(cleanPin, cleanCity, cleanState);
      if (photonResult != null) {
        return photonResult;
      }
    } catch (e) {
      debugPrint('Photon PIN validation fallback failed: $e');
    }

    // If verification could not be completed because of network/API error:
    return const PinCodeValidationResult(
      status: PinCodeValidationStatus.networkError,
      errorMessage: 'Unable to verify PIN code. Please try again.',
    );
  }

  bool _matchesLocation(
    String city, {
    required Set<String> districts,
    required Set<String> names,
    required Set<String> blocks,
    required Set<String> divisions,
  }) {
    final normCity = _normalize(city);
    if (normCity.isEmpty) return false;

    // Collect all candidate strings from API response
    final allTokens = <String>{
      ...districts,
      ...names,
      ...blocks,
      ...divisions,
    };

    final allNormTokens =
        allTokens.map(_normalize).where((s) => s.isNotEmpty).toSet();

    // Check direct equality or substring inclusion
    for (final token in allNormTokens) {
      if (token == normCity ||
          token.contains(normCity) ||
          normCity.contains(token)) {
        return true;
      }
    }

    // Check alias list for city
    final aliases = _cityAliases[normCity] ?? [normCity];
    for (final alias in aliases) {
      final normAlias = _normalize(alias);
      for (final token in allNormTokens) {
        if (token == normAlias ||
            token.contains(normAlias) ||
            normAlias.contains(token)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _matchesState(String enteredState, Set<String> returnedStates) {
    final normEntered = _normalize(enteredState);
    if (normEntered.isEmpty) return true;

    for (final st in returnedStates) {
      final normSt = _normalize(st);
      if (normSt == normEntered ||
          normSt.contains(normEntered) ||
          normEntered.contains(normSt)) {
        return true;
      }
      // Alias check for states e.g. NCT of Delhi
      final aliases = _cityAliases[normEntered] ?? [normEntered];
      for (final a in aliases) {
        if (normSt.contains(_normalize(a)) || _normalize(a).contains(normSt)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<PinCodeValidationResult?> _verifyWithPhoton(
    String pinCode,
    String city,
    String state,
  ) async {
    final uri = Uri.https('photon.komoot.io', '/api', {
      'q': '$pinCode, India',
      'limit': '5',
    });

    final response = await _client.get(uri, headers: {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final features = decoded['features'];
        if (features is List && features.isNotEmpty) {
          final returnedCities = <String>{};
          final returnedStates = <String>{};

          for (final f in features) {
            if (f is Map<String, dynamic>) {
              final props = f['properties'];
              if (props is Map<String, dynamic>) {
                if (props['city'] != null) {
                  returnedCities.add(props['city'].toString());
                }
                if (props['name'] != null) {
                  returnedCities.add(props['name'].toString());
                }
                if (props['county'] != null) {
                  returnedCities.add(props['county'].toString());
                }
                if (props['district'] != null) {
                  returnedCities.add(props['district'].toString());
                }
                if (props['state'] != null) {
                  returnedStates.add(props['state'].toString());
                }
              }
            }
          }

          final normCity = _normalize(city);
          final matchesCity = returnedCities.any((c) {
            final nc = _normalize(c);
            return nc == normCity ||
                nc.contains(normCity) ||
                normCity.contains(nc);
          });

          final normState = _normalize(state);
          final matchesState = normState.isEmpty ||
              returnedStates.any((s) {
                final ns = _normalize(s);
                return ns == normState ||
                    ns.contains(normState) ||
                    normState.contains(ns);
              });

          if (matchesCity && matchesState) {
            return PinCodeValidationResult(
              status: PinCodeValidationStatus.valid,
              matchedCities: returnedCities.toList(),
              state: returnedStates.isNotEmpty ? returnedStates.first : null,
            );
          } else {
            return const PinCodeValidationResult(
              status: PinCodeValidationStatus.mismatch,
              errorMessage: 'This PIN code does not match the selected city.',
            );
          }
        }
      }
    }
    return null;
  }
}

final pinCodeServiceProvider = Provider<PinCodeService>((ref) {
  return PinCodeService.instance;
});
