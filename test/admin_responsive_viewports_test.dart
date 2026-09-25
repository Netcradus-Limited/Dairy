import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_app/core/constants/app_colors.dart';
import 'package:dairy_app/models/category_model.dart';
import 'package:dairy_app/models/complaint_model.dart';
import 'package:dairy_app/models/customer_model.dart';
import 'package:dairy_app/models/delivery_model.dart';
import 'package:dairy_app/models/delivery_staff_model.dart';
import 'package:dairy_app/models/order_model.dart';
import 'package:dairy_app/models/product_model.dart';
import 'package:dairy_app/models/subscription.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/models/kpi_data.dart';
import 'package:dairy_app/screens/categories/categories_screen.dart';
import 'package:dairy_app/screens/customers/customer_profile_screen.dart';
import 'package:dairy_app/screens/customers/customers_screen.dart';
import 'package:dairy_app/screens/dashboard/dashboard_screen.dart';
import 'package:dairy_app/screens/delivery/delivery_management_screen.dart';
import 'package:dairy_app/screens/delivery_staff/delivery_staff_screen.dart';
import 'package:dairy_app/screens/orders/orders_screen.dart';
import 'package:dairy_app/screens/payments/payments_screen.dart';
import 'package:dairy_app/screens/products/products_screen.dart';
import 'package:dairy_app/screens/staff/staff_roles_screen.dart';
import 'package:dairy_app/screens/support/support_screen.dart';
import 'package:dairy_app/services/customer_profile_service.dart';
import 'package:dairy_app/models/customer_delivery_record.dart';
import 'package:dairy_app/models/staff_member.dart';
import 'package:dairy_app/models/order.dart' hide OrderStatus;

class FakeCustomerProfileService extends CustomerProfileService {
  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) =>
      Stream.value([]);

  @override
  Stream<List<DairyPayment>> streamCustomerPayments(String customerId) =>
      Stream.value([]);

  @override
  Stream<Subscription?> streamCustomerSubscription(String customerId) =>
      Stream.value(null);

  @override
  Stream<List<DateTime>> streamSkippedDates(String customerId) =>
      Stream.value([]);

  @override
  Stream<List<CustomerDeliveryRecord>> streamDeliveryRecords(
          String customerId) =>
      Stream.value([]);
}

class FakeAdminProvider extends ChangeNotifier implements AdminProvider {
  @override
  bool get isLoading => false;

  @override
  List<DeliveryRider> get riders => const [
        DeliveryRider(
          id: 'RDR-001',
          name: 'Ramesh Kumar Delivery Rider',
          phone: '+91 9876543210',
          email: 'ramesh@sawariyadairy.com',
          vehicle: 'EV Delivery Bike',
          vehicleNumber: 'RJ 14 AB 1234',
          assignedZone: 'North Sector A',
          status: 'Active',
          isOnline: true,
          totalDeliveriesToday: 14,
          pendingDeliveries: 3,
          rating: 4.8,
          joinedDate: '01 Jan 2026',
        ),
        DeliveryRider(
          id: 'RDR-002',
          name: 'Suresh Verma',
          phone: '+91 9876543211',
          email: 'suresh@sawariyadairy.com',
          vehicle: 'Hero Electric Rickshaw',
          vehicleNumber: 'RJ 14 CD 5678',
          assignedZone: 'South Sector B',
          status: 'Active',
          isOnline: false,
          totalDeliveriesToday: 8,
          pendingDeliveries: 1,
          rating: 4.5,
          joinedDate: '15 Jan 2026',
        ),
      ];

  @override
  List<CustomerComplaint> get complaints => [
        CustomerComplaint(
          id: 'CMP-101',
          customerId: 'CUST-001',
          customerName: 'Aarav Sharma Resident',
          phone: '+91 9812345678',
          subject: 'Late morning milk delivery issue',
          issueType: 'Delivery',
          description:
              'The milk pouch delivery was delayed by 45 minutes today morning. Please check the route.',
          status: 'Open',
          priority: 'High',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          adminReply: 'Assigned to route supervisor',
        ),
        CustomerComplaint(
          id: 'CMP-102',
          customerId: 'CUST-002',
          customerName: 'Priya Mehta',
          phone: '+91 9823456789',
          subject: 'Packaging damaged on buffalo milk',
          issueType: 'Quality Concern',
          description:
              'One packet had a slight leak at the corner seal when received.',
          status: 'In Progress',
          priority: 'Medium',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          adminReply: 'Replacement dispatched',
        ),
      ];

  @override
  TodaysDeliveryProgress get todaysDeliveryProgress =>
      const TodaysDeliveryProgress(
        completed: 12,
        pending: 12,
        cancelled: 0,
        total: 24,
      );

