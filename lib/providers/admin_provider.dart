import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import '../models/complaint_model.dart' as complaint_model;
import '../models/customer_model.dart';
import '../models/delivery_model.dart';
import '../models/delivery_staff_model.dart';
import '../models/kpi_data.dart';
import '../models/order.dart' as order;
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../repositories/firestore_product_repository.dart';
import '../services/complaint_service.dart';
import '../services/order_service.dart';

class AdminProvider extends ChangeNotifier {
  final FirestoreProductRepository _repo;
  final OrderService _orderService;
  final ComplaintService _complaintService;

  int _selectedNavIndex = 2;
  String _searchQuery = '';
  String _orderStatusTimeFilter = 'Today';
  int _unreadNotifications = 5;
  bool _isDarkMode = false;

  List<DairyProduct> _products = [];
  List<DairyCategory> _categories = [];
  bool _isLoading = true;
  String? _error;

  List<DairyOrder> _orders = [];
  bool _ordersLoading = true;
  String? _ordersError;

  List<complaint_model.CustomerComplaint> _complaints = [];
  bool _complaintsLoading = true;
  String? _complaintsError;

  int _customersCount = 0;
  int _deliveryAgentsCount = 0;
  bool _usersLoading = true;
  String? _usersError;

  StreamSubscription<List<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<List<order.Order>>? _ordersSub;
  StreamSubscription<List<complaint_model.CustomerComplaint>>? _complaintsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deliveryAgentsSub;

  int get selectedNavIndex => _selectedNavIndex;
  String get searchQuery => _searchQuery;
  String get orderStatusTimeFilter => _orderStatusTimeFilter;
  int get unreadNotifications => _unreadNotifications;
  bool get isDarkMode => _isDarkMode;
  List<DairyProduct> get products => _products;
  List<DairyCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get ordersLoading => _ordersLoading;
  String? get ordersError => _ordersError;

  List<complaint_model.CustomerComplaint> get complaints => _complaints;
  bool get complaintsLoading => _complaintsLoading;
  String? get complaintsError => _complaintsError;

  int get customersCount => _customersCount;
  int get deliveryAgentsCount => _deliveryAgentsCount;
  bool get usersLoading => _usersLoading;
  String? get usersError => _usersError;

