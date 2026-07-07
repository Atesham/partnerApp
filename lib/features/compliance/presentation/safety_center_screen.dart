import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/l10n/app_localizations.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  final _partnerProvider = PartnerProvider();
  bool _isReporting = false;

  Future<void> _triggerSOS() async {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 28),
            const SizedBox(width: 10),
            Text(
              isHindi ? 'आपातकालीन सहायता!' : 'Emergency SOS!',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.error),
            ),
          ],
        ),
        content: Text(
          isHindi
              ? 'यह सीधे स्क्रैपवेल नियंत्रण कक्ष को एक आपातकालीन कॉल और अलर्ट भेजेगा। क्या आप सहायता टीम को कॉल करना चाहते हैं?'
              : 'This will dispatch a real emergency alert to Scrapwell command center and dial our hotline. Do you wish to contact our emergency desk immediately?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.t('cancel'),
              style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isReporting = true);
              
              // 1. Log real SOS alert to Firestore
              try {
                final p = _partnerProvider.partner;
                await FirebaseFirestore.instance.collection('sos_alerts').add({
                  'partnerUid': p.uid,
                  'partnerPhone': p.phone,
                  'partnerName': p.displayName,
                  'location': GeoPoint(p.currentLat, p.currentLng),
                  'status': 'active',
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } catch (_) {}

              setState(() => _isReporting = false);

              // 2. Launch Dialer
              final uri = Uri.parse('tel:+918744081962');
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                if (mounted) {
                  AppTheme.showSnack(context, 'Could not open phone dialer.', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isHindi ? 'कॉल करें' : 'Call Now',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, bool isHindi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isHindi ? 'रिपोर्ट सफलतापूर्वक दर्ज की गई' : 'Report Filed Successfully',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isHindi
                  ? 'आपकी रिपोर्ट स्क्रैपवेल अनुपालन डेस्क पर भेज दी गई है। हमारी सुरक्षा टीम 24 घंटे के भीतर इसकी समीक्षा करेगी।'
                  : 'Your safety report has been logged at the Scrapwell Compliance Desk. Our safety team will review and resolve this within 24 hours.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isHindi ? 'ठीक है' : 'Understood'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportForm(String type, String title) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final descCtrl = TextEditingController();
    final orderIdCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: orderIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Order ID (Optional)',
                  prefixIcon: Icon(Icons.receipt_long_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: isHindi ? 'घटना का विवरण लिखें' : 'Describe the incident in detail',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 50.0),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final desc = descCtrl.text.trim();
                  if (desc.isEmpty) {
                    AppTheme.showSnack(context, 'Please enter incident details', isError: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _isReporting = true);

                  try {
                    await FirebaseFirestore.instance.collection('reports').add({
                      'partnerUid': _partnerProvider.partner.uid,
                      'partnerPhone': _partnerProvider.partner.phone,
                      'partnerName': _partnerProvider.partner.displayName,
                      'orderId': orderIdCtrl.text.trim(),
                      'type': type,
                      'description': desc,
                      'status': 'open',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      _showSuccessDialog(context, isHindi);
                    }
                  } catch (e) {
                    if (mounted) AppTheme.showSnack(context, 'Failed to file report: $e', isError: true);
                  } finally {
                    setState(() => _isReporting = false);
                  }
                },
                child: Text(isHindi ? 'रिपोर्ट दर्ज करें' : 'Submit Report'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      descCtrl.dispose();
      orderIdCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.t('safetyCenter')),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header
                Text(
                  context.t('safetyCenter'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isHindi
                      ? 'सुरक्षा दिशानिर्देश और आपातकालीन रिपोर्टिंग केंद्र।'
                      : 'Emergency reporting, support, and partner safety guidelines.',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

                // SOS Trigger Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('emergencySupport'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.error,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHindi
                                  ? 'पिकअप के दौरान किसी भी खतरे या आपातकालीन स्थिति में तुरंत कॉल करें।'
                                  : 'Call Scrapwell emergency team immediately for any safety threats.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[900],
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _triggerSOS,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Report forms options
                Text(
                  isHindi ? 'घटना की रिपोर्ट करें' : 'Report Incidents',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.subtleShadow,
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_off_rounded, color: AppTheme.primary),
                        title: Text(context.t('reportCustomerMisconduct')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showReportForm('misconduct', context.t('reportCustomerMisconduct')),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      ListTile(
                        leading: const Icon(Icons.gavel_rounded, color: AppTheme.warning),
                        title: Text(context.t('reportFraud')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showReportForm('fraud', context.t('reportFraud')),
                      ),
                      const Divider(height: 1, color: AppTheme.divider),
                      ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                        title: Text(context.t('harassmentReporting')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showReportForm('harassment', context.t('harassmentReporting')),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Safety Guidelines slide/list
                Text(
                  context.t('pickupSafetyGuidelines'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                ..._getGuidelines(isHindi).map((guide) => _buildGuidelineCard(guide)),

                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isReporting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to safety services...'),
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

  Widget _buildGuidelineCard(_Guideline guide) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.subtleShadow,
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  guide.body,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Guideline> _getGuidelines(bool isHindi) {
    if (isHindi) {
      return const [
        _Guideline('सत्यापित पते पर जाएं', 'हमेशा केवल ऐप में निर्दिष्ट सटीक स्थान पर ही पिकअप के लिए जाएं। अज्ञात या असुरक्षित सुनसान स्थानों पर जाने से बचें।'),
        _Guideline('लोड सुरक्षा सुनिश्चित करें', 'स्क्रैप उठाने के बाद अपने वाहन पर सामग्री को ठीक से बांधें। क्षमता से अधिक लोड न करें।'),
        _Guideline('पेशेवर व्यवहार बनाए रखें', 'ग्राहकों से सम्मानपूर्वक व्यवहार करें। मूल्य के मुद्दों पर शांति बनाए रखें और विवाद होने पर स्क्रैपवेल सहायता टीम को रिपोर्ट करें।'),
      ];
    }
    return const [
      _Guideline('Visit Verified Addresses Only', 'Perform collections strictly at the address displayed on the map. Avoid taking offline detours or entering unverified dark spaces.'),
      _Guideline('Secure Cargo Load', 'Bind and tie the loaded scrap properly before starting transit. Overloading cargo beyond limits is unsafe and illegal.'),
      _Guideline('Maintain Professional Behavior', 'Polite greetings and clear weights go a long way. In case of price/weight disputes, do not argue; file a support request via Safety Center.'),
    ];
  }
}

class _Guideline {
  final String title;
  final String body;
  const _Guideline(this.title, this.body);
}