  @override
  bool get todaysDeliveryProgressLoading => false;

  @override
  String? get todaysDeliveryProgressError => null;

  @override
  List<DairyOrder> get orders => const [
        DairyOrder(
          id: 'ORD-9801',
          customerName: 'Vikram Singh',
          customerPhone: '+91 9876543210',
          itemsSummary: '2x Fresh Cow Milk 1L',
          amount: 130.0,
          status: OrderStatus.confirmed,
          paymentMode: 'UPI / Online',
          deliverySlot: 'Morning (6:00 AM - 9:00 AM)',
          address: 'House 24, Lane 3, Vaishali Nagar, Jaipur',
          time: '06:15 AM',
          assignedAgentId: 'RDR-001',
          assignedAgentName: 'Ramesh Kumar',
        ),
      ];

  @override
  List<DairyCategory> get categories => const [
        DairyCategory(
          id: 'cat_milk',
          name: 'Fresh Milk & Creams',
          description: 'Pure farm fresh cow and buffalo milk',
          emoji: '🥛',
          icon: Icons.local_drink_outlined,
          color: AppColors.primary,
          imageUrl: 'assets/images/milk_category.png',
          productCount: 6,
          isActive: true,
          sortOrder: 1,
        ),
      ];

  @override
  List<DairyProduct> get products => const [
        DairyProduct(
          id: 'prod_001',
          name: 'Pure Desi Cow Milk 1L',
          subtitle: 'Farm fresh morning batch',
          category: 'Fresh Milk & Creams',
          unit: '1 Litre',
          price: 65.0,
          stockQuantity: 150,
          fatContent: '4.5% Fat',
          packaging: 'Fresh Pouch',
          emoji: '🥛',
          imageUrl: 'assets/images/doodh.png',
        ),
      ];

  @override
  List<DairyCustomer> get customers => const [
        DairyCustomer(
          id: 'CUST-001',
          name: 'Aarav Sharma Resident',
          phone: '+91 9812345678',
          email: 'aarav.sharma@example.com',
          address: 'Flat 402, Royal Palms, Vaishali Nagar, Jaipur',
          deliveryZone: 'North Sector A',
          subscriptionPlan: 'Daily 2L Cow Milk',
          milkPreference: 'Cow Milk',
          walletBalance: 1250.0,
          status: 'Active',
          joinedDate: '12 Jan 2026',
        ),
      ];

  @override
  DairyCustomer? get selectedCustomer => null;

  bool get customersLoading => false;
  String? get customersError => null;

  @override
  List<DeliveryCorridor> get corridors => const [
        DeliveryCorridor(
          id: 'COR-001',
          routeName: 'Indirapuram Morning Milk Route',
          zone: 'Indirapuram, Ghaziabad',
          vehicleType: 'Delivery Vehicle',
          riderName: 'Test Delivery Agent',
          agentId: 'RDR-001',
          timing: '05:00 AM - 07:00 AM',
          subscribersCount: 24,
          status: 'Active',
        ),
      ];

  @override
  bool get corridorsLoading => false;

  @override
  String? get corridorsError => null;

  @override
  List<DeliveryBatch> get deliveryBatches => const [
        DeliveryBatch(
          id: 'BATCH-001',
          deliveryId: '#DLV 5388',
          staffName: 'Test Delivery Agent',
          agentId: 'RDR-001',
          zone: 'Indirapuram, Ghaziabad',
          totalOrders: 6,
          completedOrders: 0,
          pendingOrders: 6,
          status: 'Pending',
        ),
      ];

  @override
  bool get deliveryBatchesLoading => false;

  @override
  String? get deliveryBatchesError => null;

  @override
  List<DairyPayment> get payments => const [
        DairyPayment(
          id: 'PAY-8921',
          orderOrWalletId: 'ORD-9801',
          orderId: 'ORD-9801',
          customerName: 'Vikram Singh Resident',
          customerPhone: '+91 9876543210',
          amount: 130.0,
          method: 'UPI / Online',
          status: 'Success',
          timestamp: '22 Sep 2026, 06:15 AM',
          transactionId: 'UPI/2026/89210041',
        ),
      ];

  @override
  bool get paymentsLoading => false;

  @override
  String? get paymentsError => null;

  @override
  List<Subscription> get subscriptions => [];

  @override
  bool get subscriptionsLoading => false;

  @override
  String? get subscriptionsError => null;

  @override
  bool get complaintsLoading => false;

  @override
  String? get complaintsError => null;

  @override
  bool get ordersLoading => false;

