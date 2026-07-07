import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/location_utils.dart';

import '../../orders/presentation/order_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _partner = PartnerProvider();
  final _orders = OrderProvider();
  final _earnings = EarningsProvider();
  final ScrollController _scrollController = ScrollController();

  OrderModel? _incomingOrder;
  bool _leadPopupShown = false;
  StreamSubscription<List<OrderModel>>? _leadsSub;
  List<OrderModel> _nearbyOrders = [];
  bool _isLeadsLoading = true;
  final Set<String> _declinedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start listening to the real-time partner document (rating, name, status, earnings, etc.)
    _partner.listenToPartner();
    _orders.listenToOrders(); // Listen to active and reserved/scheduled orders
    _earnings.loadEarnings();
    _earnings.listenToWallet();
    _partner.refreshLocationAvailability();
    
    // Register standard ChangeNotifier listeners. Direct listeners are much more robust 
    // than top-level ListenableBuilders for complex scroll view structures.
    _partner.addListener(_handlePartnerChange);
    _earnings.addListener(_onProviderUpdate);
    _orders.addListener(_onProviderUpdate);
    
    _listenToLeads();

    // Start scheduled order auto-assign listener once partner data is ready.
    _orders.listenForScheduledOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _partner.removeListener(_handlePartnerChange);
    _earnings.removeListener(_onProviderUpdate);
    _orders.removeListener(_onProviderUpdate);
    _leadsSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _partner.refreshLocationAvailability();
    }
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {});
    }
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
      _nearbyOrders = [];
      _isLeadsLoading = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _listenToLeads() {
    _leadsSub?.cancel();
    if (!_partner.isOnline) {
      setState(() {
        _nearbyOrders = [];
        _isLeadsLoading = false;
      });
      return;
    }

    // Use instantPickupStream — broadcasts ALL in-radius instant orders simultaneously.
    // The partner's current location and maxDistanceKm are read from the partner model.
    _leadsSub = LeadService.instance
        .instantPickupStream(_partner.partner)
        .listen(
          (orders) {
            if (!mounted) return;

            // Filter out declined/ignored orders
            final visibleOrders =
                orders
                    .where((o) => !_declinedOrderIds.contains(o.orderId))
                    .toList();

            setState(() {
              _nearbyOrders = visibleOrders;
              _isLeadsLoading = false;
            });

            // If popup is shown but the order was taken (no longer in stream), auto-close
            if (_leadPopupShown && _incomingOrder != null) {
              final stillAvailable = visibleOrders.any(
                (o) => o.orderId == _incomingOrder!.orderId,
              );
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

            if (visibleOrders.isEmpty || _leadPopupShown) return;

            // Show the nearest unviewed order as a popup
            final order = visibleOrders.first;
            if (_incomingOrder?.orderId == order.orderId) return;
            setState(() {
              _incomingOrder = order;
              _leadPopupShown = true;
            });
            _showLeadPopup(order);
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _isLeadsLoading = false;
              });
            }
          },
        );
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
                  _declinedOrderIds.add(order.orderId);
                  _nearbyOrders.removeWhere((o) => o.orderId == order.orderId);
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

  Future<void> _payCommission() async {
    final amount = _earnings.commissionDueBalance;
    if (amount <= 0) return;
    await _earnings.recordCommissionPaymentOpened();
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _earnings.scrapwellUpiId,
        'pn': _earnings.scrapwellPayeeName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'Scrapwell partner commission',
      },
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppTheme.showSnack(
        context,
        'No UPI app found. Pay to ${_earnings.scrapwellUpiId} and contact support.',
        isError: true,
      );
    }
  }

  Future<void> _confirmCommissionOnWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hello Scrapwell, I have paid my partner commission amount of Rs ${_earnings.commissionDueBalance.toStringAsFixed(0)}. Please verify and clear my due balance.',
    );
    final uri = Uri.parse('https://wa.me/918744081962?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppTheme.showSnack(context, 'Unable to open WhatsApp.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildBody(context)),
        ],
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
                              image: CachedNetworkImageProvider(
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

          if (_shouldShowCommissionDueCard()) _buildCommissionDueCard(),

          if (_orders.reservedOrders.isNotEmpty) _buildScheduledBanner(context),

          if (!_partner.locationAllowed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      context.t('locationDisabledDescription'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _partner.promptAndEnableGps(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      context.t('enableLocationButton'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          OnlineToggleCard(
            isOnline: _partner.isOnline,
            onToggle: (v) async {
              if (v) {
                // Directly trigger permissions popup/GPS prompt
                final allowed = await _partner.promptAndEnableGps(context);
                if (!allowed) return;
              }
              if (v && _partner.isCommissionBlocked) {
                if (mounted) {
                  AppTheme.showSnack(
                    context,
                    Localizations.localeOf(context).languageCode == 'hi'
                        ? 'अधिक ऑर्डर प्राप्त करने के लिए स्क्रैपवेल कमीशन का भुगतान करें।'
                        : 'Pay pending Scrapwell commission to receive more orders.',
                    isError: true,
                  );
                }
                return;
              }
              await _partner.toggleOnline(v);
            },
          ),

          const SizedBox(height: 16),
          _buildAssignmentRulesCard(),

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

  bool _shouldShowCommissionDueCard() {
    final balance = _earnings.commissionDueBalance;
    if (balance <= 0.01) return false;

    // DateTime.tuesday is 2 (Monday=1, Tuesday=2 ... Sunday=7)
    final isTuesday = DateTime.now().weekday == DateTime.tuesday;

    if (balance >= 500 || isTuesday) {
      return true;
    }
    return false;
  }

  Widget _buildCommissionDueCard() {
    final dueAt = _earnings.commissionDueAt;
    final dueText = dueAt == null
        ? context.t('everyTuesday')
        : 'due by ${dueAt.day}/${dueAt.month}/${dueAt.year}';
    final blocked = _partner.isCommissionBlocked ||
        _earnings.shouldBlockForCommission;

    final balanceText = _earnings.commissionDueBalance.toStringAsFixed(0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blocked ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: blocked
              ? AppTheme.error.withOpacity(0.35)
              : AppTheme.warning.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                blocked
                    ? Icons.lock_clock_rounded
                    : Icons.account_balance_wallet_rounded,
                color: blocked ? AppTheme.error : AppTheme.warning,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blocked 
                          ? context.t('commissionPaymentRequired') 
                          : context.t('commissionDueTitle'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: blocked ? AppTheme.error : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('payCommissionToReceive')
                          .replaceAll('{amount}', balanceText)
                          .replaceAll('{dueText}', dueText),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _confirmCommissionOnWhatsApp,
                icon: const Icon(Icons.chat_rounded, size: 16, color: AppTheme.primary),
                label: Text(
                  context.t('iPaidButton'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _payCommission,
                icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                label: Text(
                  context.t('payButton'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentRulesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('howOrdersAssigned'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _assignmentRuleRow(
            Icons.flash_on_rounded,
            context.t('instantPickupsTitle'),
            context.t('instantPickupsDesc'),
            AppTheme.primary,
          ),
          const SizedBox(height: 10),
          _assignmentRuleRow(
            Icons.calendar_month_rounded,
            context.t('scheduledPickupsTitle'),
            context.t('scheduledPickupsDesc'),
            AppTheme.warning,
          ),
        ],
      ),
    );
  }

  Widget _assignmentRuleRow(
    IconData icon,
    String title,
    String body,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              onChanged:
                  isOnline
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
                Text(
                  '5 km',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? AppTheme.textSecondary : AppTheme.border,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '30 km',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? AppTheme.textSecondary : AppTheme.border,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadFeed(BuildContext context) {
    if (_partner.isCommissionBlocked || _earnings.shouldBlockForCommission) {
      return _buildCommissionBlockedState();
    }
    if (!_partner.isOnline) return _buildOfflineEmptyState();

    if (_isLeadsLoading) {
      return const Column(children: [SkeletonLeadCard(), SkeletonLeadCard()]);
    }

    if (_nearbyOrders.isEmpty) return _buildEmptyLeadState();

    return Column(
      children:
          _nearbyOrders
              .map(
                (order) => LeadFeedCard(
                  order: order,
                  partner: _partner.partner,
                  onAccept: () => _showLeadPopup(order),
                  onIgnore: () {
                    setState(() {
                      _declinedOrderIds.add(order.orderId);
                      _nearbyOrders.removeWhere(
                        (o) => o.orderId == order.orderId,
                      );
                    });
                  },
                ),
              )
              .toList(),
    );
  }

  Widget _buildCommissionBlockedState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.error.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.payments_rounded, size: 42, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text(
            'Orders are paused',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Clear pending commission of Rs ${_earnings.commissionDueBalance.toStringAsFixed(0)} to receive further orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _payCommission,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Pay Commission'),
          ),
          TextButton.icon(
            onPressed: _confirmCommissionOnWhatsApp,
            icon: const Icon(Icons.chat_rounded, size: 16),
            label: const Text('I paid, notify Scrapwell'),
          ),
        ],
      ),
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
                  context
                      .t('scanningRadiusDynamic')
                      .replaceAll(
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
          children:
              reserved
                  .map((order) => _buildReservedCard(context, order))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildReservedCard(BuildContext context, OrderModel order) {
    final diff = order.scheduledDateTime.difference(DateTime.now());
    final canCancel = diff.inMinutes >= 60;
    final isOnline = _partner.isOnline;
    final categories = order.allScrapCategories;

    // Build human-readable countdown
    String _countdownLabel() {
      final now = DateTime.now();
      final slot = order.scheduledDateTime;
      final isToday = slot.year == now.year && slot.month == now.month && slot.day == now.day;
      final isTomorrow = slot.difference(DateTime(now.year, now.month, now.day)).inDays == 1;
      final hour = slot.hour > 12 ? slot.hour - 12 : (slot.hour == 0 ? 12 : slot.hour);
      final ampm = slot.hour >= 12 ? 'PM' : 'AM';
      final min = slot.minute.toString().padLeft(2, '0');
      final timeStr = '${hour.toString().padLeft(2, '0')}:$min $ampm';
      if (isToday) return '${context.t('pickupToday')} at $timeStr';
      if (isTomorrow) return '${context.t('pickupTomorrow')} at $timeStr';
      return '${slot.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][slot.month-1]} at $timeStr';
    }

    String _diffLabel() {
      if (diff.isNegative) return context.t('pickupToday');
      if (diff.inHours > 0) {
        return '${context.t('pickupIn')} ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
      }
      return '${context.t('pickupIn')} ${diff.inMinutes}m';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: order.orderId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.subtleShadow,
          border: Border.all(color: const Color(0xFFFDBA74).withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top header banner ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFFEA580C)),
                      const SizedBox(width: 5),
                      Text(
                        context.t('bookedAndPending'),
                        style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('₹${order.estimatedPayout.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    Text('estimated', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7))),
                  ]),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Countdown chip + time
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: diff.inMinutes < 60
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: diff.inMinutes < 60 ? AppTheme.error : AppTheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _diffLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: diff.inMinutes < 60 ? AppTheme.error : AppTheme.primary,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _countdownLabel(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Address
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerAddress,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // Metadata row: Distance, Weight, and Items count
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMetadataBadge(
                          Icons.social_distance_rounded,
                          '~${LocationUtils.calculateDistance(
                            _partner.partner.currentLat != 0.0 ? _partner.partner.currentLat : _partner.partner.shopLat,
                            _partner.partner.currentLng != 0.0 ? _partner.partner.currentLng : _partner.partner.shopLng,
                            order.customerLat,
                            order.customerLng,
                          ).toStringAsFixed(1)} km',
                          AppTheme.info,
                        ),
                        const SizedBox(width: 8),
                        _buildMetadataBadge(
                          Icons.scale_rounded,
                          '~${order.totalEstimatedWeight.toStringAsFixed(0)} kg',
                          AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        _buildMetadataBadge(
                          Icons.widgets_rounded,
                          '${order.scrapItems.isNotEmpty ? order.scrapItems.length : order.rawScrapCategories.length} items',
                          AppTheme.primary,
                        ),
                      ],
                    ),
                  ),

                  // Scrap category chips
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: categories.map((cat) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.recycling_rounded, size: 11, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                        ]),
                      )).toList(),
                    ),
                  ],

                  if (!isOnline) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.offline_bolt_rounded, size: 16, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('goOnlineToStart'),
                            style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(children: [
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
                            context.t('cancelReservationShort'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: canCancel ? 2 : 1,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF064E3B)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!LeadService.instance.isWithinWorkingHours(
                              _partner.partner, DateTime.now())) {
                              AppTheme.showSnack(context,
                                'Scheduled pickups can be started only during your working hours.',
                                isError: true);
                              return;
                            }
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(color: AppTheme.primary)),
                            );
                            final ok = await _orders.updateOrderStatus(
                              order.orderId, OrderStatus.partnerAssigned);
                            if (mounted) Navigator.pop(context); // close loader
                            if (ok && mounted) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => OrderTrackingScreen(orderId: order.orderId)));
                            }
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                          label: Text(
                            context.t('startTripNow'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(0, 44),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ]),

                  if (!canCancel) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.lock_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          context.t('lockedCannotCancel'),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelReservedOrderDialog(BuildContext screenContext, OrderModel order) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            screenContext.t('cancelReservation'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            screenContext.t('cancelReservationConfirm'),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                screenContext.t('goBack'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                showDialog(
                  context: screenContext,
                  barrierDismissible: false,
                  builder:
                      (_) => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      ),
                );
                try {
                  final ok = await LeadService.instance.cancelReservedOrder(
                    order,
                  );
                  // Ignore this order locally to prevent any stream race condition
                  _declinedOrderIds.add(order.orderId);

                  if (screenContext.mounted) {
                    Navigator.of(screenContext).pop(); // Close loading
                  }
                  if (ok && screenContext.mounted) {
                    AppTheme.showSnack(
                      screenContext,
                      Localizations.localeOf(screenContext).languageCode == 'hi'
                          ? 'आरक्षण रद्द और पुन: असाइन किया गया।'
                          : 'Reservation cancelled and reassigned.',
                    );
                  }
                } catch (e) {
                  if (screenContext.mounted) {
                    Navigator.of(screenContext).pop(); // Close loading
                  }
                  if (screenContext.mounted) {
                    AppTheme.showSnack(
                      screenContext,
                      e.toString().replaceAll('Exception:', '').trim(),
                      isError: true,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                Localizations.localeOf(screenContext).languageCode == 'hi'
                    ? 'आरक्षण रद्द करें'
                    : 'Cancel Reservation',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduledBanner(BuildContext context) {
    final count = _orders.reservedOrders.length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74).withOpacity(0.5), width: 1.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _scrollToScheduledSection,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode == 'hi'
                            ? 'आरक्षित पिकअप असाइन किया गया है'
                            : 'Scheduled Pickup Assigned',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Localizations.localeOf(context).languageCode == 'hi'
                            ? 'आपके बकेट में $count अनुसूचित ऑर्डर हैं। देखने के लिए टैप करें।'
                            : 'You have $count scheduled order(s) in your bucket. Tap to view.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_downward_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToScheduledSection() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        350.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _buildMetadataBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
