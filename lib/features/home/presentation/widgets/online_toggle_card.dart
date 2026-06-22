import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/shared_widgets.dart';

class OnlineToggleCard extends StatefulWidget {
  final bool isOnline;
  final Future<void> Function(bool) onToggle;

  const OnlineToggleCard({super.key, required this.isOnline, required this.onToggle});

  @override
  State<OnlineToggleCard> createState() => _OnlineToggleCardState();
}

class _OnlineToggleCardState extends State<OnlineToggleCard> {
  bool _isLoading = false;

  void _handleToggle(bool newValue) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await widget.onToggle(newValue);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: widget.isOnline
            ? const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0xFF374151), Color(0xFF6B7280)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.isOnline ? AppTheme.primary : AppTheme.textSecondary).withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // Background decor
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Positioned(
            left: -20, bottom: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)),
            ),
          ),
          // Content
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading ? 0.6 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Status icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.isOnline) const PulsingDot(color: Colors.white, size: 12),
                        Icon(
                          widget.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: Colors.white, size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isOnline ? context.t('youAreOnline') : context.t('youAreOffline'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          widget.isOnline
                              ? 'Instant pickups are active with live GPS.'
                              : 'Go online only when GPS is on for instant pickups.',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Toggle switch
                  _OnlineSwitch(
                    value: widget.isOnline, 
                    isLoading: _isLoading,
                    onChanged: _handleToggle,
                  ),
                ],
              ),
            ),
          ),
          
          // Full Card Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnlineSwitch extends StatelessWidget {
  final bool value;
  final bool isLoading;
  final Function(bool) onChanged;
  const _OnlineSwitch({required this.value, required this.isLoading, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 56, height: 30,
        decoration: BoxDecoration(
          color: value ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22, height: 22,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
            child: isLoading 
              ? const SizedBox.shrink() // Hide tiny spinner, using full card overlay now
              : Icon(
                  value ? Icons.check_rounded : Icons.close_rounded,
                  size: 12, color: value ? AppTheme.primary : AppTheme.offlineGray),
          ),
        ),
      ),
    );
  }
}
