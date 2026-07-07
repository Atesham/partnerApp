import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../auth/presentation/login_screen.dart';
import '../../language/presentation/language_selection_screen.dart';
import '../../compliance/presentation/business_profile_screen.dart';
import 'package:flutter/services.dart';
import '../../compliance/presentation/safety_center_screen.dart';
import '../../compliance/presentation/privacy_center_screen.dart';
import '../../compliance/presentation/legal_hub_screen.dart';
import '../../compliance/presentation/about_scrapwell_screen.dart';
import '../../earnings/presentation/earnings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final partner = PartnerProvider();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: ListenableBuilder(
          listenable: partner,
          builder: (_, __) {
            return CustomScrollView(
              slivers: [
                _buildHeader(context, partner),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Partner card
                        _buildPartnerCard(context, partner),
                        const SizedBox(height: 20),

                        // Section 1: Business & Settlements
                        _buildSection(context.t('businessRelationship'), [
                          _MenuItem(
                            Icons.business_center_rounded,
                            context.t('myBusinessProfile'),
                            AppTheme.primary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BusinessProfileScreen(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            Icons.payments_rounded,
                            context.t('earningsSettlements'),
                            AppTheme.success,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EarningsScreen(),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Section 2: Safety & Support
                        _buildSection(context.t('safetyOperations'), [
                          _MenuItem(
                            Icons.security_rounded,
                            context.t('safetyCenter'),
                            AppTheme.error,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SafetyCenterScreen(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            Icons.support_agent_rounded,
                            context.t('helpSupport'),
                            AppTheme.info,
                            () => _launchWhatsAppSupport(context),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Section 3: Privacy, Legal & About
                        _buildSection(context.t('privacyCompliance'), [
                          _MenuItem(
                            Icons.lock_rounded,
                            context.t('privacyData'),
                            AppTheme.warning,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyCenterScreen(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            Icons.gavel_rounded,
                            context.t('legalCompliance'),
                            AppTheme.textSecondary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LegalHubScreen(),
                              ),
                            ),
                          ),
                          _MenuItem(
                            Icons.info_outline_rounded,
                            context.t('aboutScrapwell'),
                            AppTheme.textSecondary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutScrapwellScreen(),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),

                        // Section 4: Preferences
                        _buildSection(context.t('language'), [
                          _MenuItem(
                            Icons.language_rounded,
                            context.t('language'),
                            AppTheme.primary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LanguageSelectionScreen(),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // Logout Button
                        GestureDetector(
                          onTap: () => _showLogoutDialog(context, partner),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.subtleShadow,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.logout_rounded,
                                  color: AppTheme.error,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  context.t('logout'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.error,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.error,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Scrapwell Partner v1.0.0',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _launchWhatsAppSupport(BuildContext context) async {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    const text = 'Hi Scrapwell Support, I am a partner and need assistance.';
    final whatsappUri = Uri.parse(
      'whatsapp://send?phone=+918744081962&text=${Uri.encodeComponent(text)}',
    );

    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw 'Could not launch WhatsApp';
      }
    } catch (_) {
      // Show fallback support dialog box
      if (context.mounted) {
        _showSupportFallbackDialog(context, isHindi);
      }
    }
  }

  void _showSupportFallbackDialog(BuildContext context, bool isHindi) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  isHindi ? 'सहायता केंद्र' : 'Support Desk',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi
                      ? 'आपके डिवाइस पर व्हाट्सएप इंस्टॉल नहीं है। कृपया हमसे सीधे संपर्क करें:'
                      : 'WhatsApp app is not installed on your device. Please connect with us directly:',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      // Call option
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.phone_rounded,
                          color: AppTheme.primary,
                        ),
                        title: const Text(
                          '+91 8744081962',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isHindi
                              ? 'कॉल करने के लिए टैप करें'
                              : 'Tap to call directly',
                        ),
                        onTap: () async {
                          final uri = Uri.parse('tel:+918744081962');
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      // Email option
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.email_rounded,
                          color: AppTheme.primary,
                        ),
                        title: const Text(
                          'support@scrapwell.in',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          isHindi
                              ? 'ईमेल भेजने के लिए टैप करें'
                              : 'Tap to email directly',
                        ),
                        onTap: () async {
                          final uri = Uri.parse(
                            'mailto:support@scrapwell.in?subject=Partner%20Support%20Assistance',
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isHindi ? 'ठीक है' : 'Close'),
              ),
            ],
          ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, PartnerProvider partner) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true,
      snap: true,
      elevation: 0,
      title: Text(
        context.t('myProfile'),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: AppTheme.textPrimary,
        ),
      ),
      titleSpacing: 20,
    );
  }

  Widget _buildPartnerCard(BuildContext context, PartnerProvider partner) {
    final p = partner.partner;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              image:
                  p.profilePhotoUrl.isNotEmpty
                      ? DecorationImage(
                        image: CachedNetworkImageProvider(p.profilePhotoUrl),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                p.profilePhotoUrl.isEmpty
                    ? Center(
                      child: Text(
                        p.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.shopName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.phone,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      p.isApproved
                          ? Colors.white.withOpacity(0.2)
                          : Colors.orangeAccent.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.isApproved
                      ? '✓ ${context.t('approved')}'
                      : '⏳ ${context.t('pending')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    p.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(
                      height: 1,
                      indent: 64,
                      color: AppTheme.divider,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, PartnerProvider partner) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(context.t('logoutConfirm')),
            content: Text(
              context.t('logoutConfirm'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.t('cancel'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await partner.toggleOnline(false);
                  partner.reset();
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.t('logout'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}
