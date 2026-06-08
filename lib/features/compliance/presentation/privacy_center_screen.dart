import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/presentation/login_screen.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final _provider = PartnerProvider();
  bool _cameraPermission = true;
  bool _locationPermission = true;
  bool _notificationPermission = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadStoredPreferences();
  }

  Future<void> _loadStoredPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cameraPermission = prefs.getBool('camera_allowed') ?? true;
      _locationPermission = _provider.locationAllowed;
      _notificationPermission = prefs.getBool('notifications_allowed') ?? true;
    });
  }

  Future<void> _updateCameraPermission(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_allowed', allowed);
    setState(() => _cameraPermission = allowed);
    if (mounted) {
      AppTheme.showSnack(
        context,
        allowed ? 'Camera access enabled' : 'Camera access disabled',
        isSuccess: true,
      );
    }
  }

  Future<void> _updateLocationPermission(bool allowed) async {
    setState(() => _isProcessing = true);
    try {
      await _provider.setLocationAllowed(allowed);
      setState(() => _locationPermission = allowed);
      if (mounted) {
        AppTheme.showSnack(
          context,
          allowed
              ? 'GPS Location matching enabled'
              : 'GPS Location disabled. You have been taken offline.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) AppTheme.showSnack(context, 'Failed to update GPS permission: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateNotificationPermission(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_allowed', allowed);
    setState(() => _notificationPermission = allowed);
    if (mounted) {
      AppTheme.showSnack(
        context,
        allowed ? 'Push notification alerts enabled' : 'Push notifications disabled',
        isSuccess: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.t('privacyData')),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('privacyData'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHindi
                        ? 'अपनी गोपनीयता, डेटा अनुमतियां और खाता सेटिंग्स प्रबंधित करें।'
                        : 'Manage your privacy, data permissions, and account settings.',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Section: Manage Permissions
                  Text(
                    context.t('managePermissions'),
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
                        // Location Permission
                        SwitchListTile(
                          activeColor: AppTheme.primary,
                          title: Text(
                            isHindi ? 'स्थान पहुंच (GPS)' : 'Location Access (GPS)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            isHindi
                                ? 'आस-पास के पिकअप ऑर्डर प्राप्त करने और ग्राहक तक नेविगेट करने के लिए स्थान अनुमति आवश्यक है।'
                                : 'Required to receive nearby scrap pickup leads and navigate to customers.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                          value: _locationPermission,
                          onChanged: _updateLocationPermission,
                        ),
                        const Divider(height: 1, color: AppTheme.divider),

                        // Camera Permission
                        SwitchListTile(
                          activeColor: AppTheme.primary,
                          title: Text(
                            isHindi ? 'कैमरा पहुंच' : 'Camera Access',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            isHindi
                                ? 'दुकान की फोटो और सत्यापन दस्तावेजों को अपलोड करने के लिए कैमरा आवश्यक है।'
                                : 'Required to take and upload shop photos and document proof for verification.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                          value: _cameraPermission,
                          onChanged: _updateCameraPermission,
                        ),
                        const Divider(height: 1, color: AppTheme.divider),

                        // Notifications Permission
                        SwitchListTile(
                          activeColor: AppTheme.primary,
                          title: Text(
                            isHindi ? 'सूचनाएं' : 'Notifications',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            isHindi
                                ? 'नए पिकअप अनुरोधों, चैट संदेशों और भुगतान अपडेट के लिए अलर्ट प्राप्त करें।'
                                : 'Receive real-time alerts for incoming orders, customer chat, and settlements.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                          value: _notificationPermission,
                          onChanged: _updateNotificationPermission,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Danger Zone Section
                  Text(
                    isHindi ? 'खतरनाक क्षेत्र' : 'Danger Zone',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.error, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showDeleteAccountDialog(context, isHindi),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.subtleShadow,
                        border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('deleteAccount'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.error,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isHindi
                                      ? 'अपने पार्टनर प्रोफाइल को स्थायी रूप से हटा दें।'
                                      : 'Permanently request deactivation of your partner profile.',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.error, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, bool isHindi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isHindi ? 'खाता स्थायी रूप से हटाएं?' : 'Delete Account Permanently?',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi
                  ? 'चेतावनी: यह क्रिया अपरिवर्तनीय है।'
                  : 'WARNING: This action is irreversible.',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.error),
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'आपका खाता डेटाबेस और प्रमाणीकरण सर्वर से स्थायी रूप से हटा दिया जाएगा। आपका वॉलेट बैलेंस और सभी सक्रिय लीड तुरंत रद्द हो जाएंगे।'
                  : 'Your account document and credentials will be completely purged from our databases. Your wallet balances and active leads will be immediately cancelled.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
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
              setState(() => _isProcessing = true);

              final success = await _provider.deleteAccountRequest();
              setState(() => _isProcessing = false);

              if (success) {
                if (mounted) {
                  AppTheme.showSnack(
                    context,
                    isHindi
                        ? 'आपका खाता पूरी तरह से हटा दिया गया है।'
                        : 'Your account has been completely wiped from our servers.',
                    isSuccess: true,
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              } else {
                if (mounted) {
                  AppTheme.showSnack(
                    context,
                    isHindi
                        ? 'हटाने में त्रुटि। प्रमाणीकरण अवधि समाप्त हो सकती है।'
                        : 'Wipe failed. Session might have expired. Signing out.',
                    isError: true,
                  );
                  // fallback clean exit
                  _provider.reset();
                  await AuthService.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isHindi ? 'नष्ट करें' : 'Purge Account',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
