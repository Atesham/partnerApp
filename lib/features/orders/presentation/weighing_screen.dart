import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/widgets/shared_widgets.dart';

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
  final TextEditingController weightCtrl;
  final TextEditingController rateCtrl;

  _WeighingEntry({required this.category, required this.weight, required this.rate})
      : weightCtrl = TextEditingController(text: weight > 0 ? weight.toString() : ''),
        rateCtrl = TextEditingController(text: rate > 0 ? rate.toString() : '');

  double get total => weight * rate;

  void dispose() { weightCtrl.dispose(); rateCtrl.dispose(); }
}

class _WeighingScreenState extends State<WeighingScreen> {
  final _orders = OrderProvider();
  late List<_WeighingEntry> _entries;
  bool _isSubmitting = false;
  bool _waitingConfirmation = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.order.scrapItems.map((item) => _WeighingEntry(
      category: item.category,
      weight: item.actualWeight > 0 ? item.actualWeight : item.estimatedWeight,
      rate: item.actualRate > 0 ? item.actualRate : item.estimatedRate,
    )).toList();
  }

  @override
  void dispose() {
    for (final e in _entries) e.dispose();
    super.dispose();
  }

  double get _totalPayout => _entries.fold(0, (sum, e) => sum + e.total);

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final items = widget.order.scrapItems.asMap().entries.map((entry) {
      final e = _entries[entry.key];
      final item = entry.value;
      item.actualWeight = e.weight;
      item.actualRate = e.rate;
      return item;
    }).toList();

    final ok = await _orders.submitFinalPricing(
      widget.order.orderId, items, _totalPayout,
    );

    if (!mounted) return;
    setState(() { _isSubmitting = false; _waitingConfirmation = ok; });

    if (ok) {
      _listenForConfirmation();
    } else {
      AppTheme.showSnack(context, 'Failed to submit pricing. Try again.', isError: true);
    }
  }

  void _listenForConfirmation() {
    // Listen for customer confirmation in real-time
    OrderProvider().addListener(() {
      final updated = OrderProvider().activeOrders
          .where((o) => o.orderId == widget.order.orderId)
          .firstOrNull;
      if (updated != null && updated.customerConfirmed && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _FinalConfirmationScreen(order: updated, payout: _totalPayout),
          ),
        );
      }
    });
  }

  void _updateEntry(int i, {double? weight, double? rate}) {
    setState(() {
      if (weight != null) _entries[i].weight = weight;
      if (rate != null) _entries[i].rate = rate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Enter Scrap Weights', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _waitingConfirmation
          ? _buildWaiting()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Enter actual weight and rate for each category.',
                              style: TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Column headers
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Expanded(flex: 3, child: Text('Category', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                              const Expanded(flex: 2, child: Text('Weight (kg)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                              const Expanded(flex: 2, child: Text('Rate (₹/kg)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                              const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
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

                        // Total
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF064E3B), Color(0xFF059669)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 14),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Total Payout', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('₹${_totalPayout.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                              ]),
                              const Spacer(),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('${_entries.length} items', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('${_entries.fold(0.0, (s, e) => s + e.weight).toStringAsFixed(1)} kg total',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Submit button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: GradientButton(
                    label: 'Confirm & Send to Customer',
                    onPressed: _submit,
                    isLoading: _isSubmitting,
                    icon: Icons.send_rounded,
                  ),
                ),
              ],
            ),
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
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text('₹${entry.total.toStringAsFixed(0)} total', style: TextStyle(fontSize: 11, color: entry.total > 0 ? AppTheme.primary : AppTheme.textHint, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _numField(entry.weightCtrl, 'e.g. 12', (v) => _updateEntry(i, weight: v))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _numField(entry.rateCtrl, 'e.g. 15', (v) => _updateEntry(i, rate: v))),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text('₹${entry.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: entry.total > 0 ? AppTheme.primary : AppTheme.textHint)),
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

  Widget _buildWaiting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 4),
            ),
            const SizedBox(height: 24),
            const Text('Waiting for Customer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('The customer is reviewing the final pricing. Please wait for confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
            const SizedBox(height: 32),
            Text('Total: ₹${_totalPayout.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

// ── Final Confirmation Screen ─────────────────────────────────────────────

class _FinalConfirmationScreen extends StatefulWidget {
  final OrderModel order;
  final double payout;
  const _FinalConfirmationScreen({required this.order, required this.payout});

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated success
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: const Icon(Icons.check_rounded, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Pickup Completed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              const Text('Customer has confirmed the payment.\nYour earnings have been updated.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.6)),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Text('₹${widget.payout.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                  const SizedBox(height: 4),
                  const Text('Added to your earnings', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              ),
              const Spacer(),
              GradientButton(
                label: 'Back to Home',
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                icon: Icons.home_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
