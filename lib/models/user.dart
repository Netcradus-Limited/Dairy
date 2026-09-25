import '../core/auth/app_role.dart';

/// User Model for Sawariya Dairy
class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? profileImageUrl;
  final String
      role; // 'admin', 'manager', 'dispatcher', 'staff', 'delivery', 'customer'
  final String? roleTitle; // 'Super Admin', 'Route Dispatcher', etc.
  final List<String> permissions;
  final String status; // 'Active', 'Inactive'

  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.profileImageUrl,
    this.role = UserRole.customerValue,
    this.roleTitle,
    this.permissions = const [],
    this.status = 'Active',
  });

  UserRole get userRole => UserRole.fromString(role);
  bool get isDelivery => userRole.isDelivery;
  bool get isAdmin => userRole.isAdmin;
  bool get isStaff => userRole.isStaff;
  bool get canAccessAdminPortal => userRole.canAccessAdminPortal;
  bool get isCustomer => userRole.isCustomer;
  bool get isActive => status.toLowerCase() == 'active';

  /// Permission checker for RBAC enforcement
  bool hasPermission(String permissionKey) {
    if (isAdmin) return true;
    if (!isActive) return false;
    return permissions.contains(permissionKey);
  }

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? profileImageUrl,
    String? role,
    String? roleTitle,
    List<String>? permissions,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      roleTitle: roleTitle ?? this.roleTitle,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'role': UserRole.sanitize(role),
      if (roleTitle != null) 'roleTitle': roleTitle,
      'permissions': permissions,
      'status': status,
      'isAdmin': isAdmin,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final dynamic candidateImage = map['profileImageUrl'] ??
        map['photoUrl'] ??
        map['photoURL'] ??
        map['profileImage'] ??
        map['imageUrl'] ??
        map['avatar'];

    final rawPermissions = map['permissions'];
    List<String> perms = [];
    if (rawPermissions is List) {
      perms = rawPermissions
          .map((p) => p.toString().trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }

    final rawRole = map['role'] as String?;
    final cleanRole = UserRole.sanitize(rawRole);
    final rawRoleTitle = map['roleTitle'] as String?;

    return User(
      id: map['id'] ?? map['uid'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      profileImageUrl:
          (candidateImage is String && candidateImage.trim().isNotEmpty)
              ? candidateImage.trim()
              : null,
      role: cleanRole,
      roleTitle: (rawRoleTitle != null && rawRoleTitle.trim().isNotEmpty)
          ? rawRoleTitle.trim()
          : null,
      permissions: perms,
      status: (map['status'] as String? ?? 'Active').trim(),
    );
  }
}
