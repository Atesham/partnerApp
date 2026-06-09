import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
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
        AppTheme.showSnack(context, 'Could not open phone dialer.', isError: true);
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_order == null) return;
    final lat = _order!.customerLat;
    final lng = _order!.customerLng;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppTheme.showSnack(context, 'Could not open maps navigation.', isError: true);
      }
    }
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
        // Status header (Map removed for solid clean UI)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.status == OrderStatus.partnerAssigned
                                  ? 'Head to Customer Location'
                                  : 'Arriving at Customer Destination',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.customerAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, fontWeight: FontWeight.w500),
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
          'Vehicle breakdown',
          'Customer unavailable / not responding',
          'Negotiation failed / incorrect rate selection',
          'Emergency / Personal reasons',
          'Other',
        ];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(context.t('cancelPickup'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: reasons.map((reason) {
                  return RadioListTile<String>(
                    title: Text(reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    value: reason,
                    groupValue: selectedReason,
                    activeColor: AppTheme.error,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => selectedReason = val),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  child: Text(context.t('goBack'), style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          Navigator.pop(context); // close dialog
                          await _cancelOrder(order, selectedReason!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(context.t('confirmCancel'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
      AppTheme.showSnack(context, 'This order cannot be cancelled after pickup has started.', isError: true);
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final orderRef = db.collection('orders').doc(order.orderId);
      final partnerRef = db.collection('partners').doc(uid);
      final liveLocRef = db.collection('live_locations').doc(uid);

      // 1. Release the order back to searchingPartner in Firestore
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
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 2))),
      });

      // 2. Mark the partner as available in partners collection
      batch.update(partnerRef, {
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. CRITICAL: Also restore availability in live_locations so the partner
      //    immediately re-enters the instant pickup broadcast pool.
      //    Without this, the partner stays "on another order" indefinitely.
      batch.set(
        liveLocRef,
        {
          'isAvailable': true,
          'assignedOrderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        Navigator.pop(context); // Exit the tracking screen
        AppTheme.showSnack(context, 'Order cancelled successfully.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        AppTheme.showSnack(context, 'Failed to cancel order: $e', isError: true);
      }
    }
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
          if (order.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Scrap Photos', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              order.imageUrls[idx],
                              fit: BoxFit.contain,
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
                        child: Image.network(
                          order.imageUrls[idx],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.border,
                            child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
          onPressed: () => _showOtpVerificationDialog(order),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(context.t('verifyPickupOtp'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('askCustomerOtp'),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: const TextStyle(color: AppTheme.border, letterSpacing: 8),
                        errorText: errorMessage,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
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
                  child: Text(context.t('cancel'), style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(context.t('verifyOtp'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
