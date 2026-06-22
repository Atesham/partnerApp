import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/partner_model.dart';
import '../../../../core/utils/location_utils.dart';

class LeadFeedCard extends StatefulWidget {
  final OrderModel order;
  final PartnerModel partner;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  const LeadFeedCard({
    super.key,
    required this.order,
    required this.partner,
    required this.onAccept,
    required this.onIgnore,
  });

  @override
  State<LeadFeedCard> createState() => _LeadFeedCardState();
}

class _LeadFeedCardState extends State<LeadFeedCard>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsLeft = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool get _isInstant => widget.order.pickupType == 'instant';

  @override
  void initState() {
    super.initState();

    // Pulse animation for the instant badge
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (_isInstant && widget.order.expiresAt != null) {
      _secondsLeft =
          widget.order.expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 120);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_secondsLeft > 0) _secondsLeft--;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dist = LocationUtils.calculateDistance(
      widget.partner.currentLat != 0.0
          ? widget.partner.currentLat
          : widget.partner.shopLat,
      widget.partner.currentLng != 0.0
          ? widget.partner.currentLng
          : widget.partner.shopLng,
      widget.order.customerLat,
      widget.order.customerLng,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: _isInstant
              ? AppTheme.primary.withOpacity(0.25)
              : const Color(0xFFF59E0B).withOpacity(0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onAccept,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              // ── Pickup type header strip ────────────────────────────────
              _buildTypeHeader(),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: area + payout ──────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.recycling_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.areaName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _timeAgo(widget.order.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${widget.order.estimatedPayout.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            const Text(
                              'est. payout',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.divider),
                    const SizedBox(height: 14),

                    // ── Detail chips ───────────────────────────────────
                    Row(
                      children: [
                        _chip(
                          Icons.social_distance_rounded,
                          '${dist.toStringAsFixed(1)} km',
                          AppTheme.info,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          Icons.scale_rounded,
                          '~${widget.order.totalEstimatedWeight.toStringAsFixed(0)} kg',
                          AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        // For instant: show countdown, for scheduled: show slot
                        _isInstant
                            ? _countdownChip()
                            : _chip(
                                Icons.schedule_rounded,
                                widget.order.pickupSlot.length > 12
                                    ? 'Scheduled'
                                    : widget.order.pickupSlot,
                                AppTheme.textSecondary,
                              ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Category chips ─────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.order.scrapItems
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: const TextStyle(
                                      color: AppTheme.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Action buttons ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onIgnore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 44),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              'Ignore',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: widget.onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isInstant
                                  ? AppTheme.primary
                                  : const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(0, 44),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isInstant
                                      ? Icons.flash_on_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isInstant ? 'Accept Now' : 'View Details',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top header strip indicating pickup type
  Widget _buildTypeHeader() {
    if (_isInstant) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.12),
              AppTheme.primary.withOpacity(0.04),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: Row(
          children: [
            // Pulsing dot
            FadeTransition(
              opacity: _pulseAnim,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.5),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '⚡ INSTANT PICKUP',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
              const Text(
                'Live GPS + radius',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      // Scheduled header
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 12,
              color: Color(0xFFEA580C),
            ),
            const SizedBox(width: 6),
            const Text(
              'SCHEDULED PICKUP',
              style: TextStyle(
                color: Color(0xFFEA580C),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            const Text(
              'Working hours checked',
              style: TextStyle(
                color: Color(0xFFEA580C),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _countdownChip() {
    final isUrgent = _secondsLeft < 30;
    final color = _secondsLeft > 60
        ? AppTheme.primary
        : (_secondsLeft > 30 ? AppTheme.warning : AppTheme.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_off_rounded : Icons.timer_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _secondsLeft > 0 ? '${_secondsLeft}s' : 'Expired',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
