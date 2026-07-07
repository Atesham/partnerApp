import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/models/partner_model.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/shared_widgets.dart';

class VerificationCenterScreen extends StatefulWidget {
  const VerificationCenterScreen({super.key});

  @override
  State<VerificationCenterScreen> createState() =>
      _VerificationCenterScreenState();
}

class _VerificationCenterScreenState extends State<VerificationCenterScreen> {
  final _provider = PartnerProvider();
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

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
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            context.t('verificationCenterTitle'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: _provider,
          builder: (context, _) {
            final p = _provider.partner;

            // Calculate progress out of 4 steps
            int verifiedCount = 0;
            if (p.aadhaarVerified) verifiedCount++;
            if (p.businessInfoVerified) verifiedCount++;
            if (p.bankVerified) verifiedCount++;
            if (p.addressVerified) verifiedCount++;

            final progressPercentage = verifiedCount / 4.0;
            final isAllVerified = verifiedCount == 4;

            return Stack(
              children: [
                ResponsiveWrapper(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Trust Card
                      _buildHeroTrustCard(
                        context,
                        verifiedCount,
                        progressPercentage,
                        isAllVerified,
                        isHindi,
                      ),
                      const SizedBox(height: 24),

                      // Trust Benefits section
                      _buildTrustBenefits(context, isHindi),
                      const SizedBox(height: 28),

                      // Verification Roadmap Title
                      Text(
                        isHindi ? 'सत्यापन रोडमैप' : 'Verification Roadmap',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Roadmap step items
                      _buildRoadmapSteps(context, p, isHindi),
                      const SizedBox(height: 28),

                      // Customer Profile Preview
                      _buildProfilePreview(context, p, isAllVerified, isHindi),
                      const SizedBox(height: 20),

                      // Contact Support Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border, width: 0.5),
                          boxShadow: AppTheme.subtleShadow,
                        ),
                        child: Column(
                          children: [
                            Text(
                              isHindi
                                  ? 'सत्यापन के लिए सहायता चाहिए?'
                                  : 'Need help with verification?',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isHindi
                                  ? 'यदि आपका विवरण लंबित है, तो त्वरित समीक्षा के लिए हमारे व्हाट्सएप समर्थन से संपर्क करें।'
                                  : 'If your details are pending, connect with our support team on WhatsApp for a quick review.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final text = 'approve my details as form is already filled';
                                final whatsappUri = Uri.parse('whatsapp://send?phone=+918744081962&text=${Uri.encodeComponent(text)}');
                                try {
                                  final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                                  if (!launched) {
                                    throw 'Could not launch WhatsApp';
                                  }
                                } catch (_) {
                                  final webUri = Uri.parse('https://api.whatsapp.com/send?phone=918744081962&text=${Uri.encodeComponent(text)}');
                                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF25D366),
                                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
                              label: Text(
                                isHindi ? 'व्हाट्सएप सहायता' : 'WhatsApp Support',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.35),
                    child: const Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 24,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppTheme.primary,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildHeroTrustCard(
    BuildContext context,
    int verifiedCount,
    double progress,
    bool isAllVerified,
    bool isHindi,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isAllVerified
                  ? [
                    const Color(0xFF064E3B),
                    const Color(0xFF0F766E),
                  ] // Deep green to teal
                  : [
                    const Color(0xFF1E293B),
                    const Color(0xFF334155),
                  ], // Charcoal to Slate
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          // Circular Progress Gauge
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: _VerificationGaugePainter(progress: progress),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$verifiedCount/4',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHindi ? 'सत्यापित' : 'Steps',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Copywriting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isAllVerified
                            ? const Color(0xFF34D399).withOpacity(0.2)
                            : Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isAllVerified
                              ? const Color(0xFF34D399)
                              : Colors.amber,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isAllVerified
                        ? (isHindi
                            ? '✓ सत्यापित पार्टनर'
                            : '✓ Verified Partner')
                        : (isHindi
                            ? '⏳ आंशिक रूप से सत्यापित'
                            : '⏳ Partially Verified'),
                    style: TextStyle(
                      color:
                          isAllVerified
                              ? const Color(0xFF34D399)
                              : Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isHindi
                      ? 'विश्वास के साथ रीसायकल करें'
                      : 'Recycle with Trust',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAllVerified
                      ? (isHindi
                          ? 'बधाई हो! आपकी प्रोफ़ाइल पूरी तरह से सत्यापित है। आपके लिए प्राथमिकता रूटिंग सक्रिय है।'
                          : 'Congratulations! Your profile is fully verified. Priority routing is active for you.')
                      : (isHindi
                          ? 'सभी 4 चरणों को पूरा करें और अधिक ऑर्डर प्राप्त करने के लिए अपना सत्यापित बैज अनलॉक करें।'
                          : 'Complete all 4 steps to unlock your verified badge and attract 3x more customers.'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBenefits(BuildContext context, bool isHindi) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                context.t('verificationBenefits'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBenefitRow(
            Icons.route_rounded,
            context.t('verifiedBadgeBenefit'),
          ),
          const Divider(height: 16, color: AppTheme.divider),
          _buildBenefitRow(
            Icons.business_center_rounded,
            context.t('bulkLeadsBenefit'),
          ),
          const Divider(height: 16, color: AppTheme.divider),
          _buildBenefitRow(
            Icons.wallet_rounded,
            context.t('fastSettlementsBenefit'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapSteps(
    BuildContext context,
    PartnerModel p,
    bool isHindi,
  ) {
    return Column(
      children: [
        // 1. Aadhaar ID Verification
        _buildStepCard(
          stepNo: 1,
          title: context.t('aadhaarVerification'),
          description: context.t('aadhaarDesc'),
          isVerified: p.aadhaarVerified,
          icon: Icons.badge_rounded,
          verifiedSummary:
              p.aadhaarNumber.length >= 4
                  ? 'Aadhaar: *******${p.aadhaarNumber.substring(p.aadhaarNumber.length - 4)}'
                  : 'Identity Verified Successfully',
          onActionPressed: () => _verifyAadhaarDialog(context, p, isHindi),
        ),
        const SizedBox(height: 16),

        // 2. Business Profile Verification
        _buildStepCard(
          stepNo: 2,
          title: context.t('businessVerification'),
          description: context.t('businessDesc'),
          isVerified: p.businessInfoVerified,
          icon: Icons.storefront_rounded,
          verifiedSummary:
              p.gstNumber != null && p.gstNumber!.isNotEmpty
                  ? '${p.shopName} (GST: ${p.gstNumber})'
                  : p.shopName,
          onActionPressed: () => _verifyBusinessDialog(context, p, isHindi),
        ),
        const SizedBox(height: 16),

        // 3. Payment Settlement Verification
        _buildStepCard(
          stepNo: 3,
          title: context.t('bankVerification'),
          description: context.t('paymentDesc'),
          isVerified: p.bankVerified,
          icon: Icons.account_balance_rounded,
          verifiedSummary:
              p.upiId.isNotEmpty
                  ? 'UPI ID: ${p.upiId}'
                  : (p.bankAccountNumber.length >= 4
                      ? 'A/C: *******${p.bankAccountNumber.substring(p.bankAccountNumber.length - 4)} (${p.bankIfsc})'
                      : 'Settlement Account Configured'),
          onActionPressed: () => _verifyBankDialog(context, p, isHindi),
        ),
        const SizedBox(height: 16),

        // 4. GPS Location Verification
        _buildStepCard(
          stepNo: 4,
          title: context.t('locationVerification'),
          description: context.t('locationDesc'),
          isVerified: p.addressVerified,
          icon: Icons.pin_drop_rounded,
          verifiedSummary: p.shopAddress,
          onActionPressed: () => _verifyLocation(context, p, isHindi),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required int stepNo,
    required String title,
    required String description,
    required bool isVerified,
    required IconData icon,
    required String verifiedSummary,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isVerified ? AppTheme.primary.withOpacity(0.4) : AppTheme.border,
          width: isVerified ? 1.5 : 0.5,
        ),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isVerified
                        ? AppTheme.primaryLight
                        : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isVerified ? AppTheme.primary : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSmallStatusBadge(isVerified),
              ],
            ),
            subtitle: Text(
              isVerified ? '✓ Tap to view details' : '⚡ Action required',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isVerified ? AppTheme.primary : const Color(0xFFEF4444),
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              const Divider(color: AppTheme.divider, height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isVerified)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          verifiedSummary,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onActionPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      stepNo == 4
                          ? 'Auto-Fetch Location (GPS)'
                          : 'Verify Details Now',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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

  Widget _buildSmallStatusBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isVerified ? 'VERIFIED' : 'PENDING',
        style: TextStyle(
          color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfilePreview(
    BuildContext context,
    PartnerModel p,
    bool isVerified,
    bool isHindi,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 0.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('profilePreview'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('profilePreviewDesc'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // The Customer App Card Mockup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop image / profile avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.shopName.isNotEmpty
                                  ? p.shopName
                                  : 'My Recycle Shop',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Premium verified badge if verified
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            p.rating > 0 ? p.rating.toStringAsFixed(1) : '4.8',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black45,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '1.2 km ${isHindi ? 'दूर' : 'away'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Small badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildMockBadge(
                            Icons.assignment_ind_rounded,
                            isHindi ? 'सत्यापित आईडी' : 'Verified ID',
                            isVerified,
                          ),
                          _buildMockBadge(
                            Icons.location_on_rounded,
                            isHindi ? 'मैप की गई दुकान' : 'Mapped Shop',
                            p.addressVerified,
                          ),
                          _buildMockBadge(
                            Icons.speed_rounded,
                            isHindi ? 'फास्ट रिस्पांस' : 'Quick Pickup',
                            true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBadge(IconData icon, String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF059669) : const Color(0xFF94A3B8),
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF065F46) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Verification Dialogs ──

  void _verifyAadhaarDialog(
    BuildContext context,
    PartnerModel p,
    bool isHindi,
  ) {
    final aadhaarCtrl = TextEditingController(text: p.aadhaarNumber);
    File? localFront;
    File? localBack;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isHindi ? 'आधार कार्ड सत्यापन' : 'Verify Aadhaar ID',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi
                          ? 'कृपया अपना 12 अंकों का आधार नंबर दर्ज करें और सामने व पीछे का फोटो अपलोड करें।'
                          : 'Please enter your 12-digit Aadhaar number and upload clear front and back photos.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: aadhaarCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            isHindi ? 'आधार नंबर' : 'Aadhaar Card Number',
                        hintText: '0000 0000 0000',
                        counterText: '',
                        prefixIcon: const Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final img = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (img != null) {
                                setSheetState(
                                  () => localFront = File(img.path),
                                );
                              }
                            },
                            child: _buildDocUploadCard(
                              label: isHindi ? 'सामने की फोटो' : 'Front Image',
                              file: localFront,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final img = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (img != null) {
                                setSheetState(() => localBack = File(img.path));
                              }
                            },
                            child: _buildDocUploadCard(
                              label: isHindi ? 'पीछे की फोटो' : 'Back Image',
                              file: localBack,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label:
                          isHindi
                              ? 'दस्तावेज़ जमा करें'
                              : 'Submit ID Documents',
                      onPressed: () async {
                        final numVal = aadhaarCtrl.text.trim();
                        if (numVal.length != 12) {
                          AppTheme.showSnack(
                            context,
                            'Aadhaar must be exactly 12 digits',
                            isError: true,
                          );
                          return;
                        }
                        if (localFront == null || localBack == null) {
                          AppTheme.showSnack(
                            context,
                            'Please upload both Front and Back photos',
                            isError: true,
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);

                        // Simulated Firebase Storage Upload and Verification
                        await Future.delayed(const Duration(seconds: 2));
                        final success = await _provider.verifyAadhaar(
                          numVal,
                          'https://firebasestorage.googleapis.com/v0/b/scrapwell-demo/o/aadhaar_front.jpg',
                          'https://firebasestorage.googleapis.com/v0/b/scrapwell-demo/o/aadhaar_back.jpg',
                          'SHA256_HASH_DUMMY_TOKEN',
                        );

                        setState(() => _isProcessing = false);
                        if (success && mounted) {
                          AppTheme.showSnack(
                            context,
                            'Aadhaar verification submitted successfully!',
                            isSuccess: true,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocUploadCard({required String label, required File? file}) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child:
          file != null
              ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
    );
  }

  void _verifyBusinessDialog(
    BuildContext context,
    PartnerModel p,
    bool isHindi,
  ) {
    final shopNameCtrl = TextEditingController(text: p.shopName);
    final gstCtrl = TextEditingController(text: p.gstNumber ?? '');
    File? shopPhoto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isHindi
                              ? 'व्यवसाय प्रोफ़ाइल सत्यापन'
                              : 'Verify Business Profile',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi
                          ? 'अपनी दुकान का नाम, जीएसटी नंबर (वैकल्पिक) और दुकान की सामने से फोटो अपलोड करें।'
                          : 'Configure your registered shop name, optional GSTIN, and upload a storefront photo.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: shopNameCtrl,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText:
                            isHindi ? 'दुकान का नाम' : 'Registered Shop Name',
                        prefixIcon: const Icon(Icons.store_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: gstCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            isHindi
                                ? 'जीएसटी नंबर (वैकल्पिक)'
                                : 'GSTIN Number (Optional)',
                        prefixIcon: const Icon(Icons.percent_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final img = await _picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (img != null) {
                          setSheetState(() => shopPhoto = File(img.path));
                        }
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child:
                            shopPhoto != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    shopPhoto!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                                : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: AppTheme.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isHindi
                                          ? 'दुकान की फोटो अपलोड करें'
                                          : 'Upload Shop storefront photo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label:
                          isHindi
                              ? 'प्रोफ़ाइल सहेजें'
                              : 'Save Business details',
                      onPressed: () async {
                        final name = shopNameCtrl.text.trim();
                        if (name.isEmpty) {
                          AppTheme.showSnack(
                            context,
                            'Shop Name cannot be empty',
                            isError: true,
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);

                        // Simulated Firebase Storage Upload
                        await Future.delayed(const Duration(seconds: 2));
                        final success = await _provider.updateBusinessInfo(
                          name,
                          gstCtrl.text.trim().toUpperCase(),
                          'https://firebasestorage.googleapis.com/v0/b/scrapwell-demo/o/storefront.jpg',
                        );

                        setState(() => _isProcessing = false);
                        if (success && mounted) {
                          AppTheme.showSnack(
                            context,
                            'Business profile details updated!',
                            isSuccess: true,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _verifyBankDialog(BuildContext context, PartnerModel p, bool isHindi) {
    final holderCtrl = TextEditingController(text: p.bankAccountName);
    final accountCtrl = TextEditingController(text: p.bankAccountNumber);
    final ifscCtrl = TextEditingController(text: p.bankIfsc);
    final upiCtrl = TextEditingController(text: p.upiId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          initialIndex: p.upiId.isNotEmpty ? 0 : 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isHindi ? 'भुगतान खाता विवरण' : 'Settlement Account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHindi
                        ? 'अपना UPI आईडी या बैंक खाता दर्ज करें जहां आपकी कमाई ट्रांसफर की जाएगी।'
                        : 'Choose your payout method. All wallet payouts are processed instantly.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    tabs: [
                      Tab(text: isHindi ? 'UPI आईडी' : 'UPI ID'),
                      Tab(text: isHindi ? 'बैंक खाता' : 'Bank Account'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: TabBarView(
                      children: [
                        // UPI Tab
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: upiCtrl,
                              autocorrect: false,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    isHindi
                                        ? 'UPI आईडी दर्ज करें'
                                        : 'UPI Address ID',
                                hintText: 'e.g. mobile@ybl',
                                prefixIcon: const Icon(Icons.payment_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Bank Account Tab
                        Column(
                          children: [
                            TextFormField(
                              controller: holderCtrl,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    isHindi
                                        ? 'खाता धारक का नाम'
                                        : 'Account Holder Name',
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: accountCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText:
                                          isHindi
                                              ? 'खाता संख्या'
                                              : 'Account No',
                                      prefixIcon: const Icon(
                                        Icons.credit_card_rounded,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: ifscCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'IFSC',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: isHindi ? 'खाता सहेजें' : 'Save Settlement Account',
                    onPressed: () async {
                      final tabIndex = DefaultTabController.of(ctx).index;
                      Navigator.pop(ctx);
                      setState(() => _isProcessing = true);

                      bool success = false;
                      try {
                        if (tabIndex == 0) {
                          final upi = upiCtrl.text.trim();
                          if (upi.isEmpty) {
                            AppTheme.showSnack(
                              context,
                              'Please enter a valid UPI ID',
                              isError: true,
                            );
                            setState(() => _isProcessing = false);
                            return;
                          }
                          success = await _provider.updateUpiDetails(upi);
                          await _provider.updatePartnerField(
                            'bankAccountNumber',
                            '',
                          );
                        } else {
                          final name = holderCtrl.text.trim();
                          final acct = accountCtrl.text.trim();
                          final ifsc = ifscCtrl.text.trim().toUpperCase();
                          if (name.isEmpty || acct.isEmpty || ifsc.isEmpty) {
                            AppTheme.showSnack(
                              context,
                              'Please fill in all bank details',
                              isError: true,
                            );
                            setState(() => _isProcessing = false);
                            return;
                          }
                          success = await _provider.updateBankDetails(
                            name,
                            acct,
                            ifsc,
                          );
                          await _provider.updatePartnerField('upiId', '');
                        }

                        if (success && mounted) {
                          AppTheme.showSnack(
                            context,
                            'Payout details verified and saved!',
                            isSuccess: true,
                          );
                        }
                      } catch (e) {
                        if (mounted)
                          AppTheme.showSnack(
                            context,
                            'Error: $e',
                            isError: true,
                          );
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _verifyLocation(
    BuildContext context,
    PartnerModel p,
    bool isHindi,
  ) async {
    setState(() => _isProcessing = true);

    try {
      // 1. Verify location permissions & status
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isProcessing = false);
        if (context.mounted) {
          _showLocationServiceDialog(context, isHindi);
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isProcessing = false);
          if (context.mounted) {
            AppTheme.showSnack(
              context,
              'Location permission denied by user.',
              isError: true,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isProcessing = false);
        if (context.mounted) {
          AppTheme.showSnack(
            context,
            'Location permissions are permanently denied. Enable in Settings.',
            isError: true,
          );
        }
        return;
      }

      // 2. Fetch Position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 3. Geocode Position
      String resolvedAddress = 'Shop Coordinates Mapped';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          resolvedAddress =
              '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}'
                  .trim();
          if (resolvedAddress.startsWith(','))
            resolvedAddress = resolvedAddress.substring(1).trim();
        }
      } catch (_) {
        // Fallback to exact address
        if (p.exactShopAddress.isNotEmpty) {
          resolvedAddress = p.exactShopAddress;
        } else if (p.shopAddress.isNotEmpty) {
          resolvedAddress = p.shopAddress;
        }
      }

      // 4. Update Business Address in Provider/DB
      final success = await _provider.updateBusinessAddress(
        resolvedAddress,
        position.latitude,
        position.longitude,
      );

      setState(() => _isProcessing = false);
      if (success && mounted) {
        AppTheme.showSnack(
          context,
          'Shop location mapped and verified successfully!',
          isSuccess: true,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        AppTheme.showSnack(context, 'Error locating shop: $e', isError: true);
      }
    }
  }

  void _showLocationServiceDialog(BuildContext context, bool isHindi) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.gps_off_rounded,
                  color: AppTheme.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(isHindi ? 'स्थान सेवा अक्षम है' : 'GPS Location Disabled'),
              ],
            ),
            content: Text(
              isHindi
                  ? 'आपकी दुकान का सटीक स्थान सत्यापित करने के लिए कृपया अपना जीपीएस चालू करें।'
                  : 'Please turn on your GPS / Location services so we can map your exact shop coordinates.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.t('cancel'),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Geolocator.openLocationSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(isHindi ? 'सेटिंग्स खोलें' : 'Open Settings'),
              ),
            ],
          ),
    );
  }
}

/// Custom Gauge Painter to draw a premium gradient ring
class _VerificationGaugePainter extends CustomPainter {
  final double progress;

  _VerificationGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Draw Background Track
    final trackPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw Active Progress Sweep Arc
    if (progress > 0) {
      final activePaint =
          Paint()
            ..shader = const SweepGradient(
              colors: [
                Color(0xFF10B981), // Emerald Green
                Color(0xFF34D399), // Mint Green
                Color(0xFF0D9488), // Teal
                Color(0xFF10B981), // Emerald Green
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
              transform: GradientRotation(-pi / 2),
            ).createShader(Rect.fromCircle(center: center, radius: radius))
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = strokeWidth;

      // Draw sweeping arc from top (-pi / 2)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerificationGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
