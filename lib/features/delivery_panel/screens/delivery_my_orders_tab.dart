import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';
import '../widgets/delivery_order_card.dart';
import 'delivery_order_detail_view.dart';

/// Screen 2 — My Orders Tab matching the reference design.
class DeliveryMyOrdersTab extends ConsumerStatefulWidget {
  const DeliveryMyOrdersTab({super.key});

  @override
  ConsumerState<DeliveryMyOrdersTab> createState() =>
      _DeliveryMyOrdersTabState();
}

class _DeliveryMyOrdersTabState extends ConsumerState<DeliveryMyOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DeliveryOrder? _activeDetailOrder;
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDetailOrder != null) {
      return DeliveryOrderDetailView(
        order: _activeDetailOrder!,
        onBack: () => setState(() => _activeDetailOrder = null),
      );
    }

    final activeOrders =
        ref.watch(deliveryActiveOrdersStreamProvider).asData?.value ?? [];
    final requests = ref.watch(deliveryRequestsStreamProvider);
    final historyAsync = ref.watch(deliveryHistoryStreamProvider);
    final historyOrders = historyAsync.asData?.value ?? [];

    // Filter into 3 buckets
    final now = DateTime.now();

    // 1. Today: All active + requests + today's history
    final todayHistoryOrders = historyOrders.where((o) {
      final dt = o.deliveredTime ?? o.orderTime;
      return dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
    }).toList();

    final todayOrders = [
      ...activeOrders,
      ...requests,
      ...todayHistoryOrders,
    ];

    // 2. In Progress: Pickup + Out for Delivery
    final inProgressOrders = activeOrders
        .where((o) =>
            o.status == DeliveryOrderStatus.pickup ||
            o.status == DeliveryOrderStatus.outForDelivery)
        .toList();

    // 3. Completed: Delivered history
    final completedOrders = historyOrders
        .where((o) => o.status == DeliveryOrderStatus.delivered)
        .toList();

    // Filter by search query if search is active
    final query = _searchController.text.trim().toLowerCase();
    List<DeliveryOrder> filterList(List<DeliveryOrder> list) {
      if (query.isEmpty) return list;
      return list.where((o) {
        return o.customerName.toLowerCase().contains(query) ||
            o.customerAddress.toLowerCase().contains(query) ||
            o.displayCode.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Header with tabs underneath
          DeliveryStandardHeader(
            title: 'My Orders',
            leading: IconButton(
              onPressed: () {
                Scaffold.maybeOf(context)?.openDrawer();
              },
              icon: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 24),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchActive = !_isSearchActive;
                    if (!_isSearchActive) _searchController.clear();
                  });
                },
                icon: Icon(
                  _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
            bottomRadius: 0,
          ),

          // Search Field if opened
          if (_isSearchActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by customer, address, or order code...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: DeliveryTheme.textMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: DeliveryTheme.primary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F8F1),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Tab Bar matching reference image with green indicator
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: DeliveryTheme.primary,
              indicatorWeight: 3.0,
              labelColor: DeliveryTheme.primaryDark,
              unselectedLabelColor: DeliveryTheme.textSecondary,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'Today (${todayOrders.length})'),
                Tab(text: 'In Progress (${inProgressOrders.length})'),
                Tab(text: 'Completed (${completedOrders.length})'),
              ],
            ),
          ),

          // TabBarView displaying filtered order lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderListView(filterList(todayOrders)),
                _buildOrderListView(filterList(inProgressOrders)),
                _buildOrderListView(filterList(completedOrders)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListView(List<DeliveryOrder> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 40,
                  color: DeliveryTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No orders in this category',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DeliveryTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: DeliveryTheme.primary,
      onRefresh: () async {
        ref.invalidate(deliveryActiveOrdersStreamProvider);
        ref.invalidate(deliveryRequestsStreamProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return DeliveryOrderCard(
            order: order,
            showItemsCount: true,
            onTap: () {
              setState(() => _activeDetailOrder = order);
            },
          );
        },
      ),
    );
  }
}
