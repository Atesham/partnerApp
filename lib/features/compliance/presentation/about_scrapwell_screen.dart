import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

class AboutScrapwellScreen extends StatelessWidget {
  const AboutScrapwellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(context.t('aboutScrapwell')), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & App Info Header
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      child: const Icon(
                        Icons.recycling_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t('appName'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t('appTagline'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'v1.0.0 (Production)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Scrapwell Description Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.subtleShadow,
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'हमारे बारे में' : 'About Us',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isHindi
                          ? 'स्क्रैपवेल भारत का अग्रणी डिजिटल रीसाइक्लिंग और अपशिष्ट प्रबंधन मंच है। हम स्थानीय स्क्रैप विक्रेताओं (\'पार्टनर्स\') को सीधे घरेलू और कॉर्पोरेट स्क्रैप विक्रेताओं से जोड़कर उन्हें सशक्त बनाते हैं। हमारा मिशन अनौपचारिक अपशिष्ट प्रबंधन पारिस्थितिकी तंत्र को डिजिटल बनाना, प्रौद्योगिकी के माध्यम से उचित मूल्य निर्धारण और वजन पारदर्शिता सुनिश्चित करना है, और चक्रीय हरित अर्थव्यवस्था को बढ़ावा देने के लिए लैंडफिल से रिसाइकिल योग्य सामग्रियों के विचलन को अधिकतम करना है।'
                          : 'Scrapwell is India\'s leading digital recycling and waste management platform. We empower local scrap vendors (\'partners\') by connecting them directly with household and corporate scrap sellers. Our mission is to digitize the informal waste management ecosystem, ensure fair pricing and weight transparency through technology, and maximize recyclable materials diversion from landfills to promote a circular green economy.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Corporate Registry Information
              Text(
                isHindi ? 'कॉर्पोरेट विवरण' : 'Corporate Details',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.subtleShadow,
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      label: isHindi ? 'कंपनी का नाम' : 'Company Name',
                      value: 'Scrapwell Recycling Private Limited',
                    ),
                    const Divider(height: 20, color: AppTheme.divider),
                    _buildRow(
                      label: isHindi ? 'पंजीकृत पता' : 'Registered Address',
                      value: 'Sec 10A, Gurgaon, Haryana - 122001',
                    ),
                    const Divider(height: 20, color: AppTheme.divider),
                    _buildRow(
                      label:
                          isHindi
                              ? 'कॉर्पोरेट पहचान संख्या (CIN)'
                              : 'Corporate ID (CIN)',
                      value: 'U38110HR2026PTC118542',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Grievance Officer Details
              Text(
                context.t('grievanceRedressal'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.subtleShadow,
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow(
                      label: isHindi ? 'अधिकारी का नाम' : 'Grievance Officer',
                      value: 'Mr. Saurabh',
                    ),
                    const Divider(height: 20, color: AppTheme.divider),
                    _buildRow(
                      label:
                          isHindi ? 'प्रतिक्रिया समय सीमा' : 'Resolution TAT',
                      value: isHindi ? '15 कार्य दिवस' : '15 Business Days',
                    ),
                    const Divider(height: 20, color: AppTheme.divider),
                    Text(
                      isHindi ? 'शिकायत ईमेल' : 'Grievance Email',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(
                          'mailto:help@scrapwell.in?subject=Grievance%20Redressal%20Request',
                        );
                        try {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          AppTheme.showSnack(
                            context,
                            'Could not open mail client.',
                            isError: true,
                          );
                        }
                      },
                      child: const Text(
                        'help@scrapwell.in',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
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
    );
  }

  Widget _buildRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
