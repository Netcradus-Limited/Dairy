/// Centralized Role-Based Access Control (RBAC) definition for Sawariya Dairy
enum UserRole {
  admin,
  staff,
  delivery,
  customer;

  static const String adminValue = 'admin';
  static const String staffValue = 'staff';
  static const String managerValue = 'manager';
  static const String dispatcherValue = 'dispatcher';
  static const String deliveryValue = 'delivery';
  static const String customerValue = 'customer';

  /// Securely parses a role string.
  /// Maps 'admin', 'owner', 'superadmin' to [UserRole.admin].
  /// Maps 'manager', 'dispatcher', 'route_dispatcher', 'staff' to [UserRole.staff].
  /// Maps 'delivery', 'delivery_agent', 'driver' to [UserRole.delivery].
  /// Any unknown, null, empty, or invalid role fails securely to [UserRole.customer].
  static UserRole fromString(String? role) {
    if (role == null) return UserRole.customer;
    switch (role.trim().toLowerCase()) {
      case adminValue:
      case 'owner':
      case 'superadmin':
        return UserRole.admin;
      case staffValue:
      case managerValue:
      case dispatcherValue:
      case 'route_dispatcher':
        return UserRole.staff;
      case deliveryValue:
      case 'delivery_agent':
      case 'driver':
        return UserRole.delivery;
      case customerValue:
      case 'user':
        return UserRole.customer;
      default:
        // Fail securely: unknown/invalid roles are never granted privileged access
        return UserRole.customer;
    }
  }

  /// Resolves role from phone number.
  /// Privileged roles (admin, staff, delivery) are strictly managed via authoritative
  /// backend Firestore collections (`/admins` and `/delivery_agents`).
  /// All unauthenticated or unverified phone lookups fail securely to [UserRole.customer].
  static UserRole fromPhone(String? phone) {
    return UserRole.customer;
  }

  /// Resolves role by prioritizing explicit privileged role strings
  /// verified from authoritative backend collections, failing securely to [UserRole.customer].
  static UserRole fromPhoneAndRole({String? phone, String? role}) {
    if (role != null && role.trim().isNotEmpty) {
      final parsed = fromString(role);
      if (parsed != UserRole.customer) {
        return parsed;
      }
    }
    return UserRole.customer;
  }

  /// Returns the canonical sanitized role string for storage or state.
  static String sanitize(String? role) {
    if (role == null) return customerValue;
    final clean = role.trim().toLowerCase();
    switch (clean) {
      case adminValue:
      case 'owner':
      case 'superadmin':
        return clean;
      case staffValue:
      case managerValue:
      case dispatcherValue:
      case 'route_dispatcher':
        return clean;
      case deliveryValue:
      case 'delivery_agent':
      case 'driver':
        return deliveryValue;
      case customerValue:
      case 'user':
        return customerValue;
      default:
        return customerValue;
    }
  }

  /// Canonical string representation matching existing Firestore schema.
  String get value {
    switch (this) {
      case UserRole.admin:
        return adminValue;
      case UserRole.staff:
        return staffValue;
      case UserRole.delivery:
        return deliveryValue;
      case UserRole.customer:
        return customerValue;
    }
  }

  bool get isSuperAdmin => this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;
  bool get isStaff => this == UserRole.staff;
  bool get canAccessAdminPortal =>
      this == UserRole.admin || this == UserRole.staff;
  bool get isDelivery => this == UserRole.delivery;
  bool get isCustomer => this == UserRole.customer;

  /// Returns the default landing/home route for this role.
  String get homeRoute {
    switch (this) {
      case UserRole.admin:
      case UserRole.staff:
        return '/admin';
      case UserRole.delivery:
        return '/delivery';
      case UserRole.customer:
        return '/home';
    }
  }
}
