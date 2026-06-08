import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../main/presentation/main_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream:
          FirebaseFirestore.instance
              .collection('partners')
              .doc(uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['status'] == 'approved') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                );
              }
            });
          }
        }

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await PartnerProvider().loadPartner();
                      if (PartnerProvider().isApproved && mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(),
                          ),
                        );
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 2),
                                // Animated icon
                                _AnimatedCheckIcon(),
                                const SizedBox(height: 32),
                                const Text(
                                  'Account Under\nVerification',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Our team is reviewing your details. You\'ll be notified via SMS within 24–48 hours once approved.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Steps
                                ..._steps.map((s) => _buildStep(s[0], s[1], s[2] == '1')),
                                const Spacer(flex: 2),
                                // Contact support
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.support_agent_rounded),
                                    label: const Text('Contact Support'),
                                    onPressed: () async {
                                      final uri = Uri.parse(
                                        'https://wa.me/918744081962?text=Hi, I registered on Scrapwell Partner and my account is pending verification.',
                                      );
                                      try {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } catch (_) {
                                        final webUri = Uri.parse(
                                          'https://api.whatsapp.com/send?phone=918744081962&text=Hi, I registered on Scrapwell Partner and my account is pending verification.',
                                        );
                                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: const BorderSide(
                                        color: AppTheme.primary,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () async {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Checking status...'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    await PartnerProvider().loadPartner();
                                    if (PartnerProvider().isApproved && mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const MainScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Refresh Status',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

  static const _steps = [
    ['1', 'Registration Submitted', '1'],
    ['2', 'Document Verification (24–48h)', '0'],
    ['3', 'Account Activated', '0'],
  ];

  Widget _buildStep(String num, String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done ? AppTheme.primary : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  done
                      ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                      : Text(
                        num,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: done ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCheckIcon extends StatefulWidget {
  @override
  State<_AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<_AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.hourglass_empty_rounded,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
}
