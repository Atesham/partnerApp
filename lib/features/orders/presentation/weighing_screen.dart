import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/log_utils.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../main/presentation/main_screen.dart';

class WeighingScreen extends StatefulWidget {
  final OrderModel order;
  const WeighingScreen({super.key, required this.order});

  @override
  State<WeighingScreen> createState() => _WeighingScreenState();
}

class _WeighingEntry {
  String category;
  double weight;
  double rate;
  final double customerRate; // The original rate from order — read-only
  final TextEditingController weightCtrl;

  _WeighingEntry({required this.category, required this.weight, required this.rate, required this.customerRate})
      : weightCtrl = TextEditingController(text: weight > 0 ? weight.toString() : '');

  // Always uses the customer's original rate for payout calculation
  double get total => weight * customerRate;

  void dispose() {
    weightCtrl.dispose();
  }
}

class _WeighingScreenState extends State<WeighingScreen> {
  final _orders = OrderProvider();
  late List<_WeighingEntry> _entries;
  bool _isSubmitting = false;
  XFile? _weighingPhoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _entries = widget.order.scrapItems.map((item) {
      // Prefer actual recorded weight if available, else estimated
      final w = item.actualWeight > 0 ? item.actualWeight : item.estimatedWeight;
      // The canonical rate is what the customer booked at — never editable
      final customerRate = item.estimatedRate > 0 ? item.estimatedRate : item.actualRate;
      return _WeighingEntry(
        category: item.category,
        weight: w,
        rate: customerRate,
        customerRate: customerRate,
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final e in _entries) e.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (photo != null) {
        setState(() {
          _weighingPhoto = photo;
        });
      }
    } catch (e) {
      debugLog('Error picking image: $e');
    }
  }

  double get _totalPayout => _entries.fold(0, (sum, e) => sum + e.total);

  // Commission = 2% of total payout
  double get _commission => _totalPayout * 0.02;
  double get _paidToCustomer => _totalPayout - _commission;

