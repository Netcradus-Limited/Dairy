/// Input Validation Utility
abstract class AppValidators {
  static String? validateRequired(String? value,
      [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can contain letters and spaces only.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return 'Name cannot exceed 50 characters.';
    }
    return null;
  }

  static String normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleanPhone = value.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePinCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pincode is required';
    }
    if (value.trim().length != 6 || int.tryParse(value.trim()) == null) {
      return 'Enter a valid 6-digit Pincode';
    }
    return null;
  }

  /// Validates Indian phone number strictly (10 digits starting with 6-9,
  /// rejects letters and arbitrary symbols).
  static String? validateIndianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final trimmed = value.trim();
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed) ||
        RegExp(r'[^\d\+\-\s]').hasMatch(trimmed)) {
      return 'Enter a valid 10-digit mobile number';
    }
    var cleanPhone = trimmed.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }
    if (cleanPhone.length != 10 || !RegExp(r'^[6-9]').hasMatch(cleanPhone)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  /// Validates vehicle model / type (alphabetic characters and spaces only).
  static String? validateVehicleModel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vehicle model is required';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      return 'Vehicle model can contain letters and spaces only';
    }
    if (trimmed.length < 2) {
      return 'Vehicle model must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Vehicle model cannot exceed 50 characters';
    }
    return null;
  }

  /// Validates Indian vehicle registration plate (e.g. MP 09 AB 1234, DL 01 AB 1234).
  /// Allows alphanumeric and spaces/dashes; rejects special-characters-only, numbers-only or letters-only.
  static String? validateVehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vehicle plate number is required';
    }
    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9\s\-]+$').hasMatch(trimmed)) {
      return 'Invalid characters in registration plate';
    }
    final clean = trimmed.replaceAll(RegExp(r'[\s\-]'), '');
    final hasLetters = RegExp(r'[A-Z]').hasMatch(clean);
    final hasDigits = RegExp(r'[0-9]').hasMatch(clean);
    if (!hasLetters || !hasDigits || clean.length < 6 || clean.length > 12) {
      return 'Enter a valid Indian vehicle registration (e.g. MP 09 AB 1234)';
    }
    return null;
  }

  /// Normalizes vehicle registration plate to standard uppercase spacing.
  static String normalizeVehicleNumber(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Validates delivery zone (letters, numbers, spaces, and hyphens allowed; no random symbols).
  static String? validateDeliveryZone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Delivery zone is required';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[a-zA-Z0-9\s\-\.]+$').hasMatch(trimmed)) {
      return 'Delivery zone cannot contain special symbols';
    }
    if (trimmed.length < 2) {
      return 'Delivery zone must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Delivery zone cannot exceed 50 characters';
    }
    return null;
  }
}
