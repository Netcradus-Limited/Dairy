import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Granular permission keys across all 11 functional modules of Sawariya Dairy.
class StaffPermission {
  // Dashboard
  static const String viewDashboard = 'viewDashboard';

  // Customers
  static const String viewCustomers = 'viewCustomers';
  static const String createCustomer = 'createCustomer';
  static const String editCustomer = 'editCustomer';
  static const String deleteCustomer = 'deleteCustomer';

  // Subscriptions
  static const String viewSubscriptions = 'viewSubscriptions';
  static const String createSubscription = 'createSubscription';
  static const String editSubscription = 'editSubscription';
  static const String cancelSubscription = 'cancelSubscription';

  // Products
  static const String viewProducts = 'viewProducts';
  static const String createProduct = 'createProduct';
  static const String editProduct = 'editProduct';
  static const String deleteProduct = 'deleteProduct';

  // Categories
  static const String viewCategories = 'viewCategories';
  static const String createCategory = 'createCategory';
  static const String editCategory = 'editCategory';
  static const String deleteCategory = 'deleteCategory';

  // Orders
  static const String viewOrders = 'viewOrders';
  static const String editOrders = 'editOrders';
  static const String cancelOrders = 'cancelOrders';
  static const String assignDeliveryAgent = 'assignDeliveryAgent';

  // Delivery
  static const String viewDelivery = 'viewDelivery';
  static const String manageDelivery = 'manageDelivery';

  // Payments
  static const String viewPayments = 'viewPayments';
  static const String updatePaymentStatus = 'updatePaymentStatus';

  // Notifications
  static const String viewNotifications = 'viewNotifications';
  static const String sendNotifications = 'sendNotifications';

  // Support / Complaints
  static const String viewComplaints = 'viewComplaints';
  static const String replyComplaints = 'replyComplaints';
  static const String updateComplaintStatus = 'updateComplaintStatus';

  // Staff & Roles
  static const String viewStaff = 'viewStaff';
  static const String manageStaff = 'manageStaff';
  static const String manageRoles = 'manageRoles';

  /// All 31 permission keys categorized by module for structured UI rendering.
  static const Map<String, List<({String key, String label, String desc})>>
      categorizedPermissions = {
    'Dashboard': [
      (
        key: viewDashboard,
        label: 'View Dashboard',
        desc: 'Access analytics, revenue KPIs, and order charts'
      ),
    ],
    'Customers': [
      (
        key: viewCustomers,
        label: 'View Customers',
        desc: 'Browse customer list and profiles'
      ),
      (
        key: createCustomer,
        label: 'Create Customer',
        desc: 'Register new customers and assign zones'
      ),
      (
        key: editCustomer,
        label: 'Edit Customer',
        desc: 'Update customer details and wallet balances'
      ),
      (
        key: deleteCustomer,
        label: 'Delete Customer',
        desc: 'Deactivate or delete customer accounts'
      ),
    ],
    'Subscriptions': [
      (
        key: viewSubscriptions,
        label: 'View Subscriptions',
        desc: 'Browse active, paused, and cancelled subscriptions'
      ),
      (
        key: createSubscription,
        label: 'Create Subscription',
        desc: 'Set up recurring milk subscriptions'
      ),
      (
        key: editSubscription,
        label: 'Edit Subscription',
        desc: 'Modify delivery quantities, slots, and pause schedules'
      ),
      (
        key: cancelSubscription,
        label: 'Cancel Subscription',
        desc: 'Terminate subscription contracts'
      ),
    ],
    'Products': [
      (
        key: viewProducts,
        label: 'View Products',
        desc: 'Browse product catalog and inventory'
      ),
      (
        key: createProduct,
        label: 'Create Product',
        desc: 'Add new dairy SKUs and nutritional specs'
      ),
      (
        key: editProduct,
        label: 'Edit Product',
        desc: 'Update prices, stock levels, and badges'
      ),
      (
        key: deleteProduct,
        label: 'Delete Product',
        desc: 'Remove products from the active catalog'
      ),
    ],
    'Categories': [
      (
        key: viewCategories,
        label: 'View Categories',
        desc: 'Browse product categories'
      ),
      (
        key: createCategory,
        label: 'Create Category',
        desc: 'Create new product classifications'
      ),
      (
        key: editCategory,
        label: 'Edit Category',
        desc: 'Update category themes and display order'
      ),
      (
        key: deleteCategory,
        label: 'Delete Category',
        desc: 'Delete categories with zero active products'
      ),
    ],
    'Orders': [
      (
        key: viewOrders,
        label: 'View Orders',
        desc: 'Browse live orders and history'
      ),
      (
        key: editOrders,
        label: 'Edit Orders',
        desc: 'Update order lifecycle statuses'
      ),
      (
        key: cancelOrders,
        label: 'Cancel Orders',
        desc: 'Cancel orders and trigger refund alerts'
      ),
      (
        key: assignDeliveryAgent,
        label: 'Assign Delivery Fleet',
        desc: 'Assign riders and route batches to orders'
      ),
    ],
    'Delivery': [
      (
        key: viewDelivery,
        label: 'View Delivery Management',
        desc: 'Inspect morning/evening corridors and batches'
      ),
      (
        key: manageDelivery,
        label: 'Manage Corridors & Batches',
        desc: 'Create routes, batch runs, and fleet schedules'
      ),
    ],
    'Payments': [
      (
        key: viewPayments,
        label: 'View Payments',
        desc: 'Review transactions, wallet debits, and collections'
      ),
      (
        key: updatePaymentStatus,
        label: 'Update Payment Status',
        desc: 'Verify and settle pending cash collections'
      ),
    ],
    'Notifications': [
      (
        key: viewNotifications,
        label: 'View Notifications',
        desc: 'Inspect notification history and delivery logs'
      ),
      (
        key: sendNotifications,
        label: 'Broadcast / Send Notifications',
        desc: 'Dispatch push alerts to customers and fleet'
      ),
    ],
    'Support': [
      (
        key: viewComplaints,
        label: 'View Support Tickets',
        desc: 'Inspect customer complaints and issues'
      ),
      (
        key: replyComplaints,
        label: 'Reply to Tickets',
        desc: 'Send official resolutions and notes to customers'
      ),
      (
        key: updateComplaintStatus,
        label: 'Update Ticket Status',
        desc: 'Resolve and close customer complaints'
      ),
    ],
    'Staff & Roles': [
      (
        key: viewStaff,
        label: 'View Staff & Roles',
        desc: 'Inspect administrative roster and role assignments'
      ),
      (
        key: manageStaff,
        label: 'Manage Staff Members',
        desc: 'Add, edit, activate, or deactivate staff members'
      ),
      (
        key: manageRoles,
        label: 'Manage Roles & Permissions',
        desc: 'Modify granular permission sets and assign Super Admin roles'
      ),
    ],
  };

