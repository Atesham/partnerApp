import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'widgets/online_toggle_card.dart';
import 'widgets/lead_feed_card.dart';
import 'lead_popup.dart';

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

  LeadModel? _incomingLead;
  bool _leadPopupShown = false;

  @override
  void initState() {
    super.initState();
    // Start listening to the real-time partner document (rating, name, status, earnings, etc.)
    _partner.listenToPartner();
    _earnings.loadEarnings();
    _listenToLeads();
  }

  void _listenToLeads() {
    if (!_partner.isOnline) return;
    LeadService.instance.nearbyLeadsStream().listen((leads) {
      if (!mounted || leads.isEmpty || _leadPopupShown) return;
      final lead = leads.first;
      if (_incomingLead?.leadId == lead.leadId) return;
      setState(() {
        _incomingLead = lead;
        _leadPopupShown = true;
      });
      _showLeadPopup(lead);
    });
  }

  void _showLeadPopup(LeadModel lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder:
          (_) => LeadPopup(
            lead: lead,
            partner: _partner.partner,
            onAccepted: () => setState(() => _leadPopupShown = false),
            onDeclined:
                () => setState(() {
                  _incomingLead = null;
                  _leadPopupShown = false;
                }),
          ),
    ).then(
      (_) => setState(() {
        _incomingLead = null;
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
        listenable: Listenable.merge([_partner, _earnings]),
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
                if (kDebugMode)
                  IconButton(
                    icon: const Icon(Icons.bolt, color: AppTheme.primary, size: 24),
                    onPressed: () async {
                      try {
                        await LeadService.instance.createDemoLead();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo lead created in Firestore successfully!'),
                              backgroundColor: AppTheme.onlineGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create demo lead: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
                    tooltip: 'Simulate Customer Booking',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 8),
                  ),
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

          OnlineToggleCard(
            isOnline: _partner.isOnline,
            onToggle: (v) async {
              await _partner.toggleOnline(v);
              if (v) _listenToLeads();
            },
          ),

          const SizedBox(height: 16),

          // ✅ FIX: _buildStatsRow no longer has its own ListenableBuilder.
          // It's rebuilt by the top-level merge listener above, so rating
          // updates from Firestore will reflect here in real-time.
          _buildStatsRow(context),

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
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadFeed(BuildContext context) {
    if (!_partner.isOnline) return _buildOfflineEmptyState();

    return StreamBuilder<List<LeadModel>>(
      stream: LeadService.instance.nearbyLeadsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(
            children: [SkeletonLeadCard(), SkeletonLeadCard()],
          );
        }

        final leads = snap.data ?? [];
        if (leads.isEmpty) return _buildEmptyLeadState();

        return Column(
          children:
              leads
                  .map(
                    (lead) => LeadFeedCard(
                      lead: lead,
                      onAccept: () => _showLeadPopup(lead),
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
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
                  context.t('scanningRadius'),
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
}
