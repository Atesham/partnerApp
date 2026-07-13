import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/widgets/shared_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _earnings = EarningsProvider();
  int _selectedPeriod = 0; // 0=Today, 1=Week, 2=Month

  @override
  void initState() {
    super.initState();
    _earnings.loadEarnings();
    _earnings.listenToWallet();
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

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (!mounted) return;
        AppTheme.showSnack(
          context,
          context.t('noUpiApp').replaceAll('{upiId}', _earnings.scrapwellUpiId),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppTheme.showSnack(
        context,
        context.t('noUpiApp').replaceAll('{upiId}', _earnings.scrapwellUpiId),
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
      AppTheme.showSnack(context, context.t('unableWhatsapp'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ListenableBuilder(
        listenable: _earnings,
        builder: (_, __) {
          return CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period selector
                      _buildPeriodPicker(),
                      const SizedBox(height: 16),
                      // Big earning card
                      _buildBigEarning(),
                      const SizedBox(height: 14),
                      // Stats grid
                      _buildStatsGrid(),
                      const SizedBox(height: 16),
                      // Performance section
                      _buildPerformanceSection(),
                      const SizedBox(height: 16),
                      // Commission due — primary focus
                      _buildCommissionDueCard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true,
      snap: true,
      elevation: 0,
      titleSpacing: 20,
      title: Text(
        context.t('myEarnings'),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Period Picker
  // ─────────────────────────────────────────────────────────────
  Widget _buildPeriodPicker() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final periods = [
      context.t('today'),
      context.t('thisWeek'),
      context.t('thisMonth'),
      isHindi ? 'लाइफटाइम' : 'Lifetime',
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: List.generate(periods.length, (i) {
          final selected = _selectedPeriod == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  periods[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Big Earning Hero Card
  // ─────────────────────────────────────────────────────────────
  Widget _buildBigEarning() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final value = _selectedPeriod == 0
        ? _earnings.todayEarnings
        : _selectedPeriod == 1
            ? _earnings.weekEarnings
            : _selectedPeriod == 2
                ? _earnings.monthEarnings
                : _earnings.lifetimeEarnings;
    final orders = _selectedPeriod == 0
        ? _earnings.todayOrders
        : _selectedPeriod == 1
            ? _earnings.weekOrders
            : _selectedPeriod == 2
                ? _earnings.monthOrders
                : _earnings.lifetimeOrders;
    final periodLabels = [
      context.t('today'),
      context.t('thisWeek'),
      context.t('thisMonth'),
      isHindi ? 'लाइफटाइम' : 'Lifetime',
    ];
    final periodLabel = periodLabels[_selectedPeriod];

    if (_earnings.isLoading) {
      return const SkeletonBox(width: double.infinity, height: 110, radius: 20);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.t('earnedPeriod')} $periodLabel',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$orders ${orders == 1 ? context.t('pickupDone') : context.t('pickupsDone')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Stats 2×2 Grid
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final periodLabels = [
      context.t('today'),
      context.t('thisWeek'),
      context.t('thisMonth'),
      isHindi ? 'लाइफटाइम' : 'Lifetime',
    ];
    final periodLabel = periodLabels[_selectedPeriod];

    final earningsVal = _selectedPeriod == 0
        ? _earnings.todayEarnings
        : _selectedPeriod == 1
            ? _earnings.weekEarnings
            : _selectedPeriod == 2
                ? _earnings.monthEarnings
                : _earnings.lifetimeEarnings;

    final ordersVal = _selectedPeriod == 0
        ? _earnings.todayOrders
        : _selectedPeriod == 1
            ? _earnings.weekOrders
            : _selectedPeriod == 2
                ? _earnings.monthOrders
                : _earnings.lifetimeOrders;

    final avgPerOrderVal = ordersVal > 0 ? earningsVal / ordersVal : 0.0;

    final stats = [
      _StatItem(
        icon: Icons.payments_rounded,
        label: isHindi ? '$periodLabel की कमाई' : '$periodLabel Earnings',
        value: '₹${earningsVal.toStringAsFixed(0)}',
        color: AppTheme.primary,
      ),
      _StatItem(
        icon: Icons.inventory_2_rounded,
        label: isHindi ? '$periodLabel के पिकअप' : '$periodLabel Pickups',
        value: '$ordersVal',
        color: AppTheme.info,
      ),
      _StatItem(
        icon: Icons.trending_up_rounded,
        label: isHindi ? 'औसत प्रति पिकअप' : 'Avg. per Pickup',
        value: '₹${avgPerOrderVal.toStringAsFixed(0)}',
        color: AppTheme.warning,
      ),
      _StatItem(
        icon: Icons.account_balance_wallet_rounded,
        label: isHindi ? 'वॉलेट बैलेंस' : 'Wallet Balance',
        value: '₹${_earnings.walletBalance.toStringAsFixed(0)}',
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: stats
          .map(
            (s) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(s.icon, color: s.color, size: 16),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: s.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.label,
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
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Performance Section
  // ─────────────────────────────────────────────────────────────
  Widget _buildPerformanceSection() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final periodLabels = [
      context.t('today'),
      context.t('thisWeek'),
      context.t('thisMonth'),
      isHindi ? 'लाइफटाइम' : 'Lifetime',
    ];
    final periodLabel = periodLabels[_selectedPeriod];

    final earningsVal = _selectedPeriod == 0
        ? _earnings.todayEarnings
        : _selectedPeriod == 1
            ? _earnings.weekEarnings
            : _selectedPeriod == 2
                ? _earnings.monthEarnings
                : _earnings.lifetimeEarnings;

    final ordersVal = _selectedPeriod == 0
        ? _earnings.todayOrders
        : _selectedPeriod == 1
            ? _earnings.weekOrders
            : _selectedPeriod == 2
                ? _earnings.monthOrders
                : _earnings.lifetimeOrders;

    final avgPerOrderVal = ordersVal > 0 ? earningsVal / ordersVal : 0.0;
    final glanceTitle = isHindi ? '$periodLabel एक नज़र में' : '$periodLabel at a Glance';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                glanceTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  periodLabel,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _performanceRow(
            Icons.payments_rounded,
            context.t('avgPerPickup'),
            '₹${avgPerOrderVal.toStringAsFixed(0)}',
            AppTheme.primary,
          ),
          const Divider(height: 20, color: AppTheme.divider),
          _performanceRow(
            Icons.inventory_2_rounded,
            context.t('totalPickups'),
            '$ordersVal ${context.t('ordersText')}',
            AppTheme.info,
          ),
          const Divider(height: 20, color: AppTheme.divider),
          _performanceRow(
            Icons.account_balance_wallet_rounded,
            context.t('totalEarned'),
            '₹${earningsVal.toStringAsFixed(0)}',
            AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _performanceRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Commission Due Card — Primary Focus
  // ─────────────────────────────────────────────────────────────
  Widget _buildCommissionDueCard() {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final dueAt = _earnings.commissionDueAt;
    final dueText = _earnings.commissionDueBalance >= 500
        ? (isHindi ? 'तुरंत' : 'immediately')
        : (dueAt == null
            ? context.t('everyTuesday')
            : '${dueAt.day}/${dueAt.month}/${dueAt.year}');
    final blocked = _earnings.shouldBlockForCommission;
    final hasDue = _earnings.hasCommissionDue;

    // Colour scheme: red if blocked, amber if due, green if clear
    final Color accentColor = blocked
        ? const Color(0xFFDC2626) // Deep Tailwind Red
        : hasDue
            ? const Color(0xFFD97706) // Deep Tailwind Amber
            : const Color(0xFF059669); // Deep Tailwind Green

    final Color bgColor = blocked
        ? const Color(0xFFFEF2F2)
        : hasDue
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFECFDF5);

    final IconData headerIcon = blocked
        ? Icons.error_outline_rounded
        : hasDue
            ? Icons.pending_actions_rounded
            : Icons.task_alt_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.18), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // ── Status Banner ───────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: bgColor,
              child: Row(
                children: [
                  Icon(headerIcon, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      blocked
                          ? context.t('accountBlocked')
                          : hasDue
                              ? context.t('commissionPending')
                              : context.t('commissionClear'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      blocked
                          ? (isHindi ? 'ब्लॉक' : 'Blocked')
                          : hasDue
                              ? (isHindi ? 'लंबित' : 'Due')
                              : (isHindi ? 'क्लियर' : 'Clear'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Amount + Details ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Due amount hero row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('dueBalance'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_earnings.commissionDueBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: hasDue ? accentColor : AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      if (hasDue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payment_rounded, size: 14, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                context.t('payNow'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1, color: AppTheme.divider),
                  const SizedBox(height: 18),

                  // Info details grid/rows
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          Icons.percent_rounded,
                          context.t('commissionRate'),
                          context.t('commissionRateValue'),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                        ),
                        _infoRow(
                          Icons.calendar_today_rounded,
                          context.t('payBy'),
                          dueText,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                        ),
                        _infoRow(
                          Icons.account_balance_rounded,
                          context.t('upiId'),
                          _earnings.scrapwellUpiId,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: hasDue ? _payCommission : null,
                      icon: const Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                      label: Text(
                        hasDue
                            ? context.t('payViaUpi').replaceAll('{amount}', _earnings.commissionDueBalance.toStringAsFixed(0))
                            : context.t('nothingToPay'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  if (hasDue) ...[
                    const SizedBox(height: 10),
                    // WhatsApp confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _confirmCommissionOnWhatsApp,
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(
                          context.t('alreadyPaidWhatsapp'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Footnote note banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('upiPaymentNote'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
