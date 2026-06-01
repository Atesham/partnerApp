import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _selected = 'en';
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<_LangOption> _languages = const [
    _LangOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      symbol: 'A',
      subtitle: 'Continue in English',
    ),
    _LangOption(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिंदी',
      symbol: 'अ',
      subtitle: 'हिंदी में जारी रखें',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = localeNotifier.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await saveLocale(_selected);
    if (!mounted) return;
    
    // If there is no previous route, we navigate to Onboarding
    if (!Navigator.canPop(context)) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const OnboardingScreen(),
          transitionsBuilder: (_, a, __, child) =>
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child,
              ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      // If launched from Profile/Settings, just pop back
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);

    // No PopScope(canPop: false) anymore so device back button works naturally
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  if (canGoBack)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border, width: 1.5),
                          boxShadow: AppTheme.subtleShadow,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 22),
                      ),
                    )
                  else
                    const SizedBox(height: 36),

                  // Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: AppTheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'भाषा चुनें • Choose your preferred language',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Language options
                  ...List.generate(
                    _languages.length,
                    (i) => _buildLangCard(_languages[i]),
                  ),

                  const Spacer(),

                  // Continue button
                  GradientButton(
                    label: _selected == 'hi' ? 'जारी रखें' : 'Continue',
                    onPressed: _continue,
                    icon: Icons.arrow_forward_rounded,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLangCard(_LangOption lang) {
    final isSelected = _selected == lang.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected ? AppTheme.elevatedShadow : AppTheme.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() => _selected = lang.code);
            saveLocale(lang.code);
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Symbol instead of flag
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary.withOpacity(0.15) : AppTheme.background,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lang.symbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppTheme.primaryDark
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected ? AppTheme.primary : const Color(0xFFF3F4F6),
                    border: isSelected
                        ? null
                        : Border.all(color: AppTheme.border, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangOption {
  final String code;
  final String name;
  final String nativeName;
  final String symbol;
  final String subtitle;

  const _LangOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.symbol,
    required this.subtitle,
  });
}
