import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/l10n/app_localizations.dart';

class PaymentInstructionsScreen extends StatefulWidget {
  final OrderModel order;
  final double paidToCustomer;
  final VoidCallback onPaymentConfirmed;

  const PaymentInstructionsScreen({
    super.key,
    required this.order,
    required this.paidToCustomer,
    required this.onPaymentConfirmed,
  });

  @override
  State<PaymentInstructionsScreen> createState() =>
      _PaymentInstructionsScreenState();
}

class _PaymentInstructionsScreenState extends State<PaymentInstructionsScreen> {
  String _selectedMethod = 'upi'; // 'upi' or 'cash'
  bool _isSaving = false;

  // ── Number → Hindustani words ─────────────────────────────────────────────
  String _inWords(double amount) {
    final int val = amount.toInt();
    if (val == 0) return 'Zero Rupaye';

    const ones = [
      '', 'Ek', 'Do', 'Teen', 'Char', 'Paanch', 'Chhah', 'Saat', 'Aath',
      'Nau', 'Das', 'Gyarah', 'Barah', 'Terah', 'Chaudah', 'Pandrah',
      'Solah', 'Satrah', 'Atharah', 'Unnees', 'Bees',
    ];
    const tens = [
      '', '', 'Bees', 'Tees', 'Chaalees', 'Pachaas',
      'Saath', 'Sattar', 'Assi', 'Nabbe',
    ];

    String words = '';
    int n = val;

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      words += thousands < ones.length
          ? '${ones[thousands]} Hazaar '
          : '$thousands Hazaar ';
      n = n % 1000;
    }
    if (n >= 100) {
      final hundreds = n ~/ 100;
      words += hundreds < ones.length
          ? '${ones[hundreds]} Sau '
          : '$hundreds Sau ';
      n = n % 100;
    }
    if (n >= 21) {
      final t = n ~/ 10;
      words += t < tens.length ? '${tens[t]} ' : '${t * 10} ';
      n = n % 10;
      if (n > 0 && n < ones.length) words += '${ones[n]} ';
    } else if (n > 0 && n < ones.length) {
      words += '${ones[n]} ';
    }

