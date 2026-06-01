import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/partner_model.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../orders/presentation/order_tracking_screen.dart';

class LeadPopup extends StatefulWidget {
  final LeadModel lead;
  final PartnerModel partner;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const LeadPopup({
    super.key, required this.lead, required this.partner,
    required this.onAccepted, required this.onDeclined,
  });

  @override
  State<LeadPopup> createState() => _LeadPopupState();
}

class _LeadPopupState extends State<LeadPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  late Timer _timer;
  int _secondsLeft = 30;
  bool _isAccepting = false;
  bool _responded = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    _secondsLeft = widget.lead.secondsRemaining.clamp(0, 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else if (!_responded) {
          _responded = true;
          _autoDecline();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_responded) return;
    _responded = true;
    _timer.cancel();

    setState(() => _isAccepting = true);

    final ok = await LeadService.instance.acceptLead(widget.lead, widget.partner);

    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (ok) {
      widget.onAccepted();
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: widget.lead.orderId),
        ),
      );
    } else {
      AppTheme.showSnack(context, 'Order already taken by another partner', isError: true);
      Navigator.pop(context);
    }
  }

  void _decline() {
    if (_responded) return;
    _responded = true;
    _timer.cancel();
    widget.onDeclined();
    Navigator.pop(context);
  }

  void _autoDecline() {
    _timer.cancel();
    widget.onDeclined();
    Navigator.pop(context);
  }

  double get _progress => _secondsLeft / 30.0;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 40, offset: const Offset(0, -10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                const SizedBox(height: 10),
                Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),

                // Header - NEW REQUEST
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF059669)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notification_important_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('New Pickup Request!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          Text('First to accept wins the order', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ),
                      // Countdown
                      _CountdownCircle(progress: _progress, seconds: _secondsLeft),
                    ],
                  ),
                ),

                // Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location
                      _detailRow(Icons.location_on_rounded, 'Location', widget.lead.customerAddress, AppTheme.error),
                      const SizedBox(height: 12),
                      // Distance
                      _detailRow(Icons.social_distance_rounded, 'Distance', '~2.3 km from your shop', AppTheme.info),
                      const SizedBox(height: 12),
                      // Estimated value
                      _detailRow(Icons.payments_rounded, 'Estimated Value', '₹${widget.lead.estimatedPayout.toStringAsFixed(0)}', AppTheme.primary),
                      const SizedBox(height: 12),
                      // Weight
                      _detailRow(Icons.scale_rounded, 'Approx Weight', '~${widget.lead.estimatedWeight.toStringAsFixed(0)} kg', AppTheme.warning),
                      const SizedBox(height: 12),
                      // Slot
                      _detailRow(Icons.schedule_rounded, 'Pickup Slot', widget.lead.pickupSlot, AppTheme.textSecondary),

                      const SizedBox(height: 14),

                      // Categories
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: widget.lead.scrapCategories.map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(c, style: const TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontWeight: FontWeight.w700)),
                        )).toList(),
                      ),

                      if (widget.lead.customerNotes != null && widget.lead.customerNotes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(widget.lead.customerNotes!,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Decline'),
                          onPressed: _isAccepting ? null : _decline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(0, 52),
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: _isAccepting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Icon(Icons.flash_on_rounded, size: 20),
                          label: Text(_isAccepting ? 'Accepting...' : 'Accept Now'),
                          onPressed: _isAccepting ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(0, 52), elevation: 0,
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
      ],
    );
  }
}

class _CountdownCircle extends StatelessWidget {
  final double progress;
  final int seconds;
  const _CountdownCircle({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final color = progress > 0.5 ? Colors.greenAccent : (progress > 0.25 ? Colors.orangeAccent : Colors.redAccent);
    return SizedBox(
      width: 52, height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
          ),
          Text('$seconds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
