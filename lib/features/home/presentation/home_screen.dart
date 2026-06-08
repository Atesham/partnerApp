import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'widgets/online_toggle_card.dart';
import 'widgets/lead_feed_card.dart';
import 'lead_popup.dart';
import '../../../core/utils/location_utils.dart';
import '../../orders/presentation/order_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ FIX: Use the singleton directly — same instance everywhere
  final _partner = PartnerProvider();
  final _orders = OrderProvider();
  final _earnings = EarningsProvider();

  OrderModel? _incomingOrder;
  bool _leadPopupShown = false;
  StreamSubscription<List<OrderModel>>? _leadsSub;

  double get _partnerLat => _partner.partner.currentLat != 0.0
      ? _partner.partner.currentLat
      : _partner.partner.shopLat;

  double get _partnerLng => _partner.partner.currentLng != 0.0
      ? _partner.partner.currentLng
      : _partner.partner.shopLng;

  double get _scanLat {
    final activeOrder = _orders.currentOrder;
    if (activeOrder != null && activeOrder.isActive) {
      return activeOrder.customerLat;
    }
    return _partnerLat;
  }

  double get _scanLng {
    final activeOrder = _orders.currentOrder;
    if (activeOrder != null && activeOrder.isActive) {
      return activeOrder.customerLng;
    }
    return _partnerLng;
  }

  double get _scanRadius {
    final activeOrder = _orders.currentOrder;
    if (activeOrder != null && activeOrder.isActive) {
      return 5.0; // Batching range: within 5 km of the active order customer destination
    }
    return _partner.partner.maxDistanceKm;
  }

  @override
  void initState() {
    super.initState();
    // Start listening to the real-time partner document (rating, name, status, earnings, etc.)
    _partner.listenToPartner();
    _orders.listenToOrders(); // Listen to active and reserved/scheduled orders
    _earnings.loadEarnings();
    _partner.addListener(_handlePartnerChange);
    _listenToLeads();

    // Start scheduled order auto-assign listener once partner data is ready.
    // This is safe to call immediately — it filters by approved status internally.
    _orders.listenForScheduledOrders();
  }

  @override
  void dispose() {
    _partner.removeListener(_handlePartnerChange);
    _leadsSub?.cancel();
    super.dispose();
  }

  void _handlePartnerChange() {
    if (_partner.isOnline) {
      // Always restart the stream when partner data changes so that
      // radius updates (maxDistanceKm) and live location updates are
      // immediately reflected in the broadcast filter.
      _listenToLeads();
    } else {
      _leadsSub?.cancel();
      _leadsSub = null;
    }
  }

  void _listenToLeads() {
    _leadsSub?.cancel();
    if (!_partner.isOnline) return;

    // Use instantPickupStream — broadcasts ALL in-radius instant orders simultaneously.
    // The partner's current location and maxDistanceKm are read from the partner model.
    _leadsSub = LeadService.instance
        .instantPickupStream(_partner.partner)
        .listen((orders) {
      if (!mounted) return;

      // If popup is shown but the order was taken (no longer in stream), auto-close
      if (_leadPopupShown && _incomingOrder != null) {
        final stillAvailable =
            orders.any((o) => o.orderId == _incomingOrder!.orderId);
        if (!stillAvailable) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          setState(() {
            _incomingOrder = null;
            _leadPopupShown = false;
          });
          return;
        }
      }

      if (orders.isEmpty || _leadPopupShown) return;

      // Show the nearest unviewed order as a popup
      final order = orders.first;
      if (_incomingOrder?.orderId == order.orderId) return;
      setState(() {
        _incomingOrder = order;
        _leadPopupShown = true;
      });
      _showLeadPopup(order);
    });
  }

  void _showLeadPopup(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (_) => LeadPopup(
            order: order,
            partner: _partner.partner,
            onAccepted: () => setState(() => _leadPopupShown = false),
            onDeclined:
                () => setState(() {
                  _incomingOrder = null;
                  _leadPopupShown = false;
                }),
          ),
    ).then(
      (_) => setState(() {
        _incomingOrder = null;
        _leadPopupShown = false;
      }),
    );
  }

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.t('greetingMorning');
    if (h < 17) return context.t('greetingAfternoon');
    return context.t('greetingEvening');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // ✅ FIX: ONE top-level ListenableBuilder that listens to BOTH
      // _partner AND _earnings. Any Firestore update to rating/name/status
      // will now trigger a full rebuild of the screen.
      body: ListenableBuilder(
        listenable: Listenable.merge([_partner, _earnings, _orders]),
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(child: _buildBody(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      title: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting(context)}, 👋',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _partner.partner.shopName.isNotEmpty
                        ? _partner.partner.shopName
                        : _partner.partner.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                PulsingDot(
                  color:
                      _partner.isOnline
                          ? AppTheme.onlineGreen
                          : AppTheme.offlineGray,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                    image:
                        _partner.partner.profilePhotoUrl.isNotEmpty
                            ? DecorationImage(
                              image: NetworkImage(
                                _partner.partner.profilePhotoUrl,
                              ),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      _partner.partner.profilePhotoUrl.isEmpty
                          ? Center(
                            child: Text(
                              _partner.partner.initials,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          )
                          : null,
                ),
              ],
            ),
          ],
        ),
      ),
      titleSpacing: 20,
      actions: [const SizedBox(width: 20)],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          if (!_partner.locationAllowed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_rounded,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'hi'
                          ? 'स्थान पहुंच (GPS) अक्षम है। ऑनलाइन जाने के लिए इसे गोपनीयता सेटिंग्स में चालू करें।'
                          : 'Location Access (GPS) is disabled. Turn it on in Privacy Settings to receive requests.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          OnlineToggleCard(
            isOnline: _partner.isOnline,
            onToggle: (v) async {
              if (v && !_partner.locationAllowed) {
                AppTheme.showSnack(
                  context,
                  Localizations.localeOf(context).languageCode == 'hi'
                      ? 'स्थान पहुंच बंद है। इसे गोपनीयता केंद्र में चालू करें।'
                      : 'Location access is disabled. Enable it in Privacy & Data to go online.',
                  isError: true,
                );
                return;
              }
              await _partner.toggleOnline(v);
            },
          ),

          const SizedBox(height: 16),
          _buildRadiusSelector(context),

          const SizedBox(height: 16),
          _buildStatsRow(context),

          _buildScheduledBookings(context),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('nearbyRequests'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _partner.isOnline
                          ? context.t('liveRequests')
                          : context.t('goOnlineToSeeRequests'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_partner.isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PulsingDot(color: AppTheme.primary, size: 7),
                      const SizedBox(width: 6),
                      Text(
                        context.t('live'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          _buildLeadFeed(context),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ✅ FIX: No inner ListenableBuilder here anymore.
  // Parent's Listenable.merge([_partner, _earnings]) handles both.
  Widget _buildStatsRow(BuildContext context) {
    if (_earnings.isLoading) return const SkeletonStatRow();

    return Row(
      children: [
        Expanded(
          child: _statCard(
            '₹${_partner.partner.totalEarnings.toStringAsFixed(0)}',
            context.t('totalEarnings'),
            Icons.payments_rounded,
            AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            '${_partner.partner.totalOrders}',
            context.t('totalOrders'),
            Icons.inventory_2_rounded,
            AppTheme.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            '${_partner.partner.rating.toStringAsFixed(1)} ★',
            context.t('rating'),
            Icons.star_rounded,
            AppTheme.warning,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSelector(BuildContext context) {
    final currentRadius = _partner.partner.maxDistanceKm;
    final isOnline = _partner.isOnline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.divider.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('searchRadius'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentRadius.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.12),
              valueIndicatorColor: AppTheme.primary,
              trackHeight: 4,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: currentRadius.clamp(5.0, 30.0),
              min: 5.0,
              max: 30.0,
              divisions: 5,
              label: '${currentRadius.toStringAsFixed(0)} km',
              onChanged: isOnline
                  ? (value) async {
                      await _partner.updateSearchRadius(value);
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 km',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? AppTheme.textSecondary : AppTheme.border,
                      fontWeight: FontWeight.w600,
                    )),
                Text('30 km',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? AppTheme.textSecondary : AppTheme.border,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadFeed(BuildContext context) {
    if (!_partner.isOnline) return _buildOfflineEmptyState();

    return StreamBuilder<List<OrderModel>>(
      // Use instantPickupStream — partner sees ALL orders in their radius simultaneously.
      // The stream is already filtered and sorted by distance.
      stream: LeadService.instance.instantPickupStream(_partner.partner),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(
            children: [SkeletonLeadCard(), SkeletonLeadCard()],
          );
        }

        final orders = snap.data ?? [];

        if (orders.isEmpty) return _buildEmptyLeadState();

        return Column(
          children: orders
              .map(
                (order) => LeadFeedCard(
                  order: order,
                  partner: _partner.partner,
                  onAccept: () => _showLeadPopup(order),
                  onIgnore: () {},
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildOfflineEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.power_settings_new_rounded,
              size: 36,
              color: AppTheme.offlineGray,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('youAreOffline'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('offlineSub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLeadState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 36,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('noNearbyRequests'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('noRequestsSub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulsingDot(color: AppTheme.primary, size: 7),
                const SizedBox(width: 8),
                Text(
                  context.t('scanningRadiusDynamic').replaceAll(
                        '{radius}',
                        _partner.partner.maxDistanceKm.toStringAsFixed(0),
                      ),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledBookings(BuildContext context) {
    final reserved = _orders.reservedOrders;
    if (reserved.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          context.t('scheduledBookings'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Localizations.localeOf(context).languageCode == 'hi'
              ? 'आपके आरक्षित कैलेंडर स्लॉट और पिकअप विवरण'
              : 'Your reserved calendar slots for scheduled pickups',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: reserved.map((order) => _buildReservedCard(context, order)).toList(),
        ),
      ],
    );
  }

  Widget _buildReservedCard(BuildContext context, OrderModel order) {
    final diff = order.scheduledDateTime.difference(DateTime.now());
    final canCancel = diff.inMinutes >= 60;
    final isOnline = _partner.isOnline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.divider.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDBA74).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 12, color: Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Text(
                      context.t('bookedAndPending'),
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '₹${order.estimatedPayout.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),

          if (!isOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_bolt_rounded, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('goOnlineToStart'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                order.pickupSlot,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (canCancel) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelReservedOrderDialog(context, order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'hi' ? 'रद्द करें' : 'Cancel',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: canCancel ? 2 : 1,
                child: ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    );
                    final ok = await _orders.updateOrderStatus(order.orderId, OrderStatus.partnerAssigned);
                    if (mounted) Navigator.pop(context); // close loader
                    if (ok && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderId: order.orderId),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 44),
                    elevation: 0,
                  ),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'hi' ? 'यात्रा शुरू करें' : 'Start Trip Now',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          if (!canCancel) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.t('lockedCannotCancel'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
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

  void _cancelReservedOrderDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            context.t('cancelReservation'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            context.t('cancelReservationConfirm'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.t('goBack'),
                style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                );
                try {
                  final ok = await LeadService.instance.cancelReservedOrder(order);
                  if (mounted) Navigator.pop(context); // Close loading
                  if (ok && mounted) {
                    AppTheme.showSnack(
                      context,
                      Localizations.localeOf(context).languageCode == 'hi'
                          ? 'आरक्षण रद्द और पुन: असाइन किया गया।'
                          : 'Reservation cancelled and reassigned.',
                    );
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(context); // Close loading
                  if (mounted) {
                    AppTheme.showSnack(
                      context,
                      e.toString().replaceAll('Exception:', '').trim(),
                      isError: true,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                Localizations.localeOf(context).languageCode == 'hi' ? 'आरक्षण रद्द करें' : 'Cancel Reservation',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }
}