  @override
  String? get ordersError => null;

  bool get productsLoading => false;
  String? get productsError => null;
  bool get categoriesLoading => false;
  String? get categoriesError => null;
  bool get ridersLoading => false;
  String? get ridersError => null;

  @override
  bool get isDarkMode => false;

  @override
  String get searchQuery => '';

  @override
  String get orderStatusTimeFilter => 'Today';

  @override
  double get totalPaymentsAmount => 130.0;

  @override
  int get totalPaymentsCount => payments.length;

  @override
  int get successfulPaymentsCount =>
      payments.where((p) => p.status == 'Success').length;

  @override
  bool get usersLoading => false;

  @override
  String? get usersError => null;

  @override
  int get customersCount => 16;

  @override
  int get deliveryAgentsCount => riders.length;

  @override
  String? get error => null;

  @override
  int get totalOrdersCount => 45;

  @override
  int get pendingOrdersCount => 1;

  @override
  int get confirmedOrdersCount => 1;

  @override
  int get preparingOrdersCount => 0;

  @override
  int get outForDeliveryOrdersCount => 16;

  @override
  int get deliveredOrdersCount => 23;

  @override
  int get cancelledOrdersCount => 5;

  @override
  int get activeOrdersCount => 17;

  @override
  double get totalRevenue => 5611.0;

  @override
  double get totalOrderValue => 5611.0;

  @override
  List<DairyProduct> get topSellingProducts => products;

  @override
  int get pendingPaymentsCount => 0;

  @override
  int get failedPaymentsCount => 0;

  @override
  int get cancelledPaymentsCount => 0;

  @override
  List<KpiMetric> get kpiMetrics => const [
        KpiMetric(
          title: 'Total Revenue',
          value: '₹5,611',
          growthText: '23 orders delivered',
          isPositive: true,
          icon: Icons.currency_rupee_rounded,
          themeColor: AppColors.revenueGreen,
          themeBgColor: AppColors.revenueGreenBg,
        ),
        KpiMetric(
          title: 'Total Orders',
          value: '45',
          growthText: '1 pending, 17 active',
          isPositive: true,
          icon: Icons.shopping_bag_outlined,
          themeColor: AppColors.ordersBlue,
          themeBgColor: AppColors.ordersBlueBg,
        ),
        KpiMetric(
          title: 'Total Customers',
          value: '16',
          growthText: 'Registered customer base',
          isPositive: true,
          icon: Icons.people_outline_rounded,
          themeColor: AppColors.customersOrange,
          themeBgColor: AppColors.customersOrangeBg,
        ),
        KpiMetric(
          title: 'Delivery Fleet',
          value: '5',
          growthText: 'Active delivery agents',
          isPositive: true,
          icon: Icons.two_wheeler_rounded,
          themeColor: AppColors.primary,
          themeBgColor: AppColors.primaryLight,
        ),
      ];

  @override
  List<KpiMetric> get orderStatusKpis => const [
        KpiMetric(
          title: 'Active / Out For Delivery',
          value: '17',
          growthText: 'Dispatched & on route',
          isPositive: true,
          icon: Icons.delivery_dining_rounded,
          themeColor: AppColors.ordersBlue,
          themeBgColor: AppColors.ordersBlueBg,
        ),
        KpiMetric(
          title: 'Delivered Today',
          value: '23',
          growthText: 'Completed morning runs',
          isPositive: true,
          icon: Icons.check_circle_outline_rounded,
          themeColor: AppColors.revenueGreen,
          themeBgColor: AppColors.revenueGreenBg,
        ),
      ];

  @override
  List<StaffMember> get staffMembers => [
        const StaffMember(
          id: 'staff_admin_1',
          name: 'Primary Admin Master',
          email: 'admin@sawariyadairy.com',
          phone: '9999999999',
          role: 'admin',
          roleTitle: 'Super Admin',
          status: 'Active',
          permissions: [],
        ),
        StaffMember(
          id: 'staff_mgr_1',
          name: 'Operations Lead',
          email: 'ops@sawariyadairy.com',
          phone: '8888888888',
          role: 'manager',
          roleTitle: 'Operations Manager',
          status: 'Active',
          permissions: StaffRolePresets.managerPermissions,
        ),
      ];

  @override
  List<Map<String, String>> get staffList => const [
        {
          'name': 'Primary Admin Master',
          'email': 'admin@sawariyadairy.com',
          'role': 'Super Admin',
          'status': 'Active',
        }
      ];

  @override
  Future<void> toggleCategoryActive(String categoryId) async {}

  @override
  Future<void> addCategory(DairyCategory category) async {}

