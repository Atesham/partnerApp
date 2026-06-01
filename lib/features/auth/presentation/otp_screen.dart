import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../registration/presentation/registration_screen.dart';
import '../../registration/presentation/pending_approval_screen.dart';
import '../../main/presentation/main_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String verificationId;
  const OtpScreen({super.key, required this.phone, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;
  int _resendTimer = 30;
  bool _canResend = false;

  // Animations
  late AnimationController _entryCtrl;
  late AnimationController _timerCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _successCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _headerScaleAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _successScaleAnim;

  @override
  void initState() {
    super.initState();

    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _headerScaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Circular timer
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();

    // Shake on error
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    // Success burst
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );

    _timerCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _canResend = true);
      }
    });

    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendTimer <= 0) return false;
      setState(() => _resendTimer--);
      return true;
    });
  }

  void _shakeOnError() {
    _shakeCtrl.reset();
    _shakeCtrl.forward();
  }

  Future<void> _verify(String otp) async {
    if (otp.length != 6) return;
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });

    try {
      final credential = await AuthService.instance.verifyOtp(otp);
      if (!mounted || credential == null) return;

      final uid = credential.user?.uid;
      if (uid == null) {
        setState(() { _isLoading = false; _error = 'Authentication failed'; });
        _shakeOnError();
        return;
      }

      // Show success state before navigating
      setState(() { _isLoading = false; _isSuccess = true; });
      await _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final isRegistered = await AuthService.instance.isPartnerRegistered(uid);
      if (!mounted) return;

      if (!isRegistered) {
        _navigateKeepStack(const RegistrationScreen());
        return;
      }

      final partner = PartnerProvider();
      await partner.loadPartner();
      if (!mounted) return;

      if (partner.isApproved) {
        partner.listenToPartner();
        _navigateClearStack(const MainScreen());
      } else {
        _navigateClearStack(const PendingApprovalScreen());
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Verification failed';
      if (e.code == 'invalid-verification-code') msg = context.t('invalidOtp');
      if (e.code == 'session-expired') msg = context.t('otpExpired');
      setState(() { _isLoading = false; _error = msg; });
      _shakeOnError();
      _otpController.clear();
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
      _shakeOnError();
    }
  }

  void _navigateKeepStack(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateClearStack(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _canResend = false;
      _resendTimer = 30;
      _error = null;
    });
    _otpController.clear();
    _timerCtrl.reset();
    _timerCtrl.forward();
    _startCountdown();

    await AuthService.instance.sendOtp(
      phoneNumber: widget.phone,
      onCodeSent: (vId, _) {
        if (mounted) AppTheme.showSnack(context, 'OTP resent!', isSuccess: true);
      },
      onError: (err) {
        if (mounted) AppTheme.showSnack(context, err, isError: true);
      },
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _entryCtrl.dispose();
    _timerCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Decorative Header ─────────────────────────────────────
          _buildHeader(context),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(context),
                      const SizedBox(height: 36),
                      _buildOtpSection(),
                      const SizedBox(height: 28),
                      _buildResendSection(context),
                      const SizedBox(height: 32),
                      _buildVerifyButton(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ScaleTransition(
      scale: _headerScaleAnim,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -40, right: -30,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: 20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Back button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),

            // Center content
            Align(
              alignment: const Alignment(0, 0.3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shield / OTP icon with glow ring
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryMint.withValues(alpha: 0.4),
                          blurRadius: 24, spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'OTP Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to\n'),
              TextSpan(
                text: widget.phone,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Wrong number?',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpSection() {
    // Shake offset based on animation
    final shakeOffset = _shakeAnim.value == 0
        ? 0.0
        : math.sin(_shakeAnim.value * math.pi * 4) * 10;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(shakeOffset, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enter Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              if (_isSuccess)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 13),
                    SizedBox(width: 4),
                    Text('Verified', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          CustomOtpInput(
            controller: _otpController,
            length: 6,
            isError: _error != null,
            isSuccess: _isSuccess,
            isLoading: _isLoading,
            onCompleted: _verify,
          ),

          // Error message
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: AppTheme.error, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildResendSection(BuildContext context) {
    return Center(
      child: _canResend
          ? GestureDetector(
              onTap: _resend,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    context.t('resendOtp'),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: context.t('resendIn')),
                      TextSpan(
                        text: ' ${_resendTimer}s',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
    if (_isSuccess) {
      return ScaleTransition(
        scale: _successScaleAnim,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Verified!',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return GradientButton(
      label: context.t('verifyOtp'),
      onPressed: () => _verify(_otpController.text),
      isLoading: _isLoading,
      icon: Icons.shield_rounded,
    );
  }
}

// ── Custom OTP Input ────────────────────────────────────────────────────────

class CustomOtpInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final bool isError;
  final bool isSuccess;
  final bool isLoading;
  final TextEditingController? controller;

  const CustomOtpInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.isError = false,
    this.isSuccess = false,
    this.isLoading = false,
    this.controller,
  });

  @override
  State<CustomOtpInput> createState() => _CustomOtpInputState();
}

class _CustomOtpInputState extends State<CustomOtpInput> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.length, (index) => FocusNode());
    _controllers = List.generate(widget.length, (index) => TextEditingController());
    
    if (widget.controller != null) {
      widget.controller!.addListener(_handleExternalControllerChange);
    }
  }
  
  void _handleExternalControllerChange() {
    if (widget.controller!.text.isEmpty) {
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    if (widget.controller != null) {
      widget.controller!.removeListener(_handleExternalControllerChange);
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length > 1) {
      final pastedText = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < pastedText.length && index + i < widget.length; i++) {
        _controllers[index + i].text = pastedText[i];
      }
      final nextIndex = index + pastedText.length;
      if (nextIndex < widget.length) {
        _focusNodes[nextIndex].requestFocus();
      } else {
        _focusNodes.last.unfocus();
        _checkCompletion();
      }
    } else if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _checkCompletion();
      }
    }
    _updateExternalController();
  }
  
  void _updateExternalController() {
    if (widget.controller != null) {
      String otp = _controllers.map((c) => c.text).join();
      if (widget.controller!.text != otp) {
        widget.controller!.text = otp;
      }
    }
  }

  void _checkCompletion() {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == widget.length) {
      widget.onCompleted(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return _buildDigitBox(index);
      }),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 52,
      height: 64,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
              _controllers[index - 1].clear();
              _updateExternalController();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _focusNodes[index],
          builder: (context, child) {
            final isFocused = _focusNodes[index].hasFocus;
            final hasValue = _controllers[index].text.isNotEmpty;
            
            Color borderColor = AppTheme.border;
            Color bgColor = Colors.white;
            double borderWidth = 1.5;
            Color textColor = AppTheme.textPrimary;
            List<BoxShadow>? shadows;
            
            if (widget.isError) {
              borderColor = AppTheme.error;
              bgColor = const Color(0xFFFEF2F2);
              textColor = AppTheme.error;
            } else if (widget.isSuccess) {
              borderColor = AppTheme.primary;
              bgColor = AppTheme.primaryLight;
              textColor = AppTheme.primary;
              borderWidth = 2;
            } else if (isFocused) {
              borderColor = AppTheme.primary;
              borderWidth = 2.5;
              shadows = [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ];
            } else if (hasValue) {
              bgColor = AppTheme.primaryLight;
              borderColor = AppTheme.primary.withValues(alpha: 0.4);
            } else {
              shadows = [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ];
            }

            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                readOnly: widget.isLoading || widget.isSuccess,
                autofocus: index == 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 0,
                ),
                maxLength: 6,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => _onChanged(value, index),
              ),
            );
          },
        ),
      ),
    );
  }
}
