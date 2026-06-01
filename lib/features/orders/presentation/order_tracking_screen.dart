import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'weighing_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orders = OrderProvider();
  OrderModel? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    _orders.listenToOrders();
    _orders.addListener(() {
      if (mounted) {
        final o = _orders.activeOrders
            .where((o) => o.orderId == widget.orderId)
            .firstOrNull;
        if (o != null) setState(() => _order = o);
      }
    });
    final o = _orders.activeOrders
        .where((o) => o.orderId == widget.orderId)
        .firstOrNull;
    if (o != null) setState(() => _order = o);
  }

  Future<void> _updateStatus(OrderStatus status) async {
    if (_order == null) return;
    await _orders.updateOrderStatus(_order!.orderId, status);
  }

  Future<void> _callCustomer() async {
    if (_order == null) return;
    final uri = Uri.parse('tel:${_order!.customerPhone}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _startNavigation() async {
    if (_order == null) return;
    final lat = _order!.customerLat;
    final lng = _order!.customerLng;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _order == null ? _buildSkeleton() : _buildContent(),
    );
  }

  Widget _buildSkeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          SkeletonBox(width: double.infinity, height: 240, radius: 20),
          const SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 160, radius: 16),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    return Column(
      children: [
        // Map area (placeholder — activate with real Google Maps key)
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.map_rounded, size: 56, color: Colors.white54),
                  const SizedBox(height: 8),
                  Text(order.customerAddress,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.subtleShadow),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.textPrimary),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          PulsingDot(color: AppTheme.primary, size: 7),
                          const SizedBox(width: 8),
                          Text(order.statusDisplay,
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer info
                _buildCustomerCard(order),
                const SizedBox(height: 14),
                // Scrap details
                _buildScrapCard(order),
                const SizedBox(height: 14),
                // Quick actions
                Row(children: [
                  Expanded(child: _actionBtn(Icons.call_rounded, 'Call', AppTheme.info, _callCustomer)),
                  const SizedBox(width: 10),
                  Expanded(child: _actionBtn(Icons.navigation_rounded, 'Navigate', AppTheme.primary, _startNavigation)),
                  const SizedBox(width: 10),
                  Expanded(child: _actionBtn(Icons.chat_rounded, 'Support', AppTheme.warning, () {})),
                ]),
                const SizedBox(height: 20),
                // Status CTA
                _buildStatusCTA(order),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Details', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryLight,
              child: Text(order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : 'C',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(order.customerAddress, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: _callCustomer,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.call_rounded, color: AppTheme.primary, size: 20),
              ),
            ),
          ]),
          if (order.pickupSlot.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(order.pickupSlot, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildScrapCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Scrap Details', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            Text('Est. ₹${order.estimatedPayout.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: order.scrapItems.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Text(item.category, style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600, fontSize: 13)),
            )).toList(),
          ),
          if (order.customerNotes != null && order.customerNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.notes_rounded, size: 14, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(child: Text(order.customerNotes!,
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildStatusCTA(OrderModel order) {
    switch (order.status) {
      case OrderStatus.partnerAssigned:
        return GradientButton(
          label: 'Start Navigation',
          onPressed: () {
            _startNavigation();
            _updateStatus(OrderStatus.partnerArriving);
          },
          icon: Icons.navigation_rounded,
        );
      case OrderStatus.partnerArriving:
        return GradientButton(
          label: "I've Arrived",
          onPressed: () => _updateStatus(OrderStatus.pickupStarted),
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.pickupStarted:
        return GradientButton(
          label: 'Start Pickup & Weighing',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeighingScreen(order: order),
              ),
            );
          },
          icon: Icons.scale_rounded,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