  int get totalOrdersCount => _orders.length;
  int get pendingOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.pending).length;
  int get confirmedOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.confirmed).length;
  int get preparingOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.preparing).length;
  int get outForDeliveryOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.outForDelivery).length;
  int get deliveredOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.delivered).length;
  int get cancelledOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.cancelled).length;
  int get activeOrdersCount => _orders
      .where((o) =>
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.outForDelivery)
      .length;

  double get totalRevenue => _orders
      .where((o) => o.status == OrderStatus.delivered)
      .fold(0.0, (total, o) => total + o.amount);

  double get totalOrderValue => _orders
      .where((o) => o.status != OrderStatus.cancelled)
      .fold(0.0, (total, o) => total + o.amount);

  List<DairyProduct> get topSellingProducts =>
      _products.where((p) => p.isBestSeller).toList();

  AdminProvider({
    FirestoreProductRepository? repo,
    OrderService? orderService,
    ComplaintService? complaintService,
  })  : _repo = repo ?? FirestoreProductRepository(),
        _orderService = orderService ?? OrderService(),
        _complaintService = complaintService ?? ComplaintService() {
    _listenToProducts();
    _listenToCategories();
    _listenToOrders();
    _listenToComplaints();
    _listenToUsers();
    _listenToDeliveryAgents();
  }

  // ─── Firestore listeners ───────────────────────────────────────────────

  void _listenToProducts() {
    _productsSub = _repo.streamRawProducts().listen(
      (docs) {
        _products = docs.map(_rawToDairyProduct).toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Failed to load products: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenToCategories() {
    _categoriesSub = _repo.streamRawCategories().listen(
      (docs) {
        _categories = docs.map(_rawToDairyCategory).toList();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('AdminProvider: category stream error: $e');
      },
    );
  }

  void _listenToOrders() {
    _ordersSub = _orderService.streamAllDeliveryOrders().listen(
      (orders) {
        _orders = orders.map(_dairyOrderFromOrder).toList();
        _ordersLoading = false;
        _ordersError = null;
        notifyListeners();
      },
      onError: (e) {
        _ordersError = 'Failed to load orders: $e';
        _ordersLoading = false;
        notifyListeners();
      },
    );
  }

  /// Maps a Firestore-backed [order.Order] onto the admin-facing
  /// [DairyOrder] used by the Orders screen, tolerating missing fields.
  DairyOrder _dairyOrderFromOrder(order.Order o) {
    final itemsSummary = o.items
        .map((it) {
          final title = it.product.title.trim();
          if (title.isEmpty) return '';
          final unit = it.product.unit.trim();
          return it.quantity > 1
              ? '$title (${it.quantity}${unit.isEmpty ? '' : ' $unit'})'
              : title;
        })
        .where((s) => s.isNotEmpty)
        .join(', ');

    final agentId = o.assignedAgentId?.trim();
    String? agentName;
    if (agentId != null && agentId.isNotEmpty) {
      final match = _riders.cast<DeliveryRider?>().firstWhere(
            (r) => r?.id == agentId,
            orElse: () => null,
          );
      agentName = match?.name;
    }

    return DairyOrder(
      id: o.id,
      orderCode: o.displayOrderCode,
      customerName: o.deliveryAddress.fullName.trim().isNotEmpty
          ? o.deliveryAddress.fullName
          : 'Customer',
      customerPhone: o.deliveryAddress.mobileNumber,
      itemsSummary: itemsSummary,
      amount: o.totalAmount,
      status: _mapFromServiceStatus(o.status),
      deliverySlot: o.estimatedDeliveryTime,
      address: o.deliveryAddress.fullAddressText,
      time: DateFormat('hh:mm a').format(o.orderDate),
      paymentMode: o.paymentMethod,
      assignedAgentId: agentId,
      assignedAgentName: agentName,
    );
  }

  /// App-side [order.OrderStatus] -> admin [OrderStatus].
  OrderStatus _mapFromServiceStatus(order.OrderStatus s) {
    switch (s) {
      case order.OrderStatus.placed:
        return OrderStatus.pending;
      case order.OrderStatus.confirmed:
        return OrderStatus.confirmed;
      case order.OrderStatus.preparing:
        return OrderStatus.preparing;
      case order.OrderStatus.outForDelivery:
        return OrderStatus.outForDelivery;
      case order.OrderStatus.delivered:
        return OrderStatus.delivered;
      case order.OrderStatus.cancelled:
        return OrderStatus.cancelled;
    }
  }

  /// Admin [OrderStatus] -> app-side [order.OrderStatus] for the service.
  order.OrderStatus _mapToServiceStatus(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return order.OrderStatus.placed;
      case OrderStatus.confirmed:
        return order.OrderStatus.confirmed;
      case OrderStatus.preparing:
        return order.OrderStatus.preparing;
      case OrderStatus.outForDelivery:
        return order.OrderStatus.outForDelivery;
      case OrderStatus.delivered:
        return order.OrderStatus.delivered;
      case OrderStatus.cancelled:
        return order.OrderStatus.cancelled;
    }
  }

  // ─── Mapping helpers ──────────────────────────────────────────────────

  static const Map<String, String> _categoryNameToId = {
    'Milk': 'cat_milk',
    'Milk & Creams': 'cat_milk',
    'Paneer': 'cat_paneer',
    'Paneer & Curd': 'cat_paneer',
    'Paneer & Butter': 'cat_paneer',
    'Ghee': 'cat_ghee',
    'Pure Ghee': 'cat_ghee',
    'Ghee & Butter': 'cat_ghee',
    'Beverages': 'cat_lassi',
    'Lassi': 'cat_lassi',
    'Curd & Lassi': 'cat_lassi',
    'Makhan': 'cat_makhan',
    'Uple': 'cat_uple',
    'Cow Dung Cake': 'cat_uple',
    'Organic Uple': 'cat_uple',
    'Pooja Essentials': 'cat_uple',
    'Water': 'cat_water',
    'Water Bottle': 'cat_water',
    'Water Bottle 20L': 'cat_water',
  };

  static String _categoryIdForName(String name) {
    return _categoryNameToId[name] ??
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  DairyProduct _rawToDairyProduct(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? (raw['productId'] as String?) ?? '';
    final rawImageUrl = (raw['imageUrl'] as String?) ??
        (raw['image'] as String?) ??
        (raw['image_url'] as String?) ??
        (raw['imageURL'] as String?) ??
        (raw['photoUrl'] as String?) ??
        '';
    final name = (raw['title'] as String?) ?? (raw['name'] as String?) ?? '';
    final subtitle =
        (raw['description'] as String?) ?? (raw['subtitle'] as String?) ?? '';
    final category =
        (raw['categoryName'] as String?) ?? (raw['category'] as String?) ?? '';

    final product = DairyProduct(
      id: id,
      name: name,
      subtitle: subtitle,
      category: category,
      unit: (raw['unit'] as String?) ?? '',
      price: (raw['price'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (raw['ordersCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (raw['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (raw['stockQuantity'] as num?)?.toInt() ?? 0,
      fatContent: (raw['fatContent'] as String?) ?? '',
      packaging: (raw['packaging'] as String?) ?? '',
      inStock: (raw['inStock'] as bool?) ?? true,
      emoji: (raw['emoji'] as String?) ?? '🥛',
      isBestSeller: (raw['isBestSeller'] as bool?) ?? false,
      imageUrl: rawImageUrl.trim(),
    );

    if (product.id == 'prod_1788762789345' || product.imageUrl.isNotEmpty) {
      debugPrint('ADMIN PRODUCT ${product.id}');
      debugPrint('Firestore imageUrl: ${product.imageUrl}');
      debugPrint('Resolved imageUrl: ${product.resolvedImageUrl}');
    }

    return product;
  }

  Map<String, dynamic> _dairyProductToFirestore(DairyProduct p) {
    return {
      'title': p.name,
      'description': p.subtitle,
      'categoryName': p.category,
      'categoryId': _categoryIdForName(p.category),
      'price': p.price,
      'originalPrice': null,
      'unit': p.unit,
      'imageUrl': p.imageUrl,
      'rating': 4.8,
      'reviewCount': 0,
      'isFreshDeal': false,
      'isBestSeller': p.isBestSeller,
      'isA2CowMilk': false,
      'inStock': p.inStock,
      'fatContent': p.fatContent,
      'packaging': p.packaging,
      'emoji': p.emoji,
      'stockQuantity': p.stockQuantity,
      'ordersCount': p.ordersCount,
      'totalRevenue': p.totalRevenue,
    };
  }

  DairyCategory _rawToDairyCategory(Map<String, dynamic> raw) {
    final colorValue = raw['colorValue'] as int?;
    final createdAtRaw = raw['createdAt'];
    final updatedAtRaw = raw['updatedAt'];

    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    DateTime? updatedAt;
    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    } else if (updatedAtRaw is String) {
      updatedAt = DateTime.tryParse(updatedAtRaw);
    }

    return DairyCategory(
      id: raw['id'] as String? ?? '',
      name: (raw['name'] as String?) ?? (raw['title'] as String?) ?? '',
      description:
          (raw['description'] as String?) ?? (raw['subtitle'] as String?) ?? '',
      productCount: (raw['productCount'] as num?)?.toInt() ??
          (raw['itemCount'] as num?)?.toInt() ??
          0,
      icon: Icons.category_rounded,
      color: colorValue != null ? Color(colorValue) : AppColors.primary,
      emoji: (raw['emoji'] as String?) ?? '🥛',
      imageUrl: (raw['imageUrl'] as String?) ?? '',
      isActive: (raw['isActive'] as bool?) ?? true,
      sortOrder: (raw['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> _dairyCategoryToFirestore(DairyCategory c) {
    return {
      'title': c.name,
      'name': c.name,
      'subtitle': c.description,
      'description': c.description,
      'imageUrl': c.imageUrl,
      'iconName': null,
      'colorValue': c.color.toARGB32(),
      'itemCount': c.productCount,
      'productCount': c.productCount,
      'emoji': c.emoji,
      'isActive': c.isActive,
      'sortOrder': c.sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
      if (c.createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── Product CRUD (Firestore) ─────────────────────────────────────────

  Future<void> addProduct(DairyProduct product) async {
    try {
      final data = _dairyProductToFirestore(product);
      await _repo.setProductRaw(product.id, data);
    } catch (e) {
      _error = 'Failed to add product: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProduct(DairyProduct product) async {
    try {
      final data = _dairyProductToFirestore(product);
      await _repo.setProductRaw(product.id, data);
    } catch (e) {
      _error = 'Failed to update product: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _repo.deleteProduct(id);
    } catch (e) {
      _error = 'Failed to delete product: $e';
      notifyListeners();
    }
  }

  Future<void> toggleProductStock(String id) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    try {
      final product = _products[index];
      final toggled = product.copyWith(inStock: !product.inStock);
      await updateProduct(toggled);
    } catch (e) {
      _error = 'Failed to toggle stock: $e';
      notifyListeners();
    }
  }

  Future<void> toggleBestSeller(String id) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    try {
      final product = _products[index];
      final toggled = product.copyWith(isBestSeller: !product.isBestSeller);
      await updateProduct(toggled);
    } catch (e) {
      _error = 'Failed to toggle best seller: $e';
      notifyListeners();
    }
  }

  // ─── Category CRUD (Firestore) ────────────────────────────────────────

  /// Checks whether any existing products are linked to the given category ID or name.
  bool hasLinkedProducts(String categoryId) {
    final catIndex = _categories.indexWhere((c) => c.id == categoryId);
    final catName = catIndex != -1 ? _categories[catIndex].name.trim().toLowerCase() : '';
    return _products.any((p) {
      final pCatId = _categoryIdForName(p.category);
      return pCatId == categoryId ||
          (catName.isNotEmpty && p.category.trim().toLowerCase() == catName);
    });
  }

  /// Counts the number of active/existing products belonging to a category.
  int countLinkedProducts(String categoryId) {
    final catIndex = _categories.indexWhere((c) => c.id == categoryId);
    final catName = catIndex != -1 ? _categories[catIndex].name.trim().toLowerCase() : '';
    return _products.where((p) {
      final pCatId = _categoryIdForName(p.category);
      return pCatId == categoryId ||
          (catName.isNotEmpty && p.category.trim().toLowerCase() == catName);
    }).length;
  }

  /// Toggles the active status of a category.
  Future<void> toggleCategoryActive(String id) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final cat = _categories[index];
    final updated = cat.copyWith(isActive: !cat.isActive);
    await updateCategory(updated);
  }

  Future<void> addCategory(DairyCategory category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      _error = 'Category name cannot be empty';
      notifyListeners();
      throw Exception('Category name cannot be empty');
    }

    final isDuplicate = _categories.any(
      (c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (isDuplicate) {
      _error = 'A category with the name "$trimmedName" already exists.';
      notifyListeners();
      throw Exception('A category with the name "$trimmedName" already exists.');
    }

    try {
      final data = _dairyCategoryToFirestore(category);
      await _repo.setCategoryRaw(category.id, data);
      _error = null;
    } catch (e) {
      _error = 'Failed to add category: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCategory(DairyCategory category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      _error = 'Category name cannot be empty';
      notifyListeners();
      throw Exception('Category name cannot be empty');
    }

    final isDuplicate = _categories.any(
      (c) =>
          c.id != category.id &&
          c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (isDuplicate) {
      _error = 'A category with the name "$trimmedName" already exists.';
      notifyListeners();
      throw Exception('A category with the name "$trimmedName" already exists.');
    }

    try {
      final data = _dairyCategoryToFirestore(category);
      await _repo.setCategoryRaw(category.id, data);
      _error = null;
    } catch (e) {
      _error = 'Failed to update category: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    final catIndex = _categories.indexWhere((c) => c.id == id);
    final catName = catIndex != -1 ? _categories[catIndex].name : id;

    if (hasLinkedProducts(id)) {
      final count = countLinkedProducts(id);
      _error =
          'Cannot delete category "$catName" because $count product(s) reference it. Please deactivate the category or reassign the products instead.';
      notifyListeners();
      throw Exception(_error);
    }

    try {
      await _repo.deleteCategory(id);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete category: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ─── Navigation & search ──────────────────────────────────────────────

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool val) {
    _isDarkMode = val;
    notifyListeners();
  }

  void setNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setOrderStatusTimeFilter(String filter) {
    _orderStatusTimeFilter = filter;
    notifyListeners();
  }

  void clearNotifications() {
    _unreadNotifications = 0;
    notifyListeners();
  }

  // ─── KPI Metrics (Firestore-backed) ───────────────────────────────────

  List<KpiMetric> get kpiMetrics {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final formattedRevenue = currencyFormatter.format(totalRevenue);

    return [
      KpiMetric(
        title: "Total Revenue",
        value: formattedRevenue,
        growthText: deliveredOrdersCount > 0
            ? '$deliveredOrdersCount orders delivered'
            : 'From delivered orders',
        isPositive: totalRevenue > 0,
        icon: Icons.currency_rupee_rounded,
        themeColor: AppColors.revenueGreen,
        themeBgColor: AppColors.revenueGreenBg,
      ),
      KpiMetric(
        title: "Total Orders",
        value: '$totalOrdersCount',
        growthText: pendingOrdersCount > 0
            ? '$pendingOrdersCount pending, $activeOrdersCount active'
            : (totalOrdersCount > 0
                ? '$activeOrdersCount active orders'
                : 'No orders yet'),
        isPositive: totalOrdersCount > 0,
        icon: Icons.shopping_bag_outlined,
        themeColor: AppColors.ordersBlue,
        themeBgColor: AppColors.ordersBlueBg,
      ),
      KpiMetric(
        title: 'Total Customers',
        value: '$_customersCount',
        growthText: _customersCount > 0
            ? 'Registered customer base'
            : 'No customers yet',
        isPositive: _customersCount > 0,
        icon: Icons.people_outline_rounded,
        themeColor: AppColors.customersOrange,
        themeBgColor: AppColors.customersOrangeBg,
      ),
      KpiMetric(
        title: 'Delivery Fleet',
        value: '$_deliveryAgentsCount',
        growthText: _deliveryAgentsCount > 0
            ? 'Active delivery agents'
            : 'No agents registered',
        isPositive: _deliveryAgentsCount > 0,
        icon: Icons.directions_bike_rounded,
        themeColor: AppColors.deliveriesPurple,
        themeBgColor: AppColors.deliveriesPurpleBg,
      ),
    ];
  }

  /// Order status lifecycle breakdown metrics
  List<KpiMetric> get orderStatusKpis => [
        KpiMetric(
          title: 'Active / On Route',
          value: '$activeOrdersCount',
          growthText: '$outForDeliveryOrdersCount out for delivery',
          isPositive: activeOrdersCount > 0,
          icon: Icons.local_shipping_outlined,
          themeColor: AppColors.statusOutForDelivery,
          themeBgColor: const Color(0xFFE8F6FD),
        ),
        KpiMetric(
          title: 'Pending Orders',
          value: '$pendingOrdersCount',
          growthText: pendingOrdersCount > 0
              ? 'Action required'
              : 'All orders processed',
          isPositive: pendingOrdersCount == 0,
          icon: Icons.pending_actions_rounded,
          themeColor: AppColors.statusPending,
          themeBgColor: const Color(0xFFFFF4EC),
        ),
        KpiMetric(
          title: 'Delivered Orders',
          value: '$deliveredOrdersCount',
          growthText: deliveredOrdersCount > 0
              ? '${((deliveredOrdersCount / (totalOrdersCount > 0 ? totalOrdersCount : 1)) * 100).toStringAsFixed(0)}% completion'
              : 'None delivered yet',
          isPositive: true,
          icon: Icons.check_circle_outline_rounded,
          themeColor: AppColors.statusDelivered,
          themeBgColor: const Color(0xFFE8FAF2),
        ),
        KpiMetric(
          title: 'Cancelled Orders',
          value: '$cancelledOrdersCount',
          growthText: cancelledOrdersCount == 0
              ? '0% cancellation rate'
              : '$cancelledOrdersCount cancelled',
          isPositive: cancelledOrdersCount == 0,
          icon: Icons.cancel_outlined,
          themeColor: AppColors.statusCancelled,
          themeBgColor: const Color(0xFFF1F5F9),
        ),
      ];

  // ─── Orders (Firestore-backed via OrderService) ───────────────────────

  List<DairyOrder> get orders => _orders;
  List<DairyOrder> get recentOrders => _orders.take(5).toList();

  /// Updates an order's status in the shared Firestore `orders` document using
  /// the existing [OrderService], so customers and delivery agents see the same
  /// change. The UI is refreshed by the live orders stream (no optimistic
  /// update), so a failed write leaves the status unchanged in the UI.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    await _orderService.updateOrderStatus(
      orderId,
      _mapToServiceStatus(newStatus),
    );
  }

  // ─── Today's Deliveries Data (hardcoded) ──────────────────────────────

  final List<DeliveryBatch> _deliveryBatches = [
    const DeliveryBatch(
      deliveryId: '#DLV1021',
      staffName: 'Amit Kumar',
      assignedCount: 82,
      completedCount: 76,
      status: 'On Route',
      zone: 'Sector 74 - 78 Hub',
    ),
    const DeliveryBatch(
      deliveryId: '#DLV1022',
      staffName: 'Rajesh Sharma',
      assignedCount: 95,
      completedCount: 95,
      status: 'Completed',
      zone: 'Sector 50 - 52 Hub',
    ),
    const DeliveryBatch(
      deliveryId: '#DLV1023',
      staffName: 'Vikram Singh',
      assignedCount: 88,
      completedCount: 81,
      status: 'On Route',
      zone: 'Expressway Corridors',
    ),
    const DeliveryBatch(
      deliveryId: '#DLV1024',
      staffName: 'Suresh Verma',
      assignedCount: 75,
      completedCount: 70,
      status: 'On Route',
      zone: 'Greater Noida West',
    ),
    const DeliveryBatch(
      deliveryId: '#DLV1025',
      staffName: 'Manoj Tiwari',
      assignedCount: 65,
      completedCount: 65,
      status: 'Completed',
      zone: 'Indirapuram Core',
    ),
  ];

  List<DeliveryBatch> get deliveryBatches => _deliveryBatches;

  // ─── Delivery Corridors Data (hardcoded) ──────────────────────────────

  final List<DeliveryCorridor> _corridors = [
    const DeliveryCorridor(
      routeName: 'Route 1 — Noida Express Zone',
      zone: 'Sector 128 to 137',
      riderName: 'Amit Kumar',
      subscribersCount: 142,
      timing: '05:00 AM - 06:45 AM',
      vehicleType: 'Electric Cargo Van',
    ),
    const DeliveryCorridor(
      routeName: 'Route 2 — Sector 7x Highrise Belt',
      zone: 'Sector 74, 76, 78, 79',
      riderName: 'Vikram Singh',
      subscribersCount: 185,
      timing: '05:15 AM - 07:00 AM',
      vehicleType: 'EV Bike 3-Wheeler',
    ),
    const DeliveryCorridor(
      routeName: 'Route 3 — Central Noida Hub',
      zone: 'Sector 50, 51, 52',
      riderName: 'Rajesh Sharma',
      subscribersCount: 128,
      timing: '05:30 AM - 07:15 AM',
      vehicleType: 'Cargo Bike',
    ),
    const DeliveryCorridor(
      routeName: 'Route 4 — Greater Noida West',
      zone: 'Gaur City 1 & 2',
      riderName: 'Suresh Verma',
      subscribersCount: 164,
      timing: '05:00 AM - 07:00 AM',
      vehicleType: 'Electric Mini Van',
    ),
  ];

  List<DeliveryCorridor> get corridors => _corridors;

  // ─── Customers Data (Firestore-backed) ─────────────────────────────────

  List<DairyCustomer> _customers = [];

  List<DairyCustomer> get customers => _customers;

  /// Saves a new customer document in the Firestore `users` collection.
  Future<void> addCustomer(DairyCustomer customer) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(customer.id)
          .set({
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'deliveryZone': customer.deliveryZone,
        'subscriptionPlan': customer.subscriptionPlan,
        'milkPreference': customer.milkPreference,
        'walletBalance': customer.walletBalance,
        'status': customer.status,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AdminProvider: Failed to add customer to Firestore: $e');
      _usersError = 'Failed to add customer: $e';
      notifyListeners();
    }
  }

  /// Updates an existing customer document in the Firestore `users` collection.
  Future<void> updateCustomer(DairyCustomer customer) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(customer.id)
          .set({
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'deliveryZone': customer.deliveryZone,
        'subscriptionPlan': customer.subscriptionPlan,
        'milkPreference': customer.milkPreference,
        'walletBalance': customer.walletBalance,
        'status': customer.status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AdminProvider: Failed to update customer in Firestore: $e');
      _usersError = 'Failed to update customer: $e';
      notifyListeners();
    }
  }

  /// Deletes a customer document from the Firestore `users` collection.
  Future<void> deleteCustomer(String id) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
    } catch (e) {
      debugPrint('AdminProvider: Failed to delete customer from Firestore: $e');
      _usersError = 'Failed to delete customer: $e';
      notifyListeners();
    }
  }

  // ─── Delivery Staff Riders (Firestore-backed) ─────────────────────────

  List<DeliveryRider> _riders = [];

  List<DeliveryRider> get riders => _riders;

  /// Registers a new delivery staff member in Firestore `users` and `delivery_agents`.
  Future<void> addRider(DeliveryRider rider) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(rider.id).set({
        'id': rider.id,
        'uid': rider.id,
        'name': rider.name,
        'phone': rider.phone,
        'email': rider.email,
        'role': 'delivery',
        'vehicle': rider.vehicle,
        'vehicleNumber': rider.vehicleNumber,
        'assignedZone': rider.assignedZone,
        'status': rider.status,
        if (rider.rating != null) 'rating': rider.rating,
        if (rider.profileImageUrl != null) ...{
          'profileImageUrl': rider.profileImageUrl,
          'photoUrl': rider.profileImageUrl,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('delivery_agents')
          .doc(rider.id)
          .set({
        'id': rider.id,
        'uid': rider.id,
        'name': rider.name,
        'phone': rider.phone,
        'email': rider.email,
        'vehicle': rider.vehicle,
        'vehicleNumber': rider.vehicleNumber,
        'assignedZone': rider.assignedZone,
        'isOnline': rider.status.toLowerCase() == 'active' || rider.isOnline,
        'isOnDuty': rider.status.toLowerCase() == 'active' || rider.isOnline,
        'status': rider.status,
        if (rider.rating != null) 'rating': rider.rating,
        if (rider.profileImageUrl != null) ...{
          'profileImageUrl': rider.profileImageUrl,
          'photoUrl': rider.profileImageUrl,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
          'AdminProvider: Failed to add delivery staff to Firestore: $e');
      _usersError = 'Failed to add delivery staff: $e';
      notifyListeners();
    }
  }

  /// Updates a delivery staff member in Firestore `users` and `delivery_agents`.
  Future<void> updateRider(DeliveryRider rider) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(rider.id).set({
        'name': rider.name,
        'phone': rider.phone,
        'email': rider.email,
        'vehicle': rider.vehicle,
        'vehicleNumber': rider.vehicleNumber,
        'assignedZone': rider.assignedZone,
        'status': rider.status,
        if (rider.rating != null) 'rating': rider.rating,
        if (rider.profileImageUrl != null) ...{
          'profileImageUrl': rider.profileImageUrl,
          'photoUrl': rider.profileImageUrl,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('delivery_agents')
          .doc(rider.id)
          .set({
        'uid': rider.id,
        'name': rider.name,
        'phone': rider.phone,
        'email': rider.email,
        'vehicle': rider.vehicle,
        'vehicleNumber': rider.vehicleNumber,
        'assignedZone': rider.assignedZone,
        'isOnline': rider.status.toLowerCase() == 'active' || rider.isOnline,
        'isOnDuty': rider.status.toLowerCase() == 'active' || rider.isOnline,
        'status': rider.status,
        if (rider.rating != null) 'rating': rider.rating,
        if (rider.profileImageUrl != null) ...{
          'profileImageUrl': rider.profileImageUrl,
          'photoUrl': rider.profileImageUrl,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
          'AdminProvider: Failed to update delivery staff in Firestore: $e');
      _usersError = 'Failed to update delivery staff: $e';
      notifyListeners();
    }
  }

  /// Deletes a delivery staff member from Firestore `users` and `delivery_agents`.
  Future<void> deleteRider(String id) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
      await FirebaseFirestore.instance
          .collection('delivery_agents')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('AdminProvider: Failed to delete delivery staff: $e');
      _usersError = 'Failed to delete delivery staff: $e';
      notifyListeners();
    }
  }

  // ─── Payments Data (hardcoded) ────────────────────────────────────────

  final List<DairyPayment> _payments = [
    const DairyPayment(
      id: 'TXN-99812',
      customerName: 'Rahul Sharma',
      orderOrWalletId: '#ORD10284',
      amount: 163.0,
      method: 'Online (UPI)',
      status: 'Success',
      timestamp: 'Today, 05:42 AM',
    ),
    const DairyPayment(
      id: 'TXN-99811',
      customerName: 'Priya Verma',
      orderOrWalletId: 'Wallet Auto-Debit',
      amount: 114.0,
      method: 'Prepaid Wallet',
      status: 'Success',
      timestamp: 'Today, 06:10 AM',
    ),
    const DairyPayment(
      id: 'TXN-99810',
      customerName: 'Anil Gupta',
      orderOrWalletId: '#ORD10282',
      amount: 608.0,
      method: 'Razorpay PG',
      status: 'Success',
      timestamp: 'Today, 06:25 AM',
    ),
    const DairyPayment(
      id: 'TXN-99809',
      customerName: 'Vikas Malhotra',
      orderOrWalletId: '#ORD10280',
      amount: 362.0,
      method: 'Cash On Delivery',
      status: 'Pending',
      timestamp: 'Today, 07:45 AM',
    ),
  ];

  List<DairyPayment> get payments => _payments;

  // ─── Support Complaints (Firestore-backed) ───────────────────────────

  void _listenToComplaints() {
    _complaintsSub = _complaintService.streamAllComplaints().listen(
      (list) {
        _complaints = list;
        _complaintsLoading = false;
        _complaintsError = null;
        notifyListeners();
      },
      onError: (e) {
        _complaintsError = 'Failed to load complaints: $e';
        _complaintsLoading = false;
        notifyListeners();
      },
    );
  }

  /// Update complaint status and optional admin reply in Firestore.
  Future<void> updateComplaintStatus(
    String complaintId,
    String newStatus, {
    String? adminReply,
  }) async {
    await _complaintService.updateComplaintStatus(
      complaintId,
      newStatus,
      adminReply: adminReply,
    );
  }

  /// Add or update admin response message for a complaint ticket.
  Future<void> addComplaintReply(
    String complaintId,
    String adminReply, {
    String? newStatus,
  }) async {
    await _complaintService.addAdminReply(
      complaintId,
      adminReply,
      newStatus: newStatus,
    );
  }

  // ─── Users & Delivery Agents Firestore Listeners ────────────────────

  List<Map<String, String>> _staffList = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastUserDocs = [];

  List<Map<String, String>> get staffList => _staffList;

  void _rebuildCustomers() {
    int custCount = 0;
    final List<DairyCustomer> custList = [];
    final List<Map<String, String>> staff = [];

    for (final doc in _lastUserDocs) {
      final data = doc.data();
      final role = (data['role'] as String? ?? 'customer').toLowerCase();
      final name = (data['name'] as String? ?? '').trim();
      final phone = (data['phone'] as String? ?? '').trim();
      final email = (data['email'] as String? ?? '').trim();

      if (role == 'delivery') {
        // Delivery agent account - excluded from customers
        continue;
      } else if (role == 'admin' ||
          role == 'staff' ||
          role == 'manager' ||
          role == 'dispatcher') {
        // Administrative / Staff account
        staff.add({
          'name': name.isNotEmpty ? name : 'Admin User',
          'email': email.isNotEmpty ? email : 'admin@sawariyadairy.com',
          'role': role == 'admin'
              ? 'Super Admin'
              : (data['roleTitle'] as String? ?? 'Staff Member'),
          'status': (data['status'] as String? ?? 'Active'),
        });
      } else {
        // Genuine Customer account
        custCount++;
        custList.add(
          DairyCustomer(
            id: doc.id,
            name: name.isNotEmpty ? name : 'Customer',
            phone: phone.isNotEmpty ? phone : '+91 99999 00000',
            email: email.isNotEmpty
                ? email
                : '${doc.id.toLowerCase()}@sawariyadairy.com',
            address: (data['address'] as String? ?? 'Noida, Uttar Pradesh'),
            deliveryZone: (data['deliveryZone'] as String? ?? 'Standard Zone'),
            subscriptionPlan: (data['subscriptionPlan'] as String? ??
                'Daily Morning (2 Litres)'),
            milkPreference:
                (data['milkPreference'] as String? ?? 'Standard Cow Milk'),
            walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
            status: (data['status'] as String? ?? 'Active'),
            joinedDate: data['createdAt'] != null
                ? (data['createdAt'] is Timestamp
                    ? DateFormat('dd MMM yyyy')
                        .format((data['createdAt'] as Timestamp).toDate())
                    : 'Active')
                : 'Active',
          ),
        );
      }
    }

    _customers = custList;
    _customersCount = custCount;
    _staffList = staff;
    _usersLoading = false;
    _usersError = null;
    notifyListeners();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _lastDeliveryDocs = [];

  static bool _isLegacyMockName(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'rajesh kumar' ||
        s == 'delivery agent mock';
  }

  static bool _isLegacyMockPhone(String? val) {
    if (val == null) return false;
    final digits = val.replaceAll(RegExp(r'\D'), '');
    return digits == '917777777777' ||
        digits == '7777777777' ||
        digits == '919876543210' ||
        digits == '9876543210' ||
        digits == '919876500000' ||
        digits == '9876500000' ||
        digits == '1234567890' ||
        digits == '911234567890';
  }

  static bool _isLegacyMockVehicle(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'electric delivery vehicle';
  }

  static bool _isLegacyMockVehicleNumber(String? val) {
    if (val == null) return false;
    final s = val.replaceAll(RegExp(r'\s'), '').toLowerCase();
    return s == 'up16de4412';
  }

  static bool _isLegacyMockZone(String? val) {
    if (val == null) return false;
    final s = val.trim().toLowerCase();
    return s == 'delivery zone' ||
        s == 'noida express zone';
  }

  void _rebuildRidersCombined() {
    final Map<String, Map<String, dynamic>> agentMap = {};

    // 1. Gather all docs from delivery_agents
    for (final doc in _lastDeliveryDocs) {
      final data = doc.data();
      final uid = (data['uid'] as String? ?? doc.id).trim();
      if (uid.isNotEmpty) {
        agentMap[uid] = Map<String, dynamic>.from(data);
      }
    }

    // 2. Merge all delivery users from users collection
    for (final doc in _lastUserDocs) {
      final data = doc.data();
      final role = (data['role'] as String? ?? '').trim().toLowerCase();
      if (role == 'delivery') {
        final uid =
            (data['id'] as String? ?? data['uid'] as String? ?? doc.id).trim();
        if (uid.isNotEmpty) {
          if (!agentMap.containsKey(uid)) {
            agentMap[uid] = Map<String, dynamic>.from(data);
          } else {
            final existing = agentMap[uid]!;
            data.forEach((key, value) {
              if (value != null &&
                  (!existing.containsKey(key) ||
                      existing[key] == null ||
                      existing[key] == '')) {
                existing[key] = value;
              }
            });

            // Prioritize real user fields if delivery_agents had empty or mock values
            final curName = (existing['name'] as String?)?.trim() ?? '';
            final uName = (data['name'] as String?)?.trim() ?? '';
            if ((curName.isEmpty || _isLegacyMockName(curName)) &&
                uName.isNotEmpty &&
                !_isLegacyMockName(uName) &&
                uName != 'Guest Customer') {
              existing['name'] = uName;
            }

            final curPhone = (existing['phone'] as String?)?.trim() ?? '';
            final uPhone = (data['phone'] as String?)?.trim() ?? '';
            if ((curPhone.isEmpty || _isLegacyMockPhone(curPhone)) &&
                uPhone.isNotEmpty &&
                !_isLegacyMockPhone(uPhone)) {
              existing['phone'] = uPhone;
            }

            final curImg = (existing['profileImageUrl'] ??
                existing['photoUrl'] ??
                existing['photoURL']) as String?;
            final uImg = (data['profileImageUrl'] ??
                data['photoUrl'] ??
                data['photoURL']) as String?;
            if ((curImg == null || curImg.trim().isEmpty) &&
                uImg != null &&
                uImg.trim().isNotEmpty) {
              existing['profileImageUrl'] = uImg.trim();
            }
          }
        }
      }
    }

    final List<DeliveryRider> ridersList = [];

    for (final entry in agentMap.entries) {
      final uid = entry.key;
      final data = entry.value;

      final rawName = (data['name'] as String?)?.trim() ?? '';
      final name =
          _isLegacyMockName(rawName) || rawName == 'Guest Customer' ? '' : rawName;

      final rawPhone = (data['phone'] as String?)?.trim() ?? '';
      final phone = _isLegacyMockPhone(rawPhone) ? '' : rawPhone;

      final email = (data['email'] as String? ?? '').trim();

      final rawVehicle =
          ((data['vehicle'] ?? data['vehicleType']) as String?)?.trim() ?? '';
      final vehicle = _isLegacyMockVehicle(rawVehicle) ? '' : rawVehicle;

      final rawVehicleNum = (data['vehicleNumber'] as String?)?.trim() ?? '';
      final vehicleNumber =
          _isLegacyMockVehicleNumber(rawVehicleNum) ? '' : rawVehicleNum;

      final rawZone =
          ((data['assignedZone'] ?? data['zone']) as String?)?.trim() ?? '';
      final assignedZone = _isLegacyMockZone(rawZone) ? '' : rawZone;

      final rawImage = ((data['profileImageUrl'] ??
              data['photoUrl'] ??
              data['photoURL']) as String?)
          ?.trim();
      final profileImageUrl =
          (rawImage != null && rawImage.isNotEmpty) ? rawImage : null;

      final rating = (data['rating'] as num?)?.toDouble();

      final isOnline = (data['isOnline'] as bool?) ??
          (data['isOnDuty'] as bool?) ??
          (data['status']?.toString().toLowerCase() == 'active');
      final status =
          isOnline ? 'Active' : (data['status'] as String? ?? 'Offline');

      final totalDeliveriesToday =
          (data['totalDeliveriesToday'] as num?)?.toInt() ??
              (data['completedDeliveries'] as num?)?.toInt() ??
              (data['totalDeliveries'] as num?)?.toInt() ??
              0;

      final pendingDeliveries = (data['pendingDeliveries'] as num?)?.toInt() ??
          ((data['orderId'] != null &&
                  (data['orderId'] as String).trim().isNotEmpty)
              ? 1
              : 0);

      final joinedDate = data['createdAt'] is Timestamp
          ? DateFormat('dd MMM yyyy')
              .format((data['createdAt'] as Timestamp).toDate())
          : (data['updatedAt'] is Timestamp
              ? DateFormat('dd MMM yyyy')
                  .format((data['updatedAt'] as Timestamp).toDate())
              : 'Active');

      ridersList.add(
        DeliveryRider(
          id: uid,
          name: name.isNotEmpty ? name : 'Delivery Partner',
          phone: phone,
          email: email,
          vehicle: vehicle,
          vehicleNumber: vehicleNumber,
          assignedZone: assignedZone,
          totalDeliveriesToday: totalDeliveriesToday,
          pendingDeliveries: pendingDeliveries,
          rating: rating,
          profileImageUrl: profileImageUrl,
          status: status,
          isOnline: isOnline,
          joinedDate: joinedDate,
        ),
      );
    }

    _riders = ridersList;
    _deliveryAgentsCount = ridersList.length;
    notifyListeners();
  }

  void _listenToUsers() {
    _usersSub =
        FirebaseFirestore.instance.collection('users').snapshots().listen(
      (snap) {
        _lastUserDocs = snap.docs;
        _rebuildCustomers();
        _rebuildRidersCombined();
      },
      onError: (e) {
        _usersError = 'Failed to load users: $e';
        _usersLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenToDeliveryAgents() {
    _deliveryAgentsSub = FirebaseFirestore.instance
        .collection('delivery_agents')
        .snapshots()
        .listen(
      (snap) {
        _lastDeliveryDocs = snap.docs;
        _rebuildRidersCombined();
      },
      onError: (e) {
        debugPrint('AdminProvider: delivery_agents stream error: $e');
      },
    );
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _ordersSub?.cancel();
    _complaintsSub?.cancel();
    _usersSub?.cancel();
    _deliveryAgentsSub?.cancel();
    super.dispose();
  }
}