  /// Returns a flat list of all 31 permission keys.
  static List<String> get allPermissions {
    final list = <String>[];
    for (final group in categorizedPermissions.values) {
      for (final perm in group) {
        list.add(perm.key);
      }
    }
    return list;
  }
}

/// Predefined standard role presets with sensible permission bundles.
class StaffRolePresets {
  /// Admin (Super Admin): Unrestricted access to all features.
  static List<String> get adminPermissions => StaffPermission.allPermissions;

  /// Operations Manager: Full access to daily business operations except Staff/Role alterations.
  static List<String> get managerPermissions => [
        StaffPermission.viewDashboard,
        StaffPermission.viewCustomers,
        StaffPermission.createCustomer,
        StaffPermission.editCustomer,
        StaffPermission.deleteCustomer,
        StaffPermission.viewSubscriptions,
        StaffPermission.createSubscription,
        StaffPermission.editSubscription,
        StaffPermission.cancelSubscription,
        StaffPermission.viewProducts,
        StaffPermission.createProduct,
        StaffPermission.editProduct,
        StaffPermission.deleteProduct,
        StaffPermission.viewCategories,
        StaffPermission.createCategory,
        StaffPermission.editCategory,
        StaffPermission.deleteCategory,
        StaffPermission.viewOrders,
        StaffPermission.editOrders,
        StaffPermission.cancelOrders,
        StaffPermission.assignDeliveryAgent,
        StaffPermission.viewDelivery,
        StaffPermission.manageDelivery,
        StaffPermission.viewPayments,
        StaffPermission.updatePaymentStatus,
        StaffPermission.viewNotifications,
        StaffPermission.sendNotifications,
        StaffPermission.viewComplaints,
        StaffPermission.replyComplaints,
        StaffPermission.updateComplaintStatus,
        StaffPermission.viewStaff,
        StaffPermission.manageStaff,
      ];

  /// Dispatcher: Focus on live order dispatch, delivery fleet routing, and notifications.
  static List<String> get dispatcherPermissions => [
        StaffPermission.viewDashboard,
        StaffPermission.viewCustomers,
        StaffPermission.viewSubscriptions,
        StaffPermission.viewProducts,
        StaffPermission.viewCategories,
        StaffPermission.viewOrders,
        StaffPermission.editOrders,
        StaffPermission.assignDeliveryAgent,
        StaffPermission.viewDelivery,
        StaffPermission.manageDelivery,
        StaffPermission.viewNotifications,
        StaffPermission.sendNotifications,
        StaffPermission.viewComplaints,
      ];