  Future<void> _submit() async {
    if (_weighingPhoto == null) {
      AppTheme.showSnack(context, context.t('photoRequiredError'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    String? photoUrl;
    try {
      photoUrl = await SupabaseStorageService.uploadImage(_weighingPhoto!);
    } catch (e) {
      debugLog('Supabase upload failed: $e');
    }

    final items = widget.order.scrapItems.asMap().entries.map((entry) {
      final e = _entries[entry.key];
      final item = entry.value;
      item.actualWeight = e.weight;
      item.actualRate = e.customerRate; // always use the customer's booked rate
      return item;
    }).toList();

    final ok = await _orders.submitFinalPricing(
      widget.order.orderId, items, _totalPayout,
      weighingPhotoUrl: photoUrl,
    );

    if (!mounted) return;
    setState(() { _isSubmitting = false; });

    if (ok) {
      final updated = (OrderProvider().completedOrders.where((o) => o.orderId == widget.order.orderId).firstOrNull) ?? widget.order;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _FinalConfirmationScreen(
            order: updated,
            payout: _totalPayout,
            commission: _commission,
            paidToCustomer: _paidToCustomer,
            entries: _entries,
          ),
        ),
      );
    } else {
      AppTheme.showSnack(context, 'Failed to submit pricing. Try again.', isError: true);
    }
  }

  void _updateEntry(int i, {double? weight}) {
    setState(() {
      if (weight != null) _entries[i].weight = weight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(context.t('enterWeights'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info header
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              context.t('enterWeights') + '. ' + context.t('customerRate') + ' ' + context.t('originalRate') + '.',
                              style: const TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Column headers
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(context.t('scrapDetails'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                              Expanded(flex: 2, child: Text(context.t('weight'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text(context.t('total'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),

                        // Entries
                        ...List.generate(_entries.length, (i) => _buildEntry(i)),

                        // Separator
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Divider(thickness: 1, color: AppTheme.border),
                        ),

                        // Billing summary card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF059669)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.payments_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(context.t('orderBilling'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(
                                  '${_entries.fold(0.0, (s, e) => s + e.weight).toStringAsFixed(1)} kg',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ]),
                              const SizedBox(height: 14),
                              // Total scrap value
                              _billingRow('${context.t('totalPayout')}', '₹${_totalPayout.toStringAsFixed(0)}', isBold: false),
                              const SizedBox(height: 6),
                              // Commission
                              _billingRow('${context.t('commissionLabel')}', '− ₹${_commission.toStringAsFixed(0)}', color: Colors.orange.shade200),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: Colors.white24, thickness: 1),
                              ),
                              // Paid to customer (big)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(context.t('paidToCustomer'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                                  Text('₹${_paidToCustomer.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildPhotoSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Submit button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: GradientButton(
                    label: context.t('confirmPickup'),
                    onPressed: _submit,
                    isLoading: _isSubmitting,
                    icon: Icons.send_rounded,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _billingRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700)),
      ],
    );
  }

  Widget _buildEntry(int i) {
    final entry = _entries[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category + customer rate badge
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('₹${entry.total.toStringAsFixed(0)} total',
                    style: TextStyle(fontSize: 11, color: entry.total > 0 ? AppTheme.primary : AppTheme.textHint, fontWeight: FontWeight.w600)),
                ]),
              ),
              // Customer rate read-only badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Text(context.t('customerRate'), style: const TextStyle(fontSize: 9, color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
                  Text('₹${entry.customerRate.toStringAsFixed(0)}/kg',
                    style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Weight input row
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('weight'), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _numField(entry.weightCtrl, '0.0', (v) => _updateEntry(i, weight: v)),
                ]),
              ),
              const SizedBox(width: 16),
              // Total display
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(context.t('total'), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: entry.total > 0 ? AppTheme.primaryLight : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('₹${entry.total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: entry.total > 0 ? AppTheme.primary : AppTheme.textHint)),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String hint, Function(double) onChanged) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        filled: true, fillColor: AppTheme.background,
      ),
      onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(
          color: _weighingPhoto == null ? AppTheme.border : AppTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt_rounded,
                color: _weighingPhoto == null ? AppTheme.textSecondary : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('weighingMachinePhoto'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_weighingPhoto != null)
                const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t('takeWeighingPhoto'),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, style: BorderStyle.solid, width: 1.5),
              ),
              child: _weighingPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 40, color: AppTheme.textHint),
                        const SizedBox(height: 8),
                        Text(
                          context.t('tapToSelect'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FutureBuilder<Uint8List>(
                              future: _weighingPhoto!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cached_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.t('retry'),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Final Confirmation Screen ─────────────────────────────────────────────

class _FinalConfirmationScreen extends StatefulWidget {
  final OrderModel order;
  final double payout;
  final double commission;
  final double paidToCustomer;
  final List<_WeighingEntry> entries;
  const _FinalConfirmationScreen({
    required this.order,
    required this.payout,
    required this.commission,
    required this.paidToCustomer,
    required this.entries,
  });

  @override
  State<_FinalConfirmationScreen> createState() => _FinalConfirmationScreenState();
}

class _FinalConfirmationScreenState extends State<_FinalConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final yourEarnings = widget.payout - widget.commission;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Success icon
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text(context.t('pickupComplete'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(context.t('customerPaidConfirmed'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 28),

              // ── Scrap breakdown ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTheme.subtleShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.recycling_rounded, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(context.t('scrapBreakdown'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 14),
                    ...widget.entries.asMap().entries.map((e) {
                      final entry = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(entry.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                Text('${entry.weight.toStringAsFixed(1)} kg × ₹${entry.customerRate.toStringAsFixed(0)}/kg',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ]),
                            ),
                            Text('₹${entry.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Billing summary ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF059669)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(context.t('paymentSummary'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 14),
                    _summaryRow(context.t('totalPayout'), '₹${widget.payout.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    _summaryRow(context.t('commissionLabel'), '− ₹${widget.commission.toStringAsFixed(0)}', valueColor: Colors.orange.shade200),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white24, thickness: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.t('paidToCustomer'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('₹${widget.paidToCustomer.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.t('yourEarnings'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('₹${yourEarnings.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              GradientButton(
                label: 'Back to Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                    (route) => false,
                  );
                },
                icon: Icons.home_rounded,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
