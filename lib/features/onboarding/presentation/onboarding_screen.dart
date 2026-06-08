import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../auth/presentation/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final List<_OBData> _pages = const [
    _OBData(
      titleKey: 'onb1Title', bodyKey: 'onb1Body',
      gradient: [Color(0xFF064E3B), Color(0xFF047857)],
      stat: '₹850 avg/day', statSub: 'per active partner',
      accentIcon: Icons.trending_up_rounded,
      type: _IlluType.earnings,
    ),
    _OBData(
      titleKey: 'onb2Title', bodyKey: 'onb2Body',
      gradient: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
      stat: '< 5 sec', statSub: 'to accept a request',
      accentIcon: Icons.notifications_active_rounded,
      type: _IlluType.incoming,
    ),
    _OBData(
      titleKey: 'onb3Title', bodyKey: 'onb3Body',
      gradient: [Color(0xFF422006), Color(0xFFB45309)],
      stat: '100% digital', statSub: 'weighing & payment',
      accentIcon: Icons.check_circle_rounded,
      type: _IlluType.pickup,
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          _controller.previousPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        }
        // On page 0, do nothing (block back)
      },
      child: Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => _OBPage(data: _pages[i]),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 12),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    child: Text(context.t('skip'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                  ),
                ),
                child: Row(
                  children: [
                    SmoothPageIndicator(
                      controller: _controller, count: _pages.length,
                      effect: ExpandingDotsEffect(
                        dotColor: Colors.white.withOpacity(0.35),
                        activeDotColor: Colors.white,
                        dotHeight: 8, dotWidth: 8,
                        expansionFactor: 3.5, spacing: 5,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDeep,
                        minimumSize: isLast ? const Size(160, 52) : const Size(52, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isLast ? 16 : 50)),
                        elevation: 0, padding: EdgeInsets.zero,
                      ),
                      child: isLast
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const SizedBox(width: 16),
                              Text(context.t('getStarted'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                              const SizedBox(width: 12),
                            ])
                          : const Icon(Icons.arrow_forward_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _OBPage extends StatelessWidget {
  final _OBData data;
  const _OBPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: data.gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _circle(280, 0.05)),
          Positioned(top: 200, left: -80, child: _circle(180, 0.04)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Expanded(flex: 5, child: Center(child: _buildIllu(data.type))),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(data.accentIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(data.stat, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Text('· ${data.statSub}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        Text(context.t(data.titleKey),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
                        const SizedBox(height: 12),
                        Text(context.t(data.bodyKey),
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.6)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildIllu(_IlluType type) {
    switch (type) {
      case _IlluType.earnings: return _EarningsCard();
      case _IlluType.incoming: return _IncomingCard();
      case _IlluType.pickup: return _WeighingCard();
    }
  }
}

class _EarningsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _iconBox(Icons.account_balance_wallet_rounded),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Today's Earnings", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            const Text("₹1,240", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _mini('Orders', '6'), _mini('Avg', '₹207'), _mini('Online', '4.5h'),
        ]),
      ]),
    );
  }
  Widget _iconBox(IconData icon) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: Colors.white, size: 22),
  );
  Widget _mini(String l, String v) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    Text(l, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
  ]);
}

class _IncomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notification_important_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("New Request!", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            const Text("2.3 km away", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Text("25s", style: TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        const SizedBox(height: 12),
        const Text("Paper · Plastic · Metal", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Container(height: 38,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text("Decline", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13))))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 38,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text("Accept", style: TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.w800, fontSize: 13))))),
        ]),
      ]),
    );
  }
}

class _WeighingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Weighing Screen", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _row('Paper', '12 kg', '₹14', '₹168'),
        const SizedBox(height: 6),
        _row('Plastic', '8 kg', '₹10', '₹80'),
        const SizedBox(height: 6),
        _row('Metal', '5 kg', '₹30', '₹150'),
        const Divider(color: Colors.white24, height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Total", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const Text("₹398", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ]),
    );
  }
  Widget _row(String c, String w, String r, String t) => Row(children: [
    Expanded(flex: 3, child: Text(c, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11))),
    Expanded(flex: 2, child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 11))),
    Expanded(flex: 2, child: Text(r, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11))),
    Expanded(flex: 2, child: Text(t, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
  ]);
}

enum _IlluType { earnings, incoming, pickup }

class _OBData {
  final String titleKey, bodyKey;
  final List<Color> gradient;
  final String stat, statSub;
  final IconData accentIcon;
  final _IlluType type;
  const _OBData({required this.titleKey, required this.bodyKey, required this.gradient, required this.stat, required this.statSub, required this.accentIcon, required this.type});
}