  /// Staff Member: Operational day-to-day viewing and minor customer/support updates.
  static List<String> get staffPermissions => [
        StaffPermission.viewDashboard,
        StaffPermission.viewCustomers,
        StaffPermission.editCustomer,
        StaffPermission.viewSubscriptions,
        StaffPermission.editSubscription,
        StaffPermission.viewProducts,
        StaffPermission.viewCategories,
        StaffPermission.viewOrders,
        StaffPermission.editOrders,
        StaffPermission.viewPayments,
        StaffPermission.viewNotifications,
        StaffPermission.viewComplaints,
        StaffPermission.replyComplaints,
      ];

  /// Resolves default permission preset for a given role key.
  static List<String> getPermissionsForRole(String role) {
    switch (role.toLowerCase().trim()) {
      case 'admin':
      case 'superadmin':
      case 'owner':
        return adminPermissions;
      case 'manager':
        return managerPermissions;
      case 'dispatcher':
        return dispatcherPermissions;
      case 'staff':
      default:
        return staffPermissions;
    }
  }

  /// Canonical display title for a role.
  static String getDisplayTitleForRole(String role) {
    switch (role.toLowerCase().trim()) {
      case 'admin':
      case 'superadmin':
      case 'owner':
        return 'Super Admin';
      case 'manager':
        return 'Operations Manager';
      case 'dispatcher':
        return 'Route Dispatcher';
      case 'staff':
      default:
        return 'Staff Member';
    }
  }
}

/// Domain Model for an Administrative Staff Member in Sawariya Dairy.
class StaffMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin', 'manager', 'dispatcher', 'staff'
  final String roleTitle; // 'Super Admin', 'Operations Manager', etc.
  final String status; // 'Active', 'Inactive'
  final List<String> permissions;
  final String joinedDate;
  final String? profileImageUrl;

  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.roleTitle,
    this.status = 'Active',
    this.permissions = const [],
    this.joinedDate = 'Active',
    this.profileImageUrl,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isSuperAdmin =>
      role.toLowerCase() == 'admin' ||
      role.toLowerCase() == 'superadmin' ||
      role.toLowerCase() == 'owner';

  bool hasPermission(String permissionKey) {
    if (isSuperAdmin) return true;
    return permissions.contains(permissionKey);
  }

  StaffMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? roleTitle,
    String? status,
    List<String>? permissions,
    String? joinedDate,
    String? profileImageUrl,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roleTitle: roleTitle ?? this.roleTitle,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      joinedDate: joinedDate ?? this.joinedDate,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  factory StaffMember.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final roleRaw = (data['role'] as String? ?? 'staff').toLowerCase().trim();
    final roleTitle = (data['roleTitle'] as String? ?? '').trim().isNotEmpty
        ? (data['roleTitle'] as String).trim()
        : StaffRolePresets.getDisplayTitleForRole(roleRaw);

    final rawPermissions = data['permissions'];
    List<String> perms = [];
    if (rawPermissions is List) {
      perms = rawPermissions
          .map((p) => p.toString().trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    if (perms.isEmpty) {
      perms = StaffRolePresets.getPermissionsForRole(roleRaw);
    }

    final dynamic candidateImage = data['profileImageUrl'] ??
        data['photoUrl'] ??
        data['photoURL'] ??
        data['profileImage'] ??
        data['imageUrl'] ??
        data['avatar'];

    String joinedStr = 'Active';
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        joinedStr = DateFormat('dd MMM yyyy')
            .format((data['createdAt'] as Timestamp).toDate());
      } else if (data['createdAt'] is String) {
        joinedStr = data['createdAt'] as String;
      }
    }

    return StaffMember(
      id: doc.id,
      name: (data['name'] as String? ?? 'Admin User').trim(),
      email: (data['email'] as String? ?? 'admin@sawariyadairy.com').trim(),
      phone: (data['phone'] as String? ?? '').trim(),
      role: roleRaw,
      roleTitle: roleTitle,
      status: (data['status'] as String? ?? 'Active').trim(),
      permissions: perms,
      joinedDate: joinedStr,
      profileImageUrl:
          (candidateImage is String && candidateImage.trim().isNotEmpty)
              ? candidateImage.trim()
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.toLowerCase().trim(),
      'roleTitle': roleTitle.trim(),
      'status': status.trim(),
      'permissions': permissions,
      'isAdmin': isSuperAdmin,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
