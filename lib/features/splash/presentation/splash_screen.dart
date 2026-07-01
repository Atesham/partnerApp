import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../language/presentation/language_selection_screen.dart';
import '../../main/presentation/main_screen.dart';
import '../../registration/presentation/registration_screen.dart';
import '../../registration/presentation/pending_approval_screen.dart';
import '../../auth/presentation/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        Future.delayed(const Duration(milliseconds: 1400)),
        _checkAuthStatus(),
      ]);

      if (!mounted) return;

      final route = results[1];
      if (route is Widget) {
        _push(route);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<Widget> _checkAuthStatus() async {
    await initLocale();

    final prefs = await SharedPreferences.getInstance();
    final hasLanguage = prefs.containsKey('language');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (hasLanguage) {
        return const LoginScreen();
      }
      return const LanguageSelectionScreen();
    }

    final partner = PartnerProvider();
    await partner.loadPartner();

    if (partner.error != null) {
      throw Exception(partner.error);
    }

    await NotificationService.instance.updateFcmToken();

    if (!partner.hasProfile) {
      return const RegistrationScreen();
    } else if (partner.isApproved) {
      partner.listenToPartner();
      return const MainScreen();
    } else {
      return const PendingApprovalScreen();
    }
  }

  void _push(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
        transitionsBuilder:
            (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryDeep,
                Color(0xFF065F46),
                Color(0xFF047857),
                AppTheme.primaryDark,
              ],
              stops: [0.0, 0.34, 0.68, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -90,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -140,
                left: -80,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Center(
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 4),
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Container(
                            width: 132,
                            height: 132,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.28),
                                  blurRadius: 0,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 46,
                left: 28,
                right: 28,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Text(
                            _friendlyError(_error!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _navigate,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryDeep,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ] else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor: Colors.white.withOpacity(0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.92),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Preparing your partner workspace',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('unavailable') ||
        lower.contains('connection')) {
      return 'Connection error. Please check your internet connection.';
    }
    return error;
  }
}
