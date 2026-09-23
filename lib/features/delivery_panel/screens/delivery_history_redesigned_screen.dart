import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/delivery_boy_model.dart';
import '../../../providers/delivery_provider.dart';
import '../theme/delivery_theme.dart';
import '../widgets/delivery_header.dart';
import '../widgets/delivery_order_card.dart';

/// Screen 7 — Delivery History Screen matching the reference design.
class DeliveryHistoryRedesignedScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryRedesignedScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryRedesignedScreen> createState() =>
      _DeliveryHistoryRedesignedScreenState();
}

class _DeliveryHistoryRedesignedScreenState
    extends ConsumerState<DeliveryHistoryRedesignedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(deliveryHistoryStreamProvider);
    final historyOrders = historyAsync.asData?.value ?? [];

    final allOrders = historyOrders;
    final deliveredOrders = allOrders
        .where((o) => o.status == DeliveryOrderStatus.delivered)
        .toList();
    final cancelledOrders = allOrders
        .where((o) => o.status == DeliveryOrderStatus.cancelled)
        .toList();

    return Scaffold(
      backgroundColor: DeliveryTheme.background,
      body: Column(
        children: [
          // Header matching Screen 7
          DeliveryStandardHeader(
            title: 'Delivery History',
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            bottomRadius: 0,
          ),

          // Tabs: All | Delivered | Cancelled
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
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Delivered'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(allOrders),
                _buildHistoryList(deliveredOrders),
                _buildHistoryList(cancelledOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<DeliveryOrder> orders) {
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
                  Icons.history_rounded,
                  size: 40,
                  color: DeliveryTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No delivery history found',
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return DeliveryOrderCard(
          order: order,
          showItemsCount: false,
          showDate: true,
          onTap: () {
            // Optional: view order details modal
          },
        );
      },
    );
  }
}
