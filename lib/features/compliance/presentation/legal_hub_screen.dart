import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import 'policy_detail_screen.dart';

class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.t('legalCompliance')),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Legal header
              Text(
                context.t('legalCompliance'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Localizations.localeOf(context).languageCode == 'hi'
                    ? 'स्क्रैपवेल नीति, नियम और नियामक अनुपालन केंद्र।'
                    : 'Scrapwell policies, terms, and regulatory compliance center.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Category 1: Business Relationship
              _buildCategoryCard(
                context,
                title: context.t('businessRelationship'),
                icon: Icons.business_center_rounded,
                color: AppTheme.primary,
                items: [
                  _PolicyLink('partnerTerms', 'terms'),
                  _PolicyLink('partnerCodeOfConduct', 'conduct'),
                  _PolicyLink('leadOwnershipPolicy', 'lead_ownership'),
                  _PolicyLink('antiCircumventionPolicy', 'anti_circumvention'),
                  _PolicyLink('commissionSettlementPolicy', 'commission_settlement'),
                  _PolicyLink('rateWeightCompliancePolicy', 'rate_weight'),
                ],
              ),
              const SizedBox(height: 16),

              // Category 2: Safety & Operations
              _buildCategoryCard(
                context,
                title: context.t('safetyOperations'),
                icon: Icons.shield_rounded,
                color: AppTheme.error,
                items: [
                  _PolicyLink('safetyPolicy', 'safety'),
                  _PolicyLink('pickupGuidelines', 'pickup_guidelines'),
                  _PolicyLink('customerInteractionPolicy', 'customer_interaction'),
                  _PolicyLink('communityStandards', 'community_standards'),
                ],
              ),
              const SizedBox(height: 16),

              // Category 3: Privacy & Compliance
              _buildCategoryCard(
                context,
                title: context.t('privacyCompliance'),
                icon: Icons.lock_rounded,
                color: AppTheme.warning,
                items: [
                  _PolicyLink('privacyPolicy', 'privacy'),
                  _PolicyLink('dataRetentionPolicy', 'data_retention'),
                  _PolicyLink('aadhaarHandlingPolicy', 'aadhaar_handling'),
                  _PolicyLink('accountDeletionPolicy', 'account_deletion'),
                ],
              ),
              const SizedBox(height: 16),

              // Category 4: Support
              _buildCategoryCard(
                context,
                title: context.t('support'),
                icon: Icons.support_agent_rounded,
                color: AppTheme.info,
                items: [
                  _PolicyLink('grievanceRedressalPolicy', 'grievance'),
                  _PolicyLink('disputeResolutionPolicy', 'dispute'),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<_PolicyLink> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        iconColor: AppTheme.textSecondary,
        collapsedIconColor: AppTheme.textSecondary,
        shape: const Border(), // Removes bottom/top borders of ExpansionTile
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: items.map((item) {
          return ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PolicyDetailScreen(
                    policyKey: item.key,
                    title: context.t(item.labelKey),
                  ),
                ),
              );
            },
            title: Text(
              context.t(item.labelKey),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textHint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          );
        }).toList(),
      ),
    );
  }
}

class _PolicyLink {
  final String labelKey;
  final String key;
  const _PolicyLink(this.labelKey, this.key);
}
