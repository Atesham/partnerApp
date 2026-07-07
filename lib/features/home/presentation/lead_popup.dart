import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/partner_model.dart';
import '../../../core/services/lead_service.dart';
import '../../../core/utils/location_utils.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';


class LeadPopup extends StatefulWidget {
  final OrderModel order;
  final PartnerModel partner;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const LeadPopup({
    super.key, required this.order, required this.partner,
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
  Timer? _vibrateTimer;
  late final AudioPlayer _audioPlayer;
  int _secondsLeft = 120;
  bool _isAccepting = false;
  bool _responded = false;
  StreamSubscription<DocumentSnapshot>? _orderSub;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    _audioPlayer = AudioPlayer();
    _startAlerts();

    final expires = widget.order.expiresAt;
    if (expires != null) {
      _secondsLeft = expires.difference(DateTime.now()).inSeconds.clamp(0, 120);
    } else {
      _secondsLeft = 120;
    }

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

    _listenToOrderStatus();
  }

  void _startAlerts() async {
    // Start repeating vibration alert
    _startVibrationAlert();
    
    // Play loopable local lead sound
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('ringtone/crisp-fast-two-sec-1-1782943688959_ogLriGsj.wav'));
    } catch (e) {
      debugPrint('Error playing lead popup ringtone: $e');
    }
  }

  /// Repeating vibration pattern — fires every 2.5 seconds until dismissed.
  void _startVibrationAlert() {
    _triggerVibration();
    _vibrateTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted || _responded) {
        _vibrateTimer?.cancel();
        return;
      }
      _triggerVibration();
    });
  }

  void _triggerVibration() {
    // Heavy impact followed by medium impact — mimics Rapido double-pulse
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  void _stopAlert() {
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  void _listenToOrderStatus() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.orderId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final status = doc.data()?['status'];
        final partnerId = doc.data()?['partnerId'];
        if (status != 'searchingPartner' && partnerId != uid && !_responded) {
          _responded = true;
          _timer.cancel();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          AppTheme.showSnack(context, 'Order was accepted by another partner.', isError: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _timer.cancel();
    _stopAlert();
    try {
      _audioPlayer.dispose();
    } catch (_) {}
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_responded) return;
    _responded = true;
    _timer.cancel();
    _stopAlert();

    setState(() => _isAccepting = true);

    final ok = await LeadService.instance.acceptOrder(widget.order, widget.partner);

    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (ok) {
      widget.onAccepted();
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: widget.order.orderId),
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
    _stopAlert();
    widget.onDeclined();
    Navigator.pop(context);
  }

  void _autoDecline() {
    _timer.cancel();
    _stopAlert();
    widget.onDeclined();
    Navigator.pop(context);
  }

  double get _progress => _secondsLeft / 120.0;

  @override
  Widget build(BuildContext context) {
    final scrapCategories = widget.order.allScrapCategories;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, -10)),
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
                      _detailRow(Icons.location_on_rounded, 'Location', widget.order.customerAddress, AppTheme.error),
                      const SizedBox(height: 12),
                      // Distance
                      _detailRow(
                        Icons.social_distance_rounded,
                        'Distance',
                        '~${LocationUtils.calculateDistance(
                          widget.partner.currentLat != 0.0 ? widget.partner.currentLat : widget.partner.shopLat,
                          widget.partner.currentLng != 0.0 ? widget.partner.currentLng : widget.partner.shopLng,
                          widget.order.customerLat,
                          widget.order.customerLng,
                        ).toStringAsFixed(1)} km from your location',
                        AppTheme.info,
                      ),
                      const SizedBox(height: 12),
                      // Estimated value
                      _detailRow(Icons.payments_rounded, 'Estimated Value', '₹${widget.order.estimatedPayout.toStringAsFixed(0)}', AppTheme.primary),
                      const SizedBox(height: 12),
                      // Weight
                      _detailRow(Icons.scale_rounded, 'Approx Weight', '~${widget.order.totalEstimatedWeight.toStringAsFixed(0)} kg', AppTheme.warning),
                      const SizedBox(height: 12),
                      // Slot
                      _detailRow(Icons.schedule_rounded, 'Pickup Slot', widget.order.pickupSlot, AppTheme.textSecondary),

                      const SizedBox(height: 14),

                      // Categories
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: scrapCategories.map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(c, style: const TextStyle(color: AppTheme.primaryDark, fontSize: 13, fontWeight: FontWeight.w700)),
                        )).toList(),
                      ),

                      if (widget.order.customerNotes != null && widget.order.customerNotes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(widget.order.customerNotes!,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                      ],

                      if (widget.order.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Scrap Photos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.order.imageUrls.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: CachedNetworkImage(
                                          imageUrl: widget.order.imageUrls[idx],
                                          fit: BoxFit.contain,
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(color: AppTheme.primary),
                                          ),
                                          errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.order.imageUrls[idx],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 80,
                                        height: 80,
                                        color: AppTheme.border.withOpacity(0.3),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 80,
                                        height: 80,
                                        color: AppTheme.border,
                                        child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
          ),
          Text('$seconds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
