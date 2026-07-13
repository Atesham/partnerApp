import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hourStr:$minuteStr $period';
  }
}

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  static String _fmtTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr $period';
  }

  static String _fmtFull(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final timeStr = _fmtTime(dt);
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isYesterday = dt.year == now.year && dt.month == now.month && dt.day == now.day - 1;
    
    final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    if (isToday) {
      return 'Today, $dateStr • $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $dateStr • $timeStr';
    } else {
      return '$dateStr • $timeStr';
    }
  }

  Future<void> _makeCall(String phone) async {
    final phoneUri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openMap(double lat, double lng, String name) async {
    final mapUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri);
    }
  }

  Future<void> _openHelpSupport(BuildContext context) async {
    final message = Uri.encodeComponent(
      'Hello Scrapwell support, I need help regarding Order #${order.orderId.substring(0, 8).toUpperCase()}.',
    );
    final uri = Uri.parse('https://wa.me/918744081962?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commission = order.finalPayout * 0.02;
    final paidToCustomer = order.finalPayout - commission;
    final isCompleted = order.status == OrderStatus.completed;
    final accentColor = isCompleted ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final lightBgColor = isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFEE2E2);
    final shortId = order.orderId.length > 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase();
    final dateLabel = order.completedAt != null
        ? _fmtFull(order.completedAt!)
        : _fmtFull(order.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Order Details',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Status Banner ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCompleted ? 'Completed' : 'Cancelled',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCompleted ? 'Pickup completed successfully' : 'This order was cancelled',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Banner Illustration
                    Image.asset(
                      isCompleted ? 'assets/images/completed_billing.png' : 'assets/images/cancelled_billing.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Metadata Card ──────────────────────────
              _buildCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ID',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#$shortId',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lightBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.pickupType == 'scheduled' ? 'Scheduled Pickup' : 'Instant Pickup',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date & Time',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateLabel,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Payment',
                              style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Online',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Customer Details Card ──────────────────
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Customer Details',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, color: AppTheme.textSecondary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    order.customerPhone,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Call button
                        GestureDetector(
                          onTap: () => _makeCall(order.customerPhone),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Icon(Icons.phone_enabled_rounded, color: Color(0xFF059669), size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded, color: accentColor, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerAddress,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _openMap(order.customerLat, order.customerLng, order.customerName),
                                child: Text(
                                  'View on Map',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: accentColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 4. Pickup Items Card ──────────────────────
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_mall_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Pickup Items',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: order.scrapItems.isEmpty
                          ? [
                              Text(
                                'No scrap materials listed',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              )
                            ]
                          : order.scrapItems.asMap().entries.map((e) {
                              final item = e.value;
                              final rate = item.estimatedRate > 0 ? item.estimatedRate : item.actualRate;
                              final subtotal = item.actualWeight * rate;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.category,
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Rate: ₹${rate.toStringAsFixed(0)}/kg',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.actualWeight.toStringAsFixed(1)} kg',
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${subtotal.toStringAsFixed(0)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '₹${(isCompleted ? order.finalPayout : order.estimatedPayout).toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 5. Cancellation Details Card (Only if cancelled) ──
              if (!isCompleted && order.cancellationReason != null) ...[
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Cancellation Details',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _timelineDetailRow('Cancelled by', order.reservedPartnerId == null ? 'Customer' : 'You'),
                      const SizedBox(height: 10),
                      _timelineDetailRow('Reason', order.cancellationReason ?? 'Not specified'),
                      const SizedBox(height: 10),
                      _timelineDetailRow(
                        'Cancelled at',
                        _fmtTime(order.cancelledAt ?? order.completedAt ?? order.createdAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── 6. Order Timeline Card ────────────────────
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.adjust_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Order Timeline',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTimeline(context),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 7. Earnings / Loss Card ───────────────────
              if (isCompleted)
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Earnings',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _timelineDetailRow('Item Amount', '₹${order.finalPayout.toStringAsFixed(0)}'),
                      const SizedBox(height: 10),
                      _timelineDetailRow('Platform Fee', '− ₹${commission.toStringAsFixed(0)} (2%)', valueColor: const Color(0xFFD97706)),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'You Earned',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${paidToCustomer.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: lightBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.18), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Total Loss',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This order se aapko koi earning nahi hui.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${order.estimatedPayout.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ── 8. Help & Support CTA Button ──────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openHelpSupport(context),
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isCompleted ? Colors.white : accentColor),
                  label: Text(
                    'Help / Support',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isCompleted ? Colors.white : accentColor,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? const Color(0xFF059669) : const Color(0xFFFCA5A5).withOpacity(0.3),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _timelineDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final steps = <_TimelineStep>[];
    final isCompleted = order.status == OrderStatus.completed;

    steps.add(_TimelineStep(
      title: 'Order received',
      time: _fmtTime(order.createdAt),
      isCompleted: true,
    ));

    if (order.assignedAt != null) {
      steps.add(_TimelineStep(
        title: 'You accepted the order',
        time: _fmtTime(order.assignedAt!),
        isCompleted: true,
      ));
    }

    if (order.partnerArrivedAt != null) {
      steps.add(_TimelineStep(
        title: 'Reached at customer',
        time: _fmtTime(order.partnerArrivedAt!),
        isCompleted: true,
      ));
    } else if (order.assignedAt != null && isCompleted) {
      steps.add(_TimelineStep(
        title: 'Reached at customer',
        time: _fmtTime(order.assignedAt!.add(const Duration(minutes: 10))),
        isCompleted: true,
      ));
    }

    if (isCompleted) {
      steps.add(_TimelineStep(
        title: 'Pickup completed',
        time: _fmtTime(order.completedAt ?? order.createdAt.add(const Duration(hours: 1))),
        isCompleted: true,
      ));
      steps.add(_TimelineStep(
        title: 'Payment received',
        time: _fmtTime(order.completedAt ?? order.createdAt.add(const Duration(hours: 1, minutes: 2))),
        isCompleted: true,
      ));
    } else {
      steps.add(_TimelineStep(
        title: 'Cancelled',
        time: _fmtTime(order.cancelledAt ?? order.completedAt ?? order.createdAt),
        isCompleted: true,
        isCancelled: true,
      ));
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final bulletColor = step.isCancelled ? const Color(0xFFDC2626) : const Color(0xFF059669);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: bulletColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      step.isCancelled ? Icons.close_rounded : Icons.check_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 38,
                    color: bulletColor.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.time,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineStep {
  final String title;
  final String time;
  final bool isCompleted;
  final bool isCancelled;
  const _TimelineStep({
    required this.title,
    required this.time,
    this.isCompleted = false,
    this.isCancelled = false,
  });
}
