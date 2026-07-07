import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/models/partner_model.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/shared_widgets.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _provider = PartnerProvider();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.t('myBusinessProfile')),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: _provider,
              builder: (context, _) {
                final p = _provider.partner;

                return ResponsiveWrapper(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Profile Details Header Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.subtleShadow,
                          border: Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
                                image: p.profilePhotoUrl.isNotEmpty
                                    ? DecorationImage(image: CachedNetworkImageProvider(p.profilePhotoUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: p.profilePhotoUrl.isEmpty
                                  ? Center(
                                      child: Text(
                                        p.initials,
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (p.isApproved)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7), // Gold tint
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                context.t('verifiedPartner'),
                                                style: const TextStyle(
                                                  color: Color(0xFFB45309),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.shopName,
                                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.phone,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Prominent Trust Score card
                      Text(
                        context.t('trustScore'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.subtleShadow,
                          border: Border.all(color: AppTheme.border, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            // Trust Gauge Visualizer
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(180, 180),
                                    painter: _TrustGaugePainter(score: p.trustScore),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        p.trustScore.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isHindi ? 'भरोसा स्कोर' : 'Trust Score',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Score Descriptor Info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isHindi
                                    ? 'उत्कृष्ट - प्राथमिकता ऑर्डर रूटिंग सक्रिय है'
                                    : 'Excellent - Priority Order Dispatch Activated',
                                style: const TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Trust Metrics Grid
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    label: context.t('completionRate'),
                                    value: '${p.completionRate.toStringAsFixed(0)}%',
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Container(width: 1, height: 40, color: AppTheme.divider),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: context.t('cancellationRate'),
                                    value: '${p.cancellationRate.toStringAsFixed(0)}%',
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.divider),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    label: context.t('customerRating'),
                                    value: '${p.rating.toStringAsFixed(1)} ★',
                                    color: AppTheme.warning,
                                  ),
                                ),
                                Container(width: 1, height: 40, color: AppTheme.divider),
                                Expanded(
                                  child: _buildMetricTile(
                                    label: context.t('fraudIndex'),
                                    value: p.fraudScore,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bank / UPI Details Settlement Section
                      Text(
                        isHindi ? 'भुगतान निपटान (Bank/UPI)' : 'Payment Settlement (Bank/UPI)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
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
                            if (p.upiId.isNotEmpty) ...[
                              _buildDetailRow(isHindi ? 'UPI आईडी' : 'UPI ID', p.upiId),
                              const SizedBox(height: 10),
                            ],
                            if (p.bankAccountNumber.isNotEmpty) ...[
                              _buildDetailRow(isHindi ? 'खाता धारक' : 'Account Holder', p.bankAccountName),
                              const SizedBox(height: 6),
                              _buildDetailRow(isHindi ? 'खाता संख्या' : 'Account Number', p.bankAccountNumber),
                              const SizedBox(height: 6),
                              _buildDetailRow(isHindi ? 'IFSC कोड' : 'IFSC Code', p.bankIfsc),
                              const SizedBox(height: 12),
                            ],
                            if (p.upiId.isEmpty && p.bankAccountNumber.isEmpty) ...[
                              Text(
                                isHindi ? 'कोई निपटान विवरण नहीं दिया गया है।' : 'No payment settlement details configured.',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 12),
                            ],
                            GradientButton(
                              label: isHindi ? 'निपटान विवरण संपादित करें' : 'Edit Settlement Details',
                              height: 44,
                              onPressed: () => _editSettlementDetails(context, p),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Operations info cards
                      Text(
                        isHindi ? 'संचालन विवरण' : 'Operations Details',
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
                              leading: const Icon(Icons.timer_rounded, color: AppTheme.primary),
                              title: Text(isHindi ? 'कार्य करने का समय' : 'Working Hours'),
                              subtitle: Text('${p.workingHoursStart} - ${p.workingHoursEnd}'),
                              trailing: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.primary),
                              onTap: () => _editWorkingHours(context, p),
                            ),
                            const Divider(height: 1, color: AppTheme.divider),
                            ListTile(
                              leading: const Icon(Icons.local_shipping_rounded, color: AppTheme.primary),
                              title: Text(isHindi ? 'स्वीकृत वाहन' : 'Registered Vehicles'),
                              subtitle: Text(p.vehicleTypes.isEmpty
                                  ? 'No vehicles selected'
                                  : p.vehicleTypes.map((v) => v.name.toUpperCase()).join(', ')),
                              trailing: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.primary),
                              onTap: () => _editVehicles(context, p),
                            ),
                            const Divider(height: 1, color: AppTheme.divider),
                            ListTile(
                              leading: const Icon(Icons.category_rounded, color: AppTheme.primary),
                              title: Text(isHindi ? 'स्वीकृत श्रेणियां' : 'Accepted Scrap Categories'),
                              subtitle: Text(p.scrapCategories.isEmpty
                                  ? 'No categories selected'
                                  : p.scrapCategories.join(', ')),
                              trailing: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.primary),
                              onTap: () => _editCategories(context, p),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                );
              },
            ),
            if (_isSaving)
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.primaryDeep, // Emerald Deep Green to match theme and ensure high visibility
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Real-Time Editing Dialogs ──────────────────────────────────────────────

  Future<void> _editWorkingHours(BuildContext context, PartnerModel p) async {
    final startParts = p.workingHoursStart.split(':');
    final endParts = p.workingHoursEnd.split(':');
    
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    if (startParts.length == 2) {
      startTime = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 9, minute: int.tryParse(startParts[1]) ?? 0);
    }
    
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    if (endParts.length == 2) {
      endTime = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 18, minute: int.tryParse(endParts[1]) ?? 0);
    }

    final TimeOfDay? newStart = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: 'Select Opening Time',
    );
    if (newStart == null || !mounted) return;

    final TimeOfDay? newEnd = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: 'Select Closing Time',
    );
    if (newEnd == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final startStr = '${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
      final endStr = '${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}';
      await _provider.updatePartnerField('workingHoursStart', startStr);
      await _provider.updatePartnerField('workingHoursEnd', endStr);
      if (mounted) AppTheme.showSnack(context, 'Working hours updated in real-time!', isSuccess: true);
    } catch (e) {
      if (mounted) AppTheme.showSnack(context, 'Update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editVehicles(BuildContext context, PartnerModel p) {
    final list = List<VehicleType>.from(p.vehicleTypes);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Registered Vehicles',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: VehicleType.values.map((v) {
                  final contains = list.contains(v);
                  return CheckboxListTile(
                    activeColor: AppTheme.primary,
                    title: Text(
                      v.name.toUpperCase(),
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    value: contains,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          list.add(v);
                        } else {
                          list.remove(v);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isSaving = true);
                  try {
                    final names = list.map((e) => e.name).toList();
                    await _provider.updatePartnerField('vehicleTypes', names);
                    if (mounted) AppTheme.showSnack(context, 'Vehicles updated in real-time!', isSuccess: true);
                  } catch (e) {
                    if (mounted) AppTheme.showSnack(context, 'Update failed: $e', isError: true);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editCategories(BuildContext context, PartnerModel p) {
    final List<String> available = [
      'Paper', 'Plastic', 'Metal', 'E-Waste', 'Glass', 'Cardboard', 'Rubber', 'Clothes', 'Mixed Scrap'
    ];
    final list = List<String>.from(p.scrapCategories);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Accepted Scrap Categories',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: available.map((cat) {
                  final contains = list.contains(cat);
                  return CheckboxListTile(
                    activeColor: AppTheme.primary,
                    title: Text(
                      cat,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    value: contains,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          list.add(cat);
                        } else {
                          list.remove(cat);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isSaving = true);
                  try {
                    await _provider.updatePartnerField('scrapCategories', list);
                    if (mounted) AppTheme.showSnack(context, 'Scrap categories updated in real-time!', isSuccess: true);
                  } catch (e) {
                    if (mounted) AppTheme.showSnack(context, 'Update failed: $e', isError: true);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editSettlementDetails(BuildContext context, PartnerModel p) {
    final upiCtrl = TextEditingController(text: p.upiId);
    final holderCtrl = TextEditingController(text: p.bankAccountName);
    final accountCtrl = TextEditingController(text: p.bankAccountNumber);
    final ifscCtrl = TextEditingController(text: p.bankIfsc);
    
    int tabIndex = p.upiId.isNotEmpty ? 0 : 1; // UPI tab is index 0, Bank is index 1

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Settlement Credentials',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary, // Force dark text for M3 dark mode compatibility
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tab selection row
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            'UPI ID Transfer',
                            style: TextStyle(
                              color: tabIndex == 0 ? AppTheme.primaryDeep : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          selected: tabIndex == 0,
                          onSelected: (val) {
                            if (val) setSheetState(() => tabIndex = 0);
                          },
                          selectedColor: AppTheme.primaryLight,
                          backgroundColor: AppTheme.background,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            'Bank Transfer',
                            style: TextStyle(
                              color: tabIndex == 1 ? AppTheme.primaryDeep : AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          selected: tabIndex == 1,
                          onSelected: (val) {
                            if (val) setSheetState(() => tabIndex = 1);
                          },
                          selectedColor: AppTheme.primaryLight,
                          backgroundColor: AppTheme.background,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (tabIndex == 0) ...[
                    // UPI ID form
                    TextFormField(
                      controller: upiCtrl,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'UPI ID / VPA Address',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        hintText: 'e.g. name@upi',
                        hintStyle: TextStyle(color: AppTheme.textHint),
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: AppTheme.primary),
                      ),
                    ),
                  ] else ...[
                    // Bank details form
                    TextFormField(
                      controller: holderCtrl,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: accountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Number',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: Icon(Icons.credit_card_rounded, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ifscCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bank IFSC Code',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: Icon(Icons.account_balance_outlined, color: AppTheme.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isSaving = true);
                      
                      try {
                        bool success = false;
                        if (tabIndex == 0) {
                          final upi = upiCtrl.text.trim();
                          if (upi.isEmpty) {
                            AppTheme.showSnack(context, 'Please enter a valid UPI ID', isError: true);
                            setState(() => _isSaving = false);
                            return;
                          }
                          success = await _provider.updateUpiDetails(upi);
                          // Clear bank details to prioritize UPI
                          await _provider.updatePartnerField('bankAccountNumber', '');
                        } else {
                          final name = holderCtrl.text.trim();
                          final acct = accountCtrl.text.trim();
                          final ifsc = ifscCtrl.text.trim().toUpperCase();
                          if (name.isEmpty || acct.isEmpty || ifsc.isEmpty) {
                            AppTheme.showSnack(context, 'Please fill in all bank details', isError: true);
                            setState(() => _isSaving = false);
                            return;
                          }
                          success = await _provider.updateBankDetails(name, acct, ifsc);
                          // Clear UPI ID to prioritize Bank
                          await _provider.updatePartnerField('upiId', '');
                        }

                        if (success && mounted) {
                          AppTheme.showSnack(context, 'Settlement details saved to Firebase!', isSuccess: true);
                        } else if (mounted) {
                          AppTheme.showSnack(context, 'Failed to save details', isError: true);
                        }
                      } catch (e) {
                        if (mounted) AppTheme.showSnack(context, 'Error: $e', isError: true);
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
                    child: const Text('Save Settlement Credentials'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrustGaugePainter extends CustomPainter {
  final double score;
  const _TrustGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - strokeWidth;

    // Background Arc (Grey)
    final bgPaint = Paint()
      ..color = AppTheme.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Color gradient based on score value
    final activeColor = score > 85
        ? AppTheme.primary
        : score > 70
            ? AppTheme.warning
            : AppTheme.error;

    // Active Arc (Score Arc)
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = (pi * 1.5) * (score / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.75,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_TrustGaugePainter oldDelegate) => oldDelegate.score != score;
}
