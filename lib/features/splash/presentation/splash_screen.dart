import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/in_app_update_service.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  @override
  void dispose() {
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

        // After navigating, trigger an in-app update check in the background.
        // The check is fire-and-forget: it won't block or delay navigation.
        // If an update is available, the Play Store downloads it silently and
        // a snackbar appears on the new screen prompting the user to restart.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            InAppUpdateService.instance.checkForUpdate(context);
          }
        });
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
        backgroundColor: AppTheme.primaryDeep, // Matches native launch background color (Color(0xFF064E3B))
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Matches size (280dp) and graphic of native splash
              SizedBox(
                width: 280,
                height: 280,
                child: Image.asset(
                  'assets/icons/app_icon_foreground.png', // White transparent logo
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _friendlyError(_error!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
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
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
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