  @override
  Future<void> updateCategory(DairyCategory category) async {}

  @override
  Future<void> deleteCategory(String categoryId) async {}

  @override
  Future<void> addProduct(DairyProduct product) async {}

  @override
  Future<void> updateProduct(DairyProduct product) async {}

  @override
  Future<void> deleteProduct(String productId) async {}

  @override
  Future<void> toggleProductStock(String productId) async {}

  @override
  Future<void> assignDeliveryAgent(String orderId, String? agentId,
      {String? agentName}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final viewports = <String, Size>{
    'iPhone SE (320x568)': const Size(320, 568),
    'Small Android (360x800)': const Size(360, 800),
    'iPhone SE 2nd/3rd gen (375x667)': const Size(375, 667),
    'iPhone 12/13/14 (390x844)': const Size(390, 844),
    'Pixel / Galaxy (412x915)': const Size(412, 915),
    'Tablet Portrait (768x1024)': const Size(768, 1024),
    'Desktop Baseline (1366x768)': const Size(1366, 768),
  };

  group('Admin Responsive Viewport Layout Tests — No RenderFlex Overflows', () {
    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('DashboardScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: DashboardScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Dashboard Overview'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CustomersScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final originalOnError = FlutterError.onError;
        FlutterErrorDetails? caughtDetails;
        FlutterError.onError = (FlutterErrorDetails details) {
          caughtDetails = details;
          debugPrint('FLUTTER_ERROR_CAUGHT: ${details.exceptionAsString()}');
          debugPrint('CONTEXT: ${details.context?.toString()}');
          for (final line in details.summary.toString().split('\n')) {
            debugPrint('SUMMARY: $line');
          }
        };

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: CustomersScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        FlutterError.onError = originalOnError;

        expect(caughtDetails, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CustomerProfileScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();
        const testCustomer = DairyCustomer(
          id: '4QbBrQPMIKOv2JbmeJOAKzhm0Yy1',
          name: 'Sawariya Customer',
          phone: '7810880060',
          email: '4qbbrqpmikov2jbmejoakzhm0yy1@sawariyadairy.com',
          address: 'Noida, Uttar Pradesh',
          deliveryZone: 'Standard Zone',
          subscriptionPlan: 'Daily 2L Cow Milk',
          milkPreference: 'Cow Milk',
          walletBalance: 0.0,
          status: 'Active',
          joinedDate: '10 Sep 2026',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: MaterialApp(
              home: Scaffold(
                body: CustomerProfileScreen(
                  customer: testCustomer,
                  service: FakeCustomerProfileService(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Back to Customers'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('PaymentsScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: PaymentsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('StaffRolesScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: StaffRolesScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Staff & Role Permissions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('DeliveryStaffScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: DeliveryStaffScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Delivery Staff & Fleet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SupportScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: SupportScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Customer Support & Complaints'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'DeliveryManagementScreen dispatch card renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: DeliveryManagementScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Real-Time Dispatch Status'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('OrdersScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: OrdersScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Orders & Dispatch Management'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CategoriesScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: CategoriesScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Product Categories'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProductsScreen renders without overflow on $name',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeProvider = FakeAdminProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AdminProvider>.value(
            value: fakeProvider,
            child: const MaterialApp(
              home: Scaffold(
                body: ProductsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Dairy Products & Inventory'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'OrdersScreen Reassign Delivery Agent Dialog renders without overflow on 375x667',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeProvider = FakeAdminProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to open the Reassign dialog
      final reassignTrigger = find.text('Tap to reassign');
      if (reassignTrigger.evaluate().isNotEmpty) {
        await tester.tap(reassignTrigger.first);
        await tester.pumpAndSettle();

        expect(find.text('Reassign Delivery Agent'), findsOneWidget);
        expect(find.text('Confirm Reassignment'), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CategoriesScreen Add/Update Category Dialog renders without overflow on 375x667',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeProvider = FakeAdminProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: CategoriesScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final addCategoryBtn = find.byKey(const Key('add_category_button'));
      expect(addCategoryBtn, findsOneWidget);
      await tester.tap(addCategoryBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add New Category'), findsOneWidget);
      expect(find.text('Active Status'), findsOneWidget);
      expect(find.text('Create Category'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ProductsScreen Add Product Dialog renders without overflow on 375x667',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeProvider = FakeAdminProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AdminProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: ProductsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final addProductBtn = find.byKey(const Key('add_product_button'));
      expect(addProductBtn, findsOneWidget);
      await tester.tap(addProductBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Dairy Product'), findsOneWidget);
      expect(find.text('Product Image'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
