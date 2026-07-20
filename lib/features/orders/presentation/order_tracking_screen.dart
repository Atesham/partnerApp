import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'weighing_screen.dart';
import 'chat_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orders = OrderProvider();
  OrderModel? _order;
  // Named listener reference so we can safely remove it in dispose()
  late final VoidCallback _orderListener;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _orders.removeListener(_orderListener);
    super.dispose();
  }

  void _loadOrder() {
    // Define the listener as a named reference BEFORE attaching it, so
    // we can safely remove it in dispose() — fixes the anonymous-listener leak.
    _orderListener = () {
      if (!mounted) return;
      // Check all list types so the screen stays updated across all states
      final o = _findOrder();
      if (o != null) setState(() => _order = o);
    };

    // Attach listener FIRST, then start the stream so we never miss the
    // first emission (fixes the race condition / blank skeleton bug).
    _orders.addListener(_orderListener);

    // The singleton may already have data — do an immediate lookup.
    final existing = _findOrder();
    if (existing != null) setState(() => _order = existing);
  }

  /// Search across all order lists on the singleton so we find the order
  /// regardless of whether it's active, reserved, completed, or cancelled.
  OrderModel? _findOrder() {
    return [
      ..._orders.activeOrders,
      ..._orders.reservedOrders,
      ..._orders.completedOrders,
      ..._orders.cancelledOrders,
    ].where((o) => o.orderId == widget.orderId).firstOrNull;
  }

  Future<void> _updateStatus(OrderStatus status) async {
    if (_order == null) return;
    await _orders.updateOrderStatus(_order!.orderId, status);
  }

  Future<void> _callCustomer() async {
    if (_order == null) return;
    final uri = Uri.parse('tel:${_order!.customerPhone}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppTheme.showSnack(
          context,
          'Could not open phone dialer.',
          isError: true,
        );
      }
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final orderId = _order?.orderId ?? '';
    final message = Uri.encodeComponent(
      'Hello Scrapwell Support, I need help with my order${orderId.isNotEmpty ? ' #${orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase()}' : ''}.',
    );
    final uri = Uri.parse('https://wa.me/918744081962?text=$message');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppTheme.showSnack(
          context,
          'Could not open WhatsApp. Call +91 8744081962 for support.',
          isError: true,
        );
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_order == null) return;
    final lat = _order!.customerLat;
    final lng = _order!.customerLng;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppTheme.showSnack(
          context,
          'Could not open maps navigation.',
          isError: true,
        );
      }
    }
  }

  void _openChat() {
    if (_order == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(order: _order!)),
    );
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
        child: Column(
          children: [
            SkeletonBox(width: double.infinity, height: 240, radius: 20),
            const SizedBox(height: 16),
            SkeletonBox(width: double.infinity, height: 160, radius: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    return Column(
      children: [
        // Status header (Map removed for solid clean UI)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PulsingDot(color: AppTheme.primary, size: 7),
                            const SizedBox(width: 8),
                            Text(
                              order.statusDisplay,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.status == OrderStatus.partnerAssigned
                                  ? context.t('headToCustomer')
                                  : context.t('arrivingAtDest'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.customerAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
                () {
                  final isHindi =
                      Localizations.localeOf(context).languageCode == 'hi';
                  return Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                          Icons.call_rounded,
                          isHindi ? 'कॉल' : 'Call',
                          AppTheme.info,
                          _callCustomer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          Icons.navigation_rounded,
                          isHindi ? 'नेविगेट' : 'Navigate',
                          AppTheme.primary,
                          _startNavigation,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          Icons.chat_bubble_rounded,
                          isHindi ? 'चैट' : 'Chat',
                          const Color(0xFF10B981),
                          _openChat,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          Icons.support_agent_rounded,
                          isHindi ? 'सपोर्ट' : 'Support',
                          AppTheme.warning,
                          _openWhatsAppSupport,
                        ),
                      ),
                    ],
                  );
                }(),
                const SizedBox(height: 20),
                // Status CTA
                _buildStatusCTA(order),
                const SizedBox(height: 12),
                // Cancel Order Option
                if (order.status != OrderStatus.completed &&
                    order.status != OrderStatus.cancelled &&
                    order.status != OrderStatus.pickupStarted)
                  _buildCancelButton(order),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(OrderModel order) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.cancel_rounded, size: 18),
      label: Text(context.t('cancelPickup')),
      onPressed: () => _showCancellationDialog(order),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.error,
        side: const BorderSide(color: AppTheme.error, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showCancellationDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;
        final reasons = [
          context.t('cancelReasonVehicle'),
          context.t('cancelReasonCustomer'),
          context.t('cancelReasonNegotiation'),
          context.t('cancelReasonEmergency'),
          context.t('cancelReasonOther'),
        ];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.t('cancelPickup'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    reasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: AppTheme.error,
                        contentPadding: EdgeInsets.zero,
                        onChanged:
                            (val) => setDialogState(() => selectedReason = val),
                      );
                    }).toList(),
              ),
              actions: [
                TextButton(
                  child: Text(
                    context.t('goBack'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed:
                      selectedReason == null
                          ? null
                          : () async {
                            Navigator.pop(context); // close dialog
                            await _cancelOrder(order, selectedReason!);
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    context.t('confirmCancel'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelOrder(OrderModel order, String reason) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (order.status == OrderStatus.pickupStarted ||
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled) {
      AppTheme.showSnack(
        context,
        'This order cannot be cancelled after pickup has started.',
        isError: true,
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
    );

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final orderRef = db.collection('orders').doc(order.orderId);
      final partnerRef = db.collection('partners').doc(uid);
      final liveLocRef = db.collection('live_locations').doc(uid);
      final partnerCancelRef = db
          .collection('partners')
          .doc(uid)
          .collection('cancelled_orders')
          .doc(order.orderId);

      // 1. Release the order back to searchingPartner in Firestore
      //    CRITICAL: Also write declinedPartners.$uid so the same partner never
      //    sees this order again (unless the customer raises the tip).
      //    This is the Zepto/Zomato captain-app model: decline/cancel = blacklisted
      //    at this tip level, only re-notified if tip increases.
      batch.update(orderRef, {
        'status': OrderStatus.searchingPartner.name,
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'partnerId': null,
        'partnerName': null,
        'partnerPhone': null,
        'partnerShopName': null,
        'assignedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 2)),
        ),
        // Blacklist this partner at the current tip level:
        'declinedPartners.$uid': order.tipAmount,
      });

      // 2. Write the cancelled order to the partner's subcollection
      batch.set(partnerCancelRef, {
        'orderId': order.orderId,
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'customerAddress': order.customerAddress,
        'customerLat': order.customerLat,
        'customerLng': order.customerLng,
        'areaName': order.areaName,
        'estimatedPayout': order.estimatedPayout,
        'tipAmount': order.tipAmount,
        'pickupCharge': order.pickupCharge,
        'pickupType': order.pickupType,
        'pickupSlot': order.pickupSlot,
        'createdAt': Timestamp.fromDate(order.createdAt),
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'status': OrderStatus.cancelled.name,
      });

      // 3. Also remove this order from partner's reservedSlots in case it was
      //    a scheduled order that got accepted (partnerAssigned state).
      //    Read the current partner snapshot to compute updated cancellationRate
      //    so the profile section reflects the correct cancellation % in real-time.
      final partnerSnapForRate = await partnerRef.get();
      final partnerData = partnerSnapForRate.data() ?? {};
      final currentTotalOrders =
          ((partnerData['totalOrders'] ?? 0) as num).toInt();
      final currentCancelled =
          ((partnerData['totalCancelledOrders'] ?? 0) as num).toInt();
      final newCancelled = currentCancelled + 1;
      // cancellationRate = (cancelled / totalOrders) * 100, minimum denominator of 1 to avoid NaN
      final newCancellationRate =
          (newCancelled / (currentTotalOrders > 0 ? currentTotalOrders : 1)) *
          100.0;

      batch.update(partnerRef, {
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'totalCancelledOrders': FieldValue.increment(1),
        'cancellationRate': newCancellationRate,
      });

      // 4. Restore availability in live_locations so the partner immediately
      //    re-enters the instant pickup broadcast pool.
      batch.set(liveLocRef, {
        'isAvailable': true,
        'assignedOrderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Also remove from reservedSlots if this was a scheduled order
      //    (the partner may have had it in their calendar)
      try {
        final partnerSnap = await db.collection('partners').doc(uid).get();
        if (partnerSnap.exists) {
          final data = partnerSnap.data()!;
          final slots = (data['reservedSlots'] as List<dynamic>? ?? []);
          final updatedSlots =
              slots.where((s) {
                final slotMap = s as Map<dynamic, dynamic>;
                return slotMap['orderId']?.toString() != order.orderId;
              }).toList();
          if (updatedSlots.length != slots.length) {
            // Only update if slots actually changed
            await db.collection('partners').doc(uid).update({
              'reservedSlots': updatedSlots,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (_) {
        // Non-critical: best effort to clean up calendar
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        Navigator.pop(context); // Exit the tracking screen
        AppTheme.showSnack(context, 'Order cancelled successfully.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        AppTheme.showSnack(
          context,
          'Failed to cancel order: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildCustomerCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('customerDetails'),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  order.customerName.isNotEmpty
                      ? order.customerName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _callCustomer,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (order.pickupSlot.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  order.pickupSlot,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrapCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('scrapDetails'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Est. ₹${order.estimatedPayout.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          // Tip & Pickup Charge breakdown — only shown if either exists
          if (order.tipAmount > 0 || order.pickupCharge > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            // Tip row
            if (order.tipAmount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF047857)),
                        const SizedBox(width: 6),
                        const Text(
                          'Tip from Customer',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '+ ₹${order.tipAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            // Pickup Charge row
            if (order.pickupCharge > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bike_rounded, size: 14, color: Color(0xFF1E40AF)),
                        const SizedBox(width: 6),
                        const Text(
                          'Pickup Charge',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '+ ₹${order.pickupCharge.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
              ),
            // Total Est. Earning row
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Est. Earning',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                Text(
                  '₹${(order.estimatedPayout + order.tipAmount + order.pickupCharge).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.primary),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                order.scrapItems
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          if (order.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.t('scrapPhotos'),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: order.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: order.imageUrls[idx],
                                  fit: BoxFit.contain,
                                  placeholder:
                                      (context, url) => const Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) =>
                                          const Icon(Icons.error_outline),
                                ),
                              ),
                            ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CachedNetworkImage(
                          imageUrl: order.imageUrls[idx],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                width: 80,
                                height: 80,
                                color: AppTheme.border.withOpacity(0.3),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                color: AppTheme.border,
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (order.customerNotes != null &&
              order.customerNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 14,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerNotes!,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCTA(OrderModel order) {
    switch (order.status) {
      case OrderStatus.partnerAssigned:
        return GradientButton(
          label: context.t('startNavigation'),
          onPressed: () {
            _startNavigation();
            _updateStatus(OrderStatus.partnerArriving);
          },
          icon: Icons.navigation_rounded,
        );
      case OrderStatus.partnerArriving:
        return GradientButton(
          label: context.t('iArrived'),
          onPressed: () => _showOtpVerificationDialog(order),
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.pickupStarted:
        return GradientButton(
          label: context.t('startPickupWeighing'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WeighingScreen(order: order)),
            );
          },
          icon: Icons.scale_rounded,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showOtpVerificationDialog(OrderModel order) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.t('verifyPickupOtp'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('askCustomerOtp'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: const TextStyle(
                          color: AppTheme.border,
                          letterSpacing: 8,
                        ),
                        errorText: errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 4) {
                          return context.t('enterCode');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    context.t('cancel'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final enteredOtp = controller.text.trim();
                      if (enteredOtp == order.pickupOtp) {
                        Navigator.pop(context); // Close dialog
                        await _updateStatus(OrderStatus.pickupStarted);
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WeighingScreen(order: order),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          errorMessage = context.t('incorrectOtp');
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    context.t('verifyOtp'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
