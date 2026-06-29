import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../language/presentation/language_selection_screen.dart';
import '../../compliance/presentation/policy_detail_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _phoneController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PolicyDetailScreen(
              policyKey: 'terms',
              title: context.t('termsAndConditions'),
            ),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PolicyDetailScreen(
              policyKey: 'privacy',
              title: context.t('privacyPolicy'),
            ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final phone = '+91${_phoneController.text.trim()}';

    await AuthService.instance.sendOtp(
      phoneNumber: phone,
      onCodeSent: (vId, token) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(phone: phone, verificationId: vId),
          ),
        );
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppTheme.showSnack(context, err, isError: true);
      },
    );
  }

  void _navigateBack() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _navigateBack();
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textPrimary,
              ),
              onPressed: _navigateBack,
            ),
          ),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Logo
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.recycling_rounded,
                                color: AppTheme.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scrapwell',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'PARTNER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          context.t('enterPhone'),
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontSize: 28, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.t('loginSubtitle'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 36),

                        // Country + Phone input
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Country prefix
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: AppTheme.border,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  '+91',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              // Phone number field
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.t('phoneHint'),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return context.t('phoneRequired');
                                    if (v.length < 10)
                                      return context.t('phoneInvalid');
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        RichText(
                          text: TextSpan(
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: context.t('agreePrefix'),
                              ),
                              TextSpan(
                                text: context.t('termsAndConditions'),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              TextSpan(text: context.t('andText')),
                              TextSpan(
                                text: context.t('privacyPolicy'),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        GradientButton(
                          label: context.t('continueBtn'),
                          onPressed: _sendOtp,
                          isLoading: _isLoading,
                          icon: Icons.arrow_forward_rounded,
                        ),

                        const SizedBox(height: 40),
                        // Partner benefits
                        _buildBenefits(context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefits(BuildContext context) {
    final benefits = [
      (Icons.payments_rounded, context.t('benefitEarn')),
      (Icons.flash_on_rounded, context.t('benefitAccept')),
      (Icons.security_rounded, context.t('benefitSecure')),
    ];
    return Column(
      children:
          benefits
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(b.$1, color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        b.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}
