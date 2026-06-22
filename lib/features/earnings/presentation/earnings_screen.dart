import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
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
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppTheme.showSnack(
        context,
        'No UPI app found. Pay to ${_earnings.scrapwellUpiId}.',
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
      body: ListenableBuilder(
        listenable: _earnings,
        builder: (_, __) {
          return CustomScrollView(
            slivers: [
              _buildHeader(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period selector
                      _buildPeriodPicker(),
                      const SizedBox(height: 20),
                      // Big earning number
                      _buildBigEarning(),
                      const SizedBox(height: 20),
                      // Stats grid
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      // Chart placeholder
                      _buildChartSection(),
                      const SizedBox(height: 24),
                      // Wallet balance
                      _buildWalletCard(),
                      const SizedBox(height: 16),
                      _buildCommissionWalletCard(),
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

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true, snap: true, elevation: 0,
      title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
      titleSpacing: 20,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_rounded, color: AppTheme.primary, size: 16),
              SizedBox(width: 6),
              Text('Export', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodPicker() {
    final periods = ['Today', 'This Week', 'This Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
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
                child: Text(periods[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textSecondary)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBigEarning() {
    final value = _selectedPeriod == 0
        ? _earnings.todayEarnings
        : _selectedPeriod == 1
            ? _earnings.weekEarnings
            : _earnings.monthEarnings;
    final orders = _selectedPeriod == 0
        ? _earnings.todayOrders
        : _selectedPeriod == 1
            ? _earnings.weekOrders
            : _earnings.monthOrders;

    return _earnings.isLoading
        ? const SkeletonBox(width: double.infinity, height: 120, radius: 20)
        : Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹${value.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('$orders pickups completed', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ])),
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 30),
                ),
              ],
            ),
          );
  }

  Widget _buildStatsGrid() {
    final stats = [
      ('₹${_earnings.todayEarnings.toStringAsFixed(0)}', 'Today', Icons.today_rounded, AppTheme.primary),
      ('₹${_earnings.weekEarnings.toStringAsFixed(0)}', 'This Week', Icons.calendar_view_week_rounded, AppTheme.info),
      ('${_earnings.todayOrders}', 'Today\'s Orders', Icons.inventory_2_rounded, AppTheme.warning),
      ('${_earnings.weekOrders}', 'Week\'s Orders', Icons.bar_chart_rounded, AppTheme.error),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      children: stats.map((s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.subtleShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(s.$3, color: s.$4, size: 20),
          const Spacer(),
          Text(s.$1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: s.$4)),
          const SizedBox(height: 2),
          Text(s.$2, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ]),
      )).toList(),
    );
  }

  Widget _buildChartSection() {
    // Show real performance metrics instead of dummy chart bars
    final avgPerOrder = _earnings.weekOrders > 0
        ? _earnings.weekEarnings / _earnings.weekOrders
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('This Week', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _performanceRow(Icons.payments_rounded, 'Avg. Per Order',
              '₹${avgPerOrder.toStringAsFixed(0)}', AppTheme.primary),
          const Divider(height: 20, color: AppTheme.divider),
          _performanceRow(Icons.inventory_2_rounded, 'Week Pickups',
              '${_earnings.weekOrders} orders', AppTheme.info),
          const Divider(height: 20, color: AppTheme.divider),
          _performanceRow(Icons.account_balance_wallet_rounded, 'Week Earnings',
              '₹${_earnings.weekEarnings.toStringAsFixed(0)}', AppTheme.success),
        ],
      ),
    );
  }

  Widget _performanceRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }


  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Wallet Balance', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('₹${_earnings.walletBalance.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: const Text('Withdraw', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionWalletCard() {
    final dueAt = _earnings.commissionDueAt;
    final dueText = dueAt == null
        ? 'Every Tuesday'
        : '${dueAt.day}/${dueAt.month}/${dueAt.year}';
    final blocked = _earnings.shouldBlockForCommission;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(
          color: blocked
              ? AppTheme.error.withOpacity(0.2)
              : AppTheme.warning.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: blocked
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  blocked
                      ? Icons.lock_clock_rounded
                      : Icons.receipt_long_rounded,
                  color: blocked ? AppTheme.error : AppTheme.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scrapwell Commission Wallet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rs ${_earnings.commissionDueBalance.toStringAsFixed(0)} due',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: blocked ? AppTheme.error : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _commissionInfoRow('Rate', '2% of completed order bill'),
          const Divider(height: 18, color: AppTheme.divider),
          _commissionInfoRow('Pay by', dueText),
          const Divider(height: 18, color: AppTheme.divider),
          _commissionInfoRow('UPI ID', _earnings.scrapwellUpiId),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _earnings.commissionDueBalance > 0 ? _payCommission : null,
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text('Pay Commission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmCommissionOnWhatsApp,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('I paid, notify Scrapwell on WhatsApp'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Payment opens in any installed UPI app. Dues are cleared after Scrapwell verifies the transfer.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
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
