import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dairy_app/models/payment_model.dart';
import 'package:dairy_app/providers/admin_provider.dart';
import 'package:dairy_app/screens/payments/payments_screen.dart';

class MockAdminPaymentsProvider extends ChangeNotifier implements AdminProvider {
  List<DairyPayment> _mockPayments = [];
  bool _mockLoading = false;
  String? _mockError;
  String? lastUpdatedPaymentId;
  String? lastUpdatedStatus;

  @override
  List<DairyPayment> get payments => _mockPayments;

  @override
  bool get paymentsLoading => _mockLoading;

  @override
  String? get paymentsError => _mockError;

  @override
  double get totalPaymentsAmount => _mockPayments
      .where((p) => p.status == 'Success')
      .fold(0.0, (sum, p) => sum + p.amount);

  @override
  int get successfulPaymentsCount =>
      _mockPayments.where((p) => p.status == 'Success').length;

  @override
  int get pendingPaymentsCount =>
      _mockPayments.where((p) => p.status == 'Pending').length;

  @override
  int get totalPaymentsCount => _mockPayments.length;

  void setMockPayments(List<DairyPayment> list) {
    _mockPayments = list;
    _mockLoading = false;
    _mockError = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _mockLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _mockError = error;
    _mockLoading = false;
    notifyListeners();
  }

  @override
  Future<void> updatePaymentStatus(
    String paymentId,
    String status, {
    String? transactionId,
  }) async {
    lastUpdatedPaymentId = paymentId;
    lastUpdatedStatus = status;
    final idx = _mockPayments.indexWhere((p) => p.id == paymentId);
    if (idx != -1) {
      _mockPayments[idx] = _mockPayments[idx].copyWith(
        status: status,
        transactionId: transactionId ?? _mockPayments[idx].transactionId,
      );
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final samplePayments = [
    DairyPayment(
      id: 'PAY_ORD_001',
      customerName: 'Ananya Sharma',
      customerPhone: '+91 98765 11111',
      orderId: 'ORD_001',
      orderCode: 'SWD001',
      orderOrWalletId: '#SWD001',
      amount: 450.0,
      method: 'Online (UPI)',
      status: 'Success',
      transactionId: 'TXN_UPI_1001',
      timestamp: 'Today, 08:30 AM',
      createdAt: DateTime.now(),
    ),
    DairyPayment(
      id: 'PAY_ORD_002',
      customerName: 'Vikram Mehta',
      customerPhone: '+91 98765 22222',
      orderId: 'ORD_002',
      orderCode: 'SWD002',
      orderOrWalletId: '#SWD002',
      amount: 280.0,
      method: 'Cash on Delivery',
      status: 'Pending',
      transactionId: null,
      timestamp: 'Today, 09:15 AM',
      createdAt: DateTime.now(),
    ),
    DairyPayment(
      id: 'PAY_ORD_003',
      customerName: 'Rohan Gupta',
      customerPhone: '+91 98765 33333',
      orderId: 'ORD_003',
      orderCode: 'SWD003',
      orderOrWalletId: '#SWD003',
      amount: 150.0,
      method: 'Prepaid Wallet',
      status: 'Failed',
      transactionId: 'TXN_WAL_9901',
      timestamp: 'Yesterday, 04:00 PM',
      createdAt: DateTime.now(),
    ),
  ];

  Widget createPaymentsScreenTestWidget(MockAdminPaymentsProvider provider) {
    return ChangeNotifierProvider<AdminProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(
          body: PaymentsScreen(),
        ),
      ),
    );
  }

  group('Admin Payments Screen Tests', () {
    testWidgets('PaymentsScreen renders Header, KPIs, FilterBar and Loaded Payment records',
        (WidgetTester tester) async {
      final mockProvider = MockAdminPaymentsProvider()
        ..setMockPayments(samplePayments);

      await tester.pumpWidget(createPaymentsScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Payments & Collections'), findsOneWidget);

      // KPI cards verification
      expect(find.text('Total Collections'), findsOneWidget);
      expect(find.text('₹450'), findsWidgets);
      expect(find.text('Successful Payments'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Pending Collections'), findsOneWidget);
      expect(find.text('Total Transactions'), findsOneWidget);
      expect(find.text('3'), findsWidgets);

      // Filter and Search field
      expect(find.byType(TextField), findsOneWidget);

      // Payment records rendered
      expect(find.text('Ananya Sharma'), findsWidgets);
      expect(find.text('Vikram Mehta'), findsWidgets);
      expect(find.text('Rohan Gupta'), findsWidgets);
      expect(find.textContaining('#SWD001'), findsWidgets);
      expect(find.textContaining('Online (UPI)'), findsWidgets);
      expect(find.textContaining('Cash on Delivery'), findsWidgets);
    });

    testWidgets('PaymentsScreen renders empty state when no payments are found',
        (WidgetTester tester) async {
      final mockProvider = MockAdminPaymentsProvider()..setMockPayments([]);

      await tester.pumpWidget(createPaymentsScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(find.text('No payments recorded in Firestore yet.'), findsOneWidget);
    });

    testWidgets('PaymentsScreen renders error state when Firestore stream fails',
        (WidgetTester tester) async {
      final mockProvider = MockAdminPaymentsProvider()
        ..setError('Firestore permission-denied: insufficient permissions');

      await tester.pumpWidget(createPaymentsScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      expect(
        find.text('Firestore permission-denied: insufficient permissions'),
        findsOneWidget,
      );
    });

    testWidgets('Search query filters payments list dynamically',
        (WidgetTester tester) async {
      final mockProvider = MockAdminPaymentsProvider()
        ..setMockPayments(samplePayments);

      await tester.pumpWidget(createPaymentsScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Enter search term "Vikram"
      await tester.enterText(find.byType(TextField), 'Vikram');
      await tester.pumpAndSettle();

      expect(find.text('Vikram Mehta'), findsWidgets);
      expect(find.text('Ananya Sharma'), findsNothing);
      expect(find.text('Rohan Gupta'), findsNothing);
    });

    testWidgets('Status filter filters payments by Pending status',
        (WidgetTester tester) async {
      final mockProvider = MockAdminPaymentsProvider()
        ..setMockPayments(samplePayments);

      await tester.pumpWidget(createPaymentsScreenTestWidget(mockProvider));
      await tester.pumpAndSettle();

      // Find status dropdown and tap
      final statusDropdownFinder = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton<String> &&
            widget.items?.any((item) => item.value == 'Pending') == true,
      );
      expect(statusDropdownFinder, findsOneWidget);

      await tester.tap(statusDropdownFinder);
      await tester.pumpAndSettle();

      // Tap 'Pending' menuItem
      await tester.tap(find.text('Pending').last);
      await tester.pumpAndSettle();

      expect(find.text('Vikram Mehta'), findsWidgets);
      expect(find.text('Ananya Sharma'), findsNothing);
    });
  });
}
