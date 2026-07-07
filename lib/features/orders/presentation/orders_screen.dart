import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/l10n/app_localizations.dart';
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
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(context.t('myOrders'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
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
              tabs: [
                Tab(text: context.t('active')),
                Tab(text: context.t('completed')),
                Tab(text: context.t('cancelled')),
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
              emptyMsg: context.t('noActiveOrders'),
            ),
            _OrderList(orders: _orders.completedOrders, emptyMsg: context.t('noCompletedOrders')),
            _OrderList(orders: _orders.cancelledOrders, emptyMsg: context.t('noCancelledOrders')),
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

    // Allow navigation for active/reserved (→ tracking) or completed/cancelled (→ detail)
    final canNavigate = order.isActive || order.status == OrderStatus.reserved
        || order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;

    void onTap() {
      if (order.isActive || order.status == OrderStatus.reserved) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.orderId)));
      } else if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
      }
    }

    return GestureDetector(
      onTap: canNavigate ? onTap : null,
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
                Row(children: [
                  Text(
                    order.status == OrderStatus.completed
                        ? '₹${order.finalPayout.toStringAsFixed(0)}'
                        : '~₹${order.estimatedPayout.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
                  if (canNavigate) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: statusColor, size: 20),
                  ],
                ]),
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

// ─────────────────────────────────────────────────────────
// ORDER DETAIL SCREEN — Full billing for completed/cancelled
// ─────────────────────────────────────────────────────────

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final commission = order.finalPayout * 0.02;
    final paidToCustomer = order.finalPayout - commission;
    final shortId = order.orderId.length > 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase();
    final isCompleted = order.status == OrderStatus.completed;
    final dateLabel = order.completedAt != null
        ? _fmtFull(order.completedAt!)
        : _fmtFull(order.createdAt);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.t('orderBillingDetail'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [const Color(0xFF064E3B), const Color(0xFF059669)]
                      : [const Color(0xFF7F1D1D), const Color(0xFFDC2626)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(
                    isCompleted ? Icons.receipt_long_rounded : Icons.cancel_outlined,
                    color: Colors.white, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  isCompleted ? context.t('pickupComplete') : context.t('cancelled'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(dateLabel, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('Order #$shortId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // Scrap breakdown
            _sectionCard(
              icon: Icons.recycling_rounded,
              title: context.t('scrapBreakdown'),
              child: Column(
                children: order.scrapItems.isEmpty
                    ? [Text(context.t('noScrapItems'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))]
                    : order.scrapItems.asMap().entries.map((e) {
                        final item = e.value;
                        final subtotal = item.actualWeight * (item.estimatedRate > 0 ? item.estimatedRate : item.actualRate);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.recycling_rounded, color: AppTheme.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.actualWeight.toStringAsFixed(1)} kg × ₹${(item.estimatedRate > 0 ? item.estimatedRate : item.actualRate).toStringAsFixed(0)}/kg',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ])),
                              Text('₹${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),

            if (isCompleted) ...[
              const SizedBox(height: 14),

              // Payment summary card (gradient)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF059669)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(context.t('paymentSummary'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  _billingRow(context.t('totalPayout'), '₹${order.finalPayout.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _billingRow(context.t('commissionLabel'), '− ₹${commission.toStringAsFixed(0)}', valueColor: Colors.orange.shade200),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.white24)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(context.t('paidToCustomer'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('₹${paidToCustomer.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(context.t('yourEarnings'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('₹${(order.finalPayout - commission).toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 14),

            // Pickup details
            _sectionCard(
              icon: Icons.info_outline_rounded,
              title: context.t('pickupDetails'),
              child: Column(children: [
                if (order.customerAddress.isNotEmpty)
                  _infoRow(Icons.location_on_rounded, 'Address', order.customerAddress),
                if (order.customerName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.person_rounded, 'Customer', order.customerName),
                ],
                if (order.pickupSlot.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.schedule_rounded, context.t('pickupSlot'), order.pickupSlot),
                ],
                if (order.completedAt != null) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.check_circle_rounded, context.t('completedOn'), _fmtFull(order.completedAt!)),
                ],
                if (!isCompleted && order.cancellationReason != null) ...[
                  const SizedBox(height: 10),
                  _infoRow(Icons.cancel_outlined, 'Reason', order.cancellationReason!),
                ],
              ]),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  static Widget _infoRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppTheme.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }

  static Widget _billingRow(String label, String value, {Color? valueColor}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }

  static String _fmtFull(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${hour.toString().padLeft(2, '0')}:$min $ampm';
  }
}
