import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/presentation/login_screen.dart';
import '../../language/presentation/language_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final partner = PartnerProvider();

    return Scaffold(
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
                      // Menu sections
                      _buildSection('Account', [
                        _MenuItem(Icons.edit_rounded, 'Edit Profile', AppTheme.primary, () {}),
                        _MenuItem(Icons.description_rounded, 'Documents', AppTheme.info, () {}),
                        _MenuItem(Icons.star_rate_rounded, 'Ratings & Reviews', AppTheme.warning, () {}),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Preferences', [
                        _MenuItem(Icons.language_rounded, 'Language', AppTheme.primary, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()));
                        }),
                        _MenuItem(Icons.notifications_rounded, 'Notifications', AppTheme.textSecondary, () {}),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Support', [
                        _MenuItem(Icons.help_outline_rounded, 'Help & Support', AppTheme.info, () async {
                          final uri = Uri.parse('https://wa.me/919999999999');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        }),
                        _MenuItem(Icons.privacy_tip_outlined, 'Privacy Policy', AppTheme.textSecondary, () {}),
                        _MenuItem(Icons.article_outlined, 'Terms of Service', AppTheme.textSecondary, () {}),
                      ]),
                      const SizedBox(height: 16),
                      // Logout
                      GestureDetector(
                        onTap: () => _showLogoutDialog(context, partner),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.subtleShadow,
                          ),
                          child: const Row(children: [
                            Icon(Icons.logout_rounded, color: AppTheme.error, size: 22),
                            SizedBox(width: 14),
                            Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.error)),
                            Spacer(),
                            Icon(Icons.chevron_right_rounded, color: AppTheme.error, size: 20),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('ScrapDirect Partner v1.0.0',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context, PartnerProvider partner) {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true, snap: true, elevation: 0,
      title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.textPrimary)),
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
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Center(child: Text(p.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(p.shopName, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(p.phone, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.isApproved ? Colors.white.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                p.isApproved ? '✓ Verified' : '⏳ Pending',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 4),
              Text('4.8', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ]),
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
          child: Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
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
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    title: Text(item.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  if (i < items.length - 1) const Divider(height: 1, indent: 64, color: AppTheme.divider),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout from ScrapDirect Partner?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
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
              backgroundColor: AppTheme.error, minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
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
