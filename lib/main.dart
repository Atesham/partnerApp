import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/providers/partner_provider.dart';
import 'core/services/notification_service.dart';
import 'features/splash/presentation/splash_screen.dart';

import 'features/compliance/presentation/policy_detail_screen.dart';

// Global navigation key to support notification clicks from everywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase on App Launch
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications
  await NotificationService.instance.init(navigatorKey);

  runApp(const ScrapwellPartnerApp());
}

class ScrapwellPartnerApp extends StatelessWidget {
  const ScrapwellPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (context, lang, _) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Assign the global navigator key
          title: 'Scrapwell Partner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: Locale(lang),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/terms': (context) => const PolicyDetailScreen(
                  policyKey: 'terms',
                  title: 'Terms & Conditions',
                ),
            '/privacy': (context) => const PolicyDetailScreen(
                  policyKey: 'privacy',
                  title: 'Privacy Policy',
                ),
          },
        );
      },
    );
  }
}
