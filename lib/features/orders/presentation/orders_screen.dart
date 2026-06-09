import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final _orders = OrderProvider();
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // DO NOT call _orders.listenToOrders() here — OrderProvider is a singleton
    // and its stream is already started (and shared) by HomeScreen.initState().
    // Re-calling it here would cancel + recreate the subscription, potentially
    // dropping in-flight Firestore events.
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppTheme.background,
            child: TabBar(
              controller: _tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _orders,
        builder: (_, __) => TabBarView(
          controller: _tab,
          children: [
            // Active tab shows both currently-active AND upcoming reserved orders
            _OrderList(
              orders: [..._orders.reservedOrders, ..._orders.activeOrders],
              emptyMsg: 'No active or scheduled orders',
            ),
            _OrderList(orders: _orders.completedOrders, emptyMsg: 'No completed orders yet'),
            _OrderList(orders: _orders.cancelledOrders, emptyMsg: 'No cancelled orders'),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMsg;
  const _OrderList({required this.orders, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inventory_2_outlined, size: 52, color: AppTheme.textHint),
          const SizedBox(height: 14),
          Text(emptyMsg, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    // Reserved/scheduled orders get an amber accent so they stand out
    final statusColor = order.status == OrderStatus.completed
        ? AppTheme.success
        : order.status == OrderStatus.cancelled
            ? AppTheme.error
            : order.status == OrderStatus.reserved
                ? const Color(0xFFEA580C) // orange for scheduled
                : AppTheme.primary;

    // Allow navigation for both active AND reserved orders
    final isNavigable = order.isActive || order.status == OrderStatus.reserved;

    return GestureDetector(
      onTap: isNavigable
          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.orderId)))
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.customerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(order.areaName, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(order.statusDisplay, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.completedAt != null
                        ? _formatDate(order.completedAt!)
                        : _formatDate(order.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Row(children: [
                  const Icon(Icons.recycling_rounded, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.categoryList, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
                Text(
                  order.status == OrderStatus.completed
                      ? '₹${order.finalPayout.toStringAsFixed(0)}'
                      : '~₹${order.estimatedPayout.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