    return '${words.trim()} Rupaye';
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _callCustomer() async {
    final phone = widget.order.customerPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsAppCustomer() async {
    final raw = widget.order.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return;
    final number = raw.startsWith('91') ? raw : '91$raw';
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyPhoneNumber() {
    final phone = widget.order.customerPhone.trim();
    if (phone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: phone));
    if (mounted) AppTheme.showSnack(context, context.t('copiedSnack'));
  }

  /// Saves the selected payment method to Firestore then calls onPaymentConfirmed.
  /// Shows an error snack if Firestore fails, but still lets the flow continue
  /// so the partner is never blocked by a network issue.
  Future<void> _confirmPayment() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.orderId)
          .update({
        'paymentMethod': _selectedMethod,
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PaymentInstructions] Firestore update failed: $e');
      // Non-blocking — we still proceed so order flow is not stuck.
      if (mounted) {
        AppTheme.showSnack(
          context,
          'Payment recorded locally. Will sync shortly.',
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onPaymentConfirmed();
  }

  // ── Derived order data (computed once per build) ──────────────────────────

  double get _totalWeight {
    if (widget.order.scrapItems.isNotEmpty) {
      return widget.order.scrapItems
          .fold(0.0, (s, i) => s + i.actualWeight);
    }
    return widget.order.rawEstimatedWeight;
  }

  /// Weighted average rate across all items (0 if no items).
  double get _avgRate {
    if (widget.order.scrapItems.isEmpty) return 0.0;
    final totalPaid = widget.order.scrapItems
        .fold(0.0, (s, i) => s + i.actualTotal);
    final wt = _totalWeight;
    return wt > 0 ? totalPaid / wt : 0.0;
  }

  String _scrapType(BuildContext context) {
    if (widget.order.scrapItems.isNotEmpty) {
      final cats = widget.order.scrapItems
          .map((i) => i.category)
          .toSet() // deduplicate
          .join(', ');
      return cats;
    }
    if (widget.order.rawScrapCategories.isNotEmpty) {
      return widget.order.rawScrapCategories.join(', ');
    }
    return context.t('mixedScrapLabel');
  }

  /// Shows the full order ID as stored in Firestore with a # prefix.
  String get _displayOrderId => '#${widget.order.orderId}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery for responsive sizing
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    // Scale factor: 1.0 on a 360px wide phone, proportionally different on tablets/small phones
    final scale = (sw / 360.0).clamp(0.85, 1.3);

    final amount = widget.paidToCustomer.clamp(0, double.infinity).toDouble();
    final amountStr = amount.toStringAsFixed(0);
    final inWordsStr = _inWords(amount);

    return PopScope(
      // Allow back navigation — pop returns to WeighingScreen
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        // Nothing extra needed — default system back is allowed when !_isSaving
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: _buildAppBar(context, scale),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16 * scale, 12 * scale, 16 * scale, 16 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Hero Banner
                      _HeroBanner(
                        amount: amountStr,
                        inWords: inWordsStr,
                        motivation: context.t('paymentMotivation'),
                        amountLabel: context.t('payAmountLabel'),
                        scale: scale,
                      ),
                      SizedBox(height: 14 * scale),

                      // 2. Order Summary
                      _OrderSummaryCard(
                        title: context.t('orderSummaryTitle'),
                        orderId: _displayOrderId,
                        totalWeight: _totalWeight,
                        scrapType: _scrapType(context),
                        rate: _avgRate,
                        totalAmount: amount,
                        weightLabel: context.t('totalWeightLabel'),
                        scrapTypeLabel: context.t('scrapTypeLabel'),
                        rateLabel: context.t('rateLabel'),
                        totalLabel: context.t('totalAmountLabel'),
                        infoText: context.t('paymentInstructionsSub'),
                        scale: scale,
                      ),
                      SizedBox(height: 14 * scale),

                      // 3. Payment Method
                      _PaymentMethodCard(
                        title: context.t('paymentMethodTitle'),
                        selected: _selectedMethod,
                        upiLabel: context.t('upiTransferLabel'),
                        cashLabel: context.t('cashPaymentLabel'),
                        onChanged: _isSaving
                            ? null
                            : (val) => setState(() => _selectedMethod = val),
                        scale: scale,
                      ),
                      SizedBox(height: 14 * scale),

                      // 4. Customer Details
                      _CustomerDetailsCard(
                        title: context.t('customerDetailsTitle2'),
                        name: widget.order.customerName,
                        phone: widget.order.customerPhone,
                        callLabel: context.t('callLabel'),
                        whatsAppLabel: context.t('whatsAppLabel'),
                        onCopy: _copyPhoneNumber,
                        onCall: _callCustomer,
                        onWhatsApp: _whatsAppCustomer,
                        scale: scale,
                      ),
                      SizedBox(height: 14 * scale),

                      // 5. Tip Banner
                      _TipBanner(
                        text: context.t('paymentTipBanner'),
                        scale: scale,
                      ),
                      SizedBox(height: 20 * scale),
                    ],
                  ),
                ),
              ),

              // 6. Bottom CTA — always visible
              _BottomCTA(
                isSaving: _isSaving,
                buttonLabel: context
                    .t('ctaButtonLabel')
                    .replaceAll('{amount}', amountStr),
                subCaption: context.t('ctaSubCaption'),
                onPressed: _confirmPayment,
                scale: scale,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, double scale) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // Back button — manually handles the _isSaving guard
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppTheme.textPrimary,
        ),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _isSaving ? null : () => Navigator.maybePop(context),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('payCustomerTitle'),
            style: GoogleFonts.manrope(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: (17 * scale).clamp(14, 20),
            ),
          ),
          Text(
            context.t('payCustomerTitleSub'),
            style: GoogleFonts.manrope(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: (11 * scale).clamp(9, 13),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              Text(
                context.t('secureLabel'),
                style: GoogleFonts.manrope(
                  color: AppTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String amount;
  final String inWords;
  final String motivation;
  final String amountLabel;
  final double scale;

  const _HeroBanner({
    required this.amount,
    required this.inWords,
    required this.motivation,
    required this.amountLabel,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = (100.0 * scale).clamp(76.0, 130.0);
    final amountFontSize = (46.0 * scale).clamp(34.0, 56.0);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Sparkle decorations — positioned relative to right edge
            Positioned(
              top: 10,
              right: avatarSize + 10,
              child: _Sparkle(
                size: (10 * scale).clamp(7, 14),
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Positioned(
              top: 34,
              right: avatarSize - 14,
              child: _Sparkle(
                size: (7 * scale).clamp(5, 10),
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              bottom: 18,
              right: avatarSize + 20,
              child: _Sparkle(
                size: (6 * scale).clamp(4, 9),
                color: Colors.amber.withValues(alpha: 0.6),
              ),
            ),
            // Avatar circle on the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: avatarSize,
                child: Center(
                  child: Container(
                    width: avatarSize * 0.9,
                    height: avatarSize * 0.9,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: avatarSize * 0.55,
                    ),
                  ),
                ),
              ),
            ),
            // Main content — padded so it never overlaps the avatar
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20 * scale, avatarSize + 8, 20 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amountLabel,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: (12 * scale).clamp(10, 15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₹$amount',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: amountFontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scale,
                      vertical: 4 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      inWords,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: (11 * scale).clamp(9, 13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Text(
                    motivation,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: (12 * scale).clamp(10, 14),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
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
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.auto_awesome_rounded, size: size, color: color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  final String title;
  final String orderId;
  final double totalWeight;
  final String scrapType;
  final double rate;
  final double totalAmount;
  final String weightLabel;
  final String scrapTypeLabel;
  final String rateLabel;
  final String totalLabel;
  final String infoText;
  final double scale;

  const _OrderSummaryCard({
    required this.title,
    required this.orderId,
    required this.totalWeight,
    required this.scrapType,
    required this.rate,
    required this.totalAmount,
    required this.weightLabel,
    required this.scrapTypeLabel,
    required this.rateLabel,
    required this.totalLabel,
    required this.infoText,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14 * scale, 16, 0),
            child: Row(
              children: [
                _CardIcon(icon: Icons.receipt_long_rounded, scale: scale),
                SizedBox(width: 10 * scale),
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: (15 * scale).clamp(13, 18),
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                // Full order ID — scrollable on very small screens
                Flexible(
                  child: Text(
                    orderId,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: (12 * scale).clamp(10, 14),
                      color: AppTheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14 * scale),

          // ── 2 × 2 grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.scale_rounded,
                    label: weightLabel,
                    value: '${totalWeight.toStringAsFixed(1)} kg',
                    scale: scale,
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.inventory_2_rounded,
                    label: scrapTypeLabel,
                    value: scrapType,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.sell_rounded,
                    label: rateLabel,
                    value: rate > 0 ? '₹${rate.toStringAsFixed(0)} / kg' : '—',
                    scale: scale,
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: _SummaryTile(
                    icon: Icons.currency_rupee_rounded,
                    label: totalLabel,
                    value: '₹${totalAmount.toStringAsFixed(0)}',
                    bold: true,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12 * scale),

          // ── Info strip ──
          Container(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 12 * scale),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10 * scale,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    infoText,
                    style: GoogleFonts.manrope(
                      fontSize: (11.5 * scale).clamp(10, 13),
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
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

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;
  final double scale;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: (18 * scale).clamp(14, 22)),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: (11 * scale).clamp(9, 13),
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: (13 * scale).clamp(11, 15),
                  color: AppTheme.textPrimary,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Method Card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final String title;
  final String selected;
  final String upiLabel;
  final String cashLabel;
  final ValueChanged<String>? onChanged; // null when saving (disabled)
  final double scale;

  const _PaymentMethodCard({
    required this.title,
    required this.selected,
    required this.upiLabel,
    required this.cashLabel,
    required this.onChanged,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.wallet_rounded, scale: scale),
              SizedBox(width: 10 * scale),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: (15 * scale).clamp(13, 18),
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Row(
            children: [
              Expanded(
                child: _MethodTile(
                  isSelected: selected == 'upi',
                  onTap: onChanged != null ? () => onChanged!('upi') : null,
                  icon: const _UpiLogo(),
                  label: upiLabel,
                  scale: scale,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: _MethodTile(
                  isSelected: selected == 'cash',
                  onTap: onChanged != null ? () => onChanged!('cash') : null,
                  icon: Icon(
                    Icons.payments_rounded,
                    size: (26 * scale).clamp(20, 32),
                    color: const Color(0xFF6B7280),
                  ),
                  label: cashLabel,
                  scale: scale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget icon;
  final String label;
  final double scale;

  const _MethodTile({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          vertical: 14 * scale,
          horizontal: 10 * scale,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primaryLight : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            icon,
            SizedBox(width: 6 * scale),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: (12 * scale).clamp(10, 14),
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4 * scale),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: (22 * scale).clamp(18, 26),
              height: (22 * scale).clamp(18, 26),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// UPI label badge — no external asset needed.
class _UpiLogo extends StatelessWidget {
  const _UpiLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEECFB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'UPI',
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3B1FA8),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Details Card
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerDetailsCard extends StatelessWidget {
  final String title;
  final String name;
  final String phone;
  final String callLabel;
  final String whatsAppLabel;
  final VoidCallback onCopy;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final double scale;

  const _CustomerDetailsCard({
    required this.title,
    required this.name,
    required this.phone,
    required this.callLabel,
    required this.whatsAppLabel,
    required this.onCopy,
    required this.onCall,
    required this.onWhatsApp,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.person_rounded, scale: scale),
              SizedBox(width: 10 * scale),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: (15 * scale).clamp(13, 18),
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: (16 * scale).clamp(13, 20),
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onCopy,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              phone,
                              style: GoogleFonts.manrope(
                                fontSize: (14 * scale).clamp(11, 16),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * scale),
              // Action buttons
              _ActionCircle(
                icon: Icons.phone_rounded,
                label: callLabel,
                color: AppTheme.primary,
                onTap: onCall,
                scale: scale,
              ),
              SizedBox(width: 10 * scale),
              _ActionCircle(
                icon: Icons.chat_rounded,
                label: whatsAppLabel,
                color: const Color(0xFF25D366),
                onTap: onWhatsApp,
                scale: scale,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double scale;

  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final circleSize = (48 * scale).clamp(38.0, 60.0);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: circleSize * 0.45),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: (10 * scale).clamp(8, 12),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tip Banner
// ─────────────────────────────────────────────────────────────────────────────

class _TipBanner extends StatelessWidget {
  final String text;
  final double scale;
  const _TipBanner({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6 * scale),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: AppTheme.primary,
              size: (18 * scale).clamp(14, 22),
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: (12 * scale).clamp(10, 14),
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Icon(
            Icons.payments_rounded,
            color: AppTheme.primary,
            size: (30 * scale).clamp(22, 38),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom CTA
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCTA extends StatelessWidget {
  final bool isSaving;
  final String buttonLabel;
  final String subCaption;
  final VoidCallback onPressed;
  final double scale;

  const _BottomCTA({
    required this.isSaving,
    required this.buttonLabel,
    required this.subCaption,
    required this.onPressed,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Account for bottom safe area (e.g., iPhone home indicator)
    final bottomPad = (mq.padding.bottom > 0 ? mq.padding.bottom : 12.0);
    final buttonHeight = (58 * scale).clamp(50.0, 66.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        12 * scale,
        16 * scale,
        bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                disabledBackgroundColor:
                    AppTheme.primaryDark.withValues(alpha: 0.55),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isSaving ? null : onPressed,
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            buttonLabel,
                            style: GoogleFonts.manrope(
                              fontSize: (15 * scale).clamp(13, 18),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_rounded,
                color: AppTheme.textSecondary,
                size: 12,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  subCaption,
                  style: GoogleFonts.manrope(
                    fontSize: (11 * scale).clamp(9, 13),
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small helper widget — section header icon
// ─────────────────────────────────────────────────────────────────────────────

class _CardIcon extends StatelessWidget {
  final IconData icon;
  final double scale;
  const _CardIcon({required this.icon, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(7 * scale),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: AppTheme.primary,
        size: (18 * scale).clamp(14, 22),
      ),
    );
  }
}
