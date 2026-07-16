import 'dart:io';
import '../../../core/utils/aadhaar_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/partner_model.dart';
import '../../../core/providers/partner_provider.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'pending_approval_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isLoading = false;

  // Form data
  final _fullName = TextEditingController();
  final _shopName = TextEditingController();
  final _shopAddress = TextEditingController();
  final _exactAddress = TextEditingController();
  final _gst = TextEditingController();
  final _aadhaar = TextEditingController();
  final Set<String> _categories = {};
  bool _otherCategorySelected = false;
  final _otherCategoryCtrl = TextEditingController();
  Set<VehicleType> _vehicleTypes = {VehicleType.motorcycle};
  TimeOfDay _workStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);
  double _shopLat = 28.6139;
  double _shopLng = 77.2090;

  bool _isUploading = false;
  bool _isFetchingLocation = false;

  File? _profileImage;
  File? _shopImage;
  File? _aadhaarFront;
  File? _aadhaarBack;

  final List<String> _scrapOptions = [
    'Paper',
    'Plastic',
    'Metal',
    'E-Waste',
    'Glass',
    'Cardboard',
    'Rubber',
    'Clothes',
    'Mixed Scrap',
  ];

  final List<Map<String, dynamic>> _vehicles = [
    {
      'type': VehicleType.bicycle,
      'label': 'Bicycle',
      'icon': Icons.pedal_bike_rounded,
    },
    {
      'type': VehicleType.motorcycle,
      'label': 'Motorcycle',
      'icon': Icons.two_wheeler_rounded,
    },
    {
      'type': VehicleType.autoRickshaw,
      'label': 'Auto Rickshaw',
      'icon': Icons.electric_rickshaw_rounded,
    },
    {
      'type': VehicleType.miniTruck,
      'label': 'Mini Truck',
      'icon': Icons.local_shipping_rounded,
    },
    {
      'type': VehicleType.handCart,
      'label': 'Hand Cart',
      'icon': Icons.shopping_cart_rounded,
    },
  ];

  final List<String> _stepTitles = [
    'Basic Info',
    'Shop Details',
    'Categories',
    'Vehicle & Hours',
  ];

  Future<File?> _pickImageGeneric() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    context.t('uploadPhoto'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primary,
                  ),
                  title: Text(context.t('camera')),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.primary,
                  ),
                  title: Text(context.t('gallery')),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final tempFile = File(pickedFile.path);
        try {
          final filesPath = tempFile.parent.path.replaceAll('/cache', '/files');
          final filesDir = Directory(filesPath);
          if (!await filesDir.exists()) {
            await filesDir.create(recursive: true);
          }
          final fileName = tempFile.path.replaceAll('\\', '/').split('/').last;
          final persistentFile = await tempFile.copy(
            '${filesDir.path}/persisted_${DateTime.now().millisecondsSinceEpoch}_$fileName',
          );
          return persistentFile;
        } catch (_) {
          return tempFile;
        }
      }
    }
    return null;
  }

  Future<void> _pickImage() async {
    final f = await _pickImageGeneric();
    if (f != null) setState(() => _profileImage = f);
  }

  Future<void> _pickAadhaarImage(bool isFront) async {
    final f = await _pickImageGeneric();
    if (f != null) {
      setState(() {
        if (isFront)
          _aadhaarFront = f;
        else
          _aadhaarBack = f;
      });
    }
  }

  Future<void> _pickShopImage() async {
    final f = await _pickImageGeneric();
    if (f != null) setState(() => _shopImage = f);
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
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
                      Icons.location_off_rounded,
                      color: AppTheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'GPS is Turned Off',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'Please turn on device location (GPS) to find your shop coordinates automatically.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          AppTheme.showSnack(
            context,
            context.t('permissionRequired'),
            isError: true,
          );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        AppTheme.showSnack(
          context,
          'Location permissions are permanently denied. Please enable them in settings.',
          isError: true,
        );
      return;
    }

    setState(() => _isFetchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _shopLat = position.latitude;
        _shopLng = position.longitude;
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final subLoc = place.subLocality ?? place.name ?? '';
          final loc = place.locality ?? place.subAdministrativeArea ?? '';
          final pin = place.postalCode ?? '';
          _shopAddress.text =
              '$subLoc, $loc, $pin'.replaceAll(', ,', ',').trim();
          if (_shopAddress.text.startsWith(',')) {
            _shopAddress.text = _shopAddress.text.substring(1).trim();
          }
          if (_shopAddress.text.endsWith(',')) {
            _shopAddress.text =
                _shopAddress.text
                    .substring(0, _shopAddress.text.length - 1)
                    .trim();
          }
        } else {
          _shopAddress.text =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        }
      });
    } catch (e) {
      if (mounted)
        AppTheme.showSnack(
          context,
          'Failed to fetch location. Please try again.',
          isError: true,
        );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _next() {
    // Validation for Step 0 (Basic Info)
    if (_step == 0) {
      if (_profileImage == null) {
        AppTheme.showSnack(
          context,
          context.t('errorNoProfileImage'),
          isError: true,
        );
        return;
      }
      if (_fullName.text.trim().isEmpty) {
        AppTheme.showSnack(context, context.t('errorNoName'), isError: true);
        return;
      }
    }
    // Validation for Step 1 (Shop Details)
    if (_step == 1) {
      if (_shopName.text.trim().isEmpty) {
        AppTheme.showSnack(
          context,
          context.t('errorNoShopName'),
          isError: true,
        );
        return;
      }
      if (_shopAddress.text.trim().isEmpty) {
        AppTheme.showSnack(
          context,
          context.t('errorNoShopAddress'),
          isError: true,
        );
        return;
      }
      if (_shopImage == null) {
        AppTheme.showSnack(
          context,
          'Please select a Shop Photo',
          isError: true,
        );
        return;
      }
      if (_exactAddress.text.trim().isEmpty) {
        AppTheme.showSnack(
          context,
          context.t('errorNoExactAddress'),
          isError: true,
        );
        return;
      }
      if (_aadhaar.text.trim().length != 12) {
        AppTheme.showSnack(context, context.t('errorNoAadhaar'), isError: true);
        return;
      }
      if (!VerhoeffValidator.isValidAadhaar(_aadhaar.text)) {
        AppTheme.showSnack(
          context,
          context.t('errorInvalidAadhaar') ?? 'Invalid Aadhaar number. Please re-enter.',
          isError: true,
        );
        return;
      }
      if (_aadhaarFront == null) {
        AppTheme.showSnack(
          context,
          context.t('errorNoAadhaarFront'),
          isError: true,
        );
        return;
      }
      if (_aadhaarBack == null) {
        AppTheme.showSnack(
          context,
          context.t('errorNoAadhaarBack'),
          isError: true,
        );
        return;
      }
    }
    // Validation for Step 2 (Categories)
    if (_step == 2) {
      if (_categories.isEmpty && !_otherCategorySelected) {
        AppTheme.showSnack(
          context,
          context.t('errorNoCategories'),
          isError: true,
        );
        return;
      }
    }
    // Validation for Step 3 (Vehicle & Hours)
    if (_step == 3) {
      if (_vehicleTypes.isEmpty) {
        AppTheme.showSnack(context, context.t('errorNoVehicle'), isError: true);
        return;
      }
    }
    if (_step < 3) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      AuthService.instance.signOut();
      Navigator.pop(context);
    }
  }

  Future<String> _uploadToSupabase(File file, String folderPath) async {
    // Verify file exists
    if (!await file.exists()) {
      throw Exception('Image file does not exist at path: ${file.path}');
    }

    // Supabase Credentials
    const String projectId = 'jdmwvxghimqiwpsbbeak';
    const String anonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkbXd2eGdoaW1xaXdwc2JiZWFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2NzU3MTAsImV4cCI6MjA5NjI1MTcxMH0.qSw2mhDyVjrpCAvwfxPMaWYyIncrrAYjOEzdJYuoxd8';

    // Parse folderPath into bucketName and subPath (e.g. 'partners/$uid')
    final parts = folderPath.split('/');
    final bucketName = parts.first;
    final subPath = parts.skip(1).join('/');

    // Get unique file name
    final fileName = file.path.replaceAll('\\', '/').split('/').last;
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final finalPath =
        subPath.isNotEmpty ? '$subPath/$uniqueFileName' : uniqueFileName;

    // Detect Content-Type
    String contentType = 'image/jpeg';
    if (fileName.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    } else if (fileName.toLowerCase().endsWith('.gif')) {
      contentType = 'image/gif';
    }

    final url = Uri.parse(
      'https://$projectId.supabase.co/storage/v1/object/$bucketName/$finalPath',
    );
    final bytes = await file.readAsBytes();

    final response = await http.post(
      url,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return 'https://$projectId.supabase.co/storage/v1/object/public/$bucketName/$finalPath';
    } else {
      throw Exception(
        'Supabase upload failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    try {
      // Upload Images to Supabase
      final String profileUrl =
          _profileImage != null
              ? await _uploadToSupabase(_profileImage!, 'partners/$uid')
              : '';
      final String shopUrl =
          _shopImage != null
              ? await _uploadToSupabase(_shopImage!, 'partners/$uid')
              : '';
      final String aadhaarFrontUrl =
          _aadhaarFront != null
              ? await _uploadToSupabase(_aadhaarFront!, 'partners/$uid')
              : '';
      final String aadhaarBackUrl =
          _aadhaarBack != null
              ? await _uploadToSupabase(_aadhaarBack!, 'partners/$uid')
              : '';

      List<String> finalCategories = _categories.toList();
      if (_otherCategorySelected && _otherCategoryCtrl.text.trim().isNotEmpty) {
        finalCategories.addAll(
          _otherCategoryCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }

      final partner = PartnerModel(
        uid: uid,
        phone: phone,
        fullName: _fullName.text.trim(),
        shopName: _shopName.text.trim(),
        shopAddress: _shopAddress.text.trim(),
        exactShopAddress: _exactAddress.text.trim(),
        shopLat: _shopLat,
        shopLng: _shopLng,
        currentLat: _shopLat,
        currentLng: _shopLng,
        scrapCategories: finalCategories,
        gstNumber: _gst.text.trim().isEmpty ? null : _gst.text.trim(),
        aadhaarNumber: _aadhaar.text.trim(),
        profilePhotoUrl: profileUrl,
        shopPhotoUrl: shopUrl,
        aadhaarFrontUrl: aadhaarFrontUrl,
        aadhaarBackUrl: aadhaarBackUrl,
        vehicleTypes: _vehicleTypes.toList(),
        workingHoursStart: _workStart.format(context),
        workingHoursEnd: _workEnd.format(context),
        status: PartnerStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ok = await PartnerProvider().createPartnerProfile(partner);
      if (!mounted) return;

      if (ok) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
            (_) => false,
          );
        }
      } else {
        AppTheme.showSnack(context, context.t('regFailed'), isError: true);
      }
    } catch (e) {
      if (mounted)
        AppTheme.showSnack(
          context,
          'Failed to submit registration: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullName.dispose();
    _shopName.dispose();
    _shopAddress.dispose();
    _exactAddress.dispose();
    _gst.dispose();
    _aadhaar.dispose();
    _otherCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _prev();
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: ResponsiveWrapper(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _prev,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('partnerReg'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${context.t('step')} ${_step + 1} ${context.t('of')} 4 Â· ${_stepTitles[_step]}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_step + 1) / 4,
                            backgroundColor: AppTheme.border,
                            valueColor: const AlwaysStoppedAnimation(
                              AppTheme.primary,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StepBasicInfo(
                          nameCtrl: _fullName,
                          profileImage: _profileImage,
                          onPickImage: _pickImage,
                        ),
                        _StepShopDetails(
                          shopNameCtrl: _shopName,
                          shopAddressCtrl: _shopAddress,
                          exactAddressCtrl: _exactAddress,
                          gstCtrl: _gst,
                          aadhaarCtrl: _aadhaar,
                          shopImage: _shopImage,
                          aadhaarFront: _aadhaarFront,
                          aadhaarBack: _aadhaarBack,
                          onFetchLocation: _fetchLocation,
                          onClearLocation:
                              () => setState(() {
                                _shopAddress.clear();
                              }),
                          onPickShopImage: _pickShopImage,
                          onPickAadhaar: _pickAadhaarImage,
                          isFetchingLocation: _isFetchingLocation,
                        ),
                        _StepCategories(
                          options: _scrapOptions,
                          selected: _categories,
                          otherSelected: _otherCategorySelected,
                          otherCtrl: _otherCategoryCtrl,
                          onToggle:
                              (c) => setState(() {
                                if (_categories.contains(c))
                                  _categories.remove(c);
                                else
                                  _categories.add(c);
                              }),
                          onToggleOther:
                              (val) => setState(() {
                                _otherCategorySelected = val;
                                if (!val) _otherCategoryCtrl.clear();
                              }),
                        ),
                        _StepVehicle(
                          vehicles: _vehicles,
                          selectedTypes: _vehicleTypes,
                          workStart: _workStart,
                          workEnd: _workEnd,
                          onVehicle:
                              (v) => setState(() {
                                if (_vehicleTypes.contains(v)) {
                                  if (_vehicleTypes.length > 1)
                                    _vehicleTypes.remove(v);
                                } else {
                                  _vehicleTypes.add(v);
                                }
                              }),
                          onStartTime: (t) => setState(() => _workStart = t),
                          onEndTime: (t) => setState(() => _workEnd = t),
                        ),
                      ],
                    ),
                  ),

                  // Bottom button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: GradientButton(
                      label:
                          _step < 3
                              ? context.t('next')
                              : context.t('submitReg'),
                      onPressed: _next,
                      isLoading: _isLoading,
                      icon:
                          _step < 3
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Step 1: Basic Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepBasicInfo extends StatelessWidget {
  final TextEditingController nameCtrl;
  final File? profileImage;
  final VoidCallback onPickImage;

  const _StepBasicInfo({
    required this.nameCtrl,
    required this.profileImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            context.t('stepBasicInfoTitle'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('stepBasicInfoSub'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          // Profile photo placeholder
          Center(
            child: GestureDetector(
              onTap: onPickImage,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  image:
                      profileImage != null
                          ? DecorationImage(
                            image: FileImage(profileImage!),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    profileImage == null
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: AppTheme.primary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t('profilePhoto'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                        : null,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _label(context.t('fullName')),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. Ramesh Kumar Sharma',
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('nameVerifiedInfo'),
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
  );
}

// â”€â”€ Step 2: Shop Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepShopDetails extends StatelessWidget {
  final TextEditingController shopNameCtrl,
      shopAddressCtrl,
      exactAddressCtrl,
      gstCtrl,
      aadhaarCtrl;
  final File? shopImage, aadhaarFront, aadhaarBack;
  final VoidCallback onFetchLocation;
  final VoidCallback onClearLocation;
  final VoidCallback onPickShopImage;
  final Function(bool isFront) onPickAadhaar;
  final bool isFetchingLocation;

  const _StepShopDetails({
    required this.shopNameCtrl,
    required this.shopAddressCtrl,
    required this.exactAddressCtrl,
    required this.gstCtrl,
    required this.aadhaarCtrl,
    required this.shopImage,
    required this.aadhaarFront,
    required this.aadhaarBack,
    required this.onFetchLocation,
    required this.onClearLocation,
    required this.onPickShopImage,
    required this.onPickAadhaar,
    required this.isFetchingLocation,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            context.t('shopDetailsTitle'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('shopDetailsSub'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _label(context.t('shopName')),
          const SizedBox(height: 8),
          TextFormField(
            controller: shopNameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Ramesh Scrap & Recyclers',
              prefixIcon: Icon(
                Icons.store_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Shop Location Verification Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.subtleShadow,
              border: Border.all(
                color:
                    isFetchingLocation
                        ? AppTheme.primary
                        : shopAddressCtrl.text.isNotEmpty
                        ? AppTheme.primary.withOpacity(0.4)
                        : AppTheme.border,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isFetchingLocation
                                ? AppTheme.primaryLight
                                : shopAddressCtrl.text.isNotEmpty
                                ? AppTheme.primaryLight
                                : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFetchingLocation
                            ? Icons.my_location_rounded
                            : shopAddressCtrl.text.isNotEmpty
                            ? Icons.verified_user_rounded
                            : Icons.location_off_rounded,
                        color:
                            isFetchingLocation
                                ? AppTheme.primary
                                : shopAddressCtrl.text.isNotEmpty
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('shopLocation') ?? 'Shop GPS Location',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFetchingLocation
                                ? 'Pinpointing GPS location...'
                                : shopAddressCtrl.text.isNotEmpty
                                ? 'Location mapped successfully'
                                : 'GPS location is required for routing pickups',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  isFetchingLocation
                                      ? AppTheme.primary
                                      : shopAddressCtrl.text.isNotEmpty
                                      ? AppTheme.primaryDark
                                      : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isFetchingLocation) ...[
                  // Inline Loader
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Locating shop coordinates via GPS...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (shopAddressCtrl.text.isEmpty) ...[
                  // Mapped location empty state (Action Button)
                  GestureDetector(
                    onTap: onFetchLocation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.t('fetchLocation') ??
                                'Use Current GPS Location',
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Resolved Mapped Location State
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.pin_drop_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                shopAddressCtrl.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: onFetchLocation,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                label: const Text(
                                  'Recalibrate GPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onClearLocation,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _label(
            context.t('exactAddress') ??
                'Exact Shop Address (Shop No, Building)',
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: exactAddressCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText:
                  context.t('exactAddressHint') ??
                  'e.g. Shop No. 12, Ground Floor',
              prefixIcon: const Icon(
                Icons.home_work_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _label('${context.t('gstOptional')}'),
          const SizedBox(height: 8),
          TextFormField(
            controller: gstCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            decoration: const InputDecoration(
              hintText: 'e.g. 07AABCU9603R1ZP',
              prefixIcon: Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _label('Shop Photo (Mandatory)'),
          const SizedBox(height: 8),
          _buildImagePicker(
            context,
            shopImage,
            'Shop Photo',
            () => onPickShopImage(),
          ),
          const SizedBox(height: 20),
          _label(context.t('aadhaarRequired') ?? 'Aadhaar Number'),
          const SizedBox(height: 8),
          TextFormField(
            controller: aadhaarCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: const InputDecoration(
              hintText: 'XXXX XXXX XXXX',
              prefixIcon: Icon(
                Icons.credit_card_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildImagePicker(
                  context,
                  aadhaarFront,
                  context.t('aadhaarFront') ?? 'Aadhaar Front',
                  () => onPickAadhaar(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildImagePicker(
                  context,
                  aadhaarBack,
                  context.t('aadhaarBack') ?? 'Aadhaar Back',
                  () => onPickAadhaar(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    File? file,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
              image:
                  file != null
                      ? DecorationImage(
                        image: FileImage(file),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                file == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                    : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
  );
}

// â”€â”€ Step 3: Scrap Categories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepCategories extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final bool otherSelected;
  final TextEditingController otherCtrl;
  final Function(String) onToggle;
  final Function(bool) onToggleOther;

  const _StepCategories({
    required this.options,
    required this.selected,
    required this.otherSelected,
    required this.otherCtrl,
    required this.onToggle,
    required this.onToggleOther,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            context.t('categoriesTitle'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('categoriesSub'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${selected.length + (otherSelected ? 1 : 0)} ${context.t('selected')}',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...options.map((cat) {
                final isSelected = selected.contains(cat);
                return GestureDetector(
                  onTap: () => onToggle(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.border,
                        width: 1.5,
                      ),
                      boxShadow:
                          isSelected
                              ? AppTheme.elevatedShadow
                              : AppTheme.subtleShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          cat,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => onToggleOther(!otherSelected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: otherSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: otherSelected ? AppTheme.primary : AppTheme.border,
                      width: 1.5,
                    ),
                    boxShadow:
                        otherSelected
                            ? AppTheme.elevatedShadow
                            : AppTheme.subtleShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (otherSelected) ...[
                        const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        context.t('otherCategory') ?? 'Other',
                        style: TextStyle(
                          color:
                              otherSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (otherSelected) ...[
            const SizedBox(height: 20),
            TextFormField(
              controller: otherCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText:
                    context.t('enterOtherCategory') ?? 'Enter Custom Category',
                prefixIcon: const Icon(
                  Icons.add_box_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('categoriesInfo'),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Step 4: Vehicle & Hours â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StepVehicle extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final Set<VehicleType> selectedTypes;
  final TimeOfDay workStart, workEnd;
  final Function(VehicleType) onVehicle;
  final Function(TimeOfDay) onStartTime, onEndTime;

  const _StepVehicle({
    required this.vehicles,
    required this.selectedTypes,
    required this.workStart,
    required this.workEnd,
    required this.onVehicle,
    required this.onStartTime,
    required this.onEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            context.t('vehicleTitle'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('vehicleSub'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          Text(
            context.t('vehicleTypeLabel'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...vehicles.map((v) {
            final isSelected = selectedTypes.contains(v['type']);
            return GestureDetector(
              onTap: () => onVehicle(v['type'] as VehicleType),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppTheme.primary
                                : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        v['icon'] as IconData,
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      v['label'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 28),

          // â”€â”€ Working Hours Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Text(
            context.t('workingHoursLabel'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Localizations.localeOf(context).languageCode == 'hi'
                ? 'à¤†à¤ª à¤•à¤¬ à¤‘à¤°à¥à¤¡à¤° à¤¸à¥à¤µà¥€à¤•à¤¾à¤° à¤•à¤° à¤¸à¤•à¤¤à¥‡ à¤¹à¥ˆà¤‚?'
                : 'When are you available to accept orders?',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),

          // Quick Preset Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _hoursPreset(context, 'ðŸŒ… Morning', const TimeOfDay(hour: 6, minute: 0), const TimeOfDay(hour: 14, minute: 0), workStart, workEnd, onStartTime, onEndTime),
              _hoursPreset(context, 'â˜€ï¸ Day Shift', const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 18, minute: 0), workStart, workEnd, onStartTime, onEndTime),
              _hoursPreset(context, 'ðŸŒ† Evening', const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 22, minute: 0), workStart, workEnd, onStartTime, onEndTime),
              _hoursPreset(context, 'ðŸ•’ Full Day', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0), workStart, workEnd, onStartTime, onEndTime),
            ],
          ),
          const SizedBox(height: 16),

          // Visual Schedule Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      Localizations.localeOf(context).languageCode == 'hi'
                          ? 'à¤†à¤ªà¤•à¤¾ à¤•à¤¾à¤® à¤•à¤¾ à¤¸à¤®à¤¯'
                          : 'Your Working Schedule',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // Duration badge
                    Builder(builder: (ctx) {
                      final startMins = workStart.hour * 60 + workStart.minute;
                      final endMins = workEnd.hour * 60 + workEnd.minute;
                      final dur = endMins > startMins ? endMins - startMins : (24 * 60 - startMins + endMins);
                      final h = dur ~/ 60;
                      final m = dur % 60;
                      final label = m == 0 ? '${h}h' : '${h}h ${m}m';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // START TIME
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: workStart,
                            helpText: Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¶à¥à¤°à¥‚ à¤•à¤¾ à¤¸à¤®à¤¯' : 'Start Time',
                          );
                          if (t != null) onStartTime(t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¶à¥à¤°à¥‚' : 'Starts',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                workStart.format(context),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¬à¤¦à¤²à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤Ÿà¥ˆà¤ª à¤•à¤°à¥‡à¤‚' : 'Tap to change',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Arrow
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 20),
                          const SizedBox(height: 2),
                          Text(
                            Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¤à¤•' : 'to',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    // END TIME
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: workEnd,
                            helpText: Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¬à¤‚à¤¦ à¤•à¤¾ à¤¸à¤®à¤¯' : 'End Time',
                          );
                          if (t != null) onEndTime(t);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nights_stay_rounded, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¬à¤‚à¤¦' : 'Ends',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                workEnd.format(context),
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Localizations.localeOf(context).languageCode == 'hi' ? 'à¤¬à¤¦à¤²à¤¨à¥‡ à¤•à¥‡ à¤²à¤¿à¤ à¤Ÿà¥ˆà¤ª à¤•à¤°à¥‡à¤‚' : 'Tap to change',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('allSetInfo'),
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: quick-select preset chip for working hours
  Widget _hoursPreset(
    BuildContext context,
    String label,
    TimeOfDay presetStart,
    TimeOfDay presetEnd,
    TimeOfDay currentStart,
    TimeOfDay currentEnd,
    Function(TimeOfDay) onStartTime,
    Function(TimeOfDay) onEndTime,
  ) {
    final isSelected = currentStart.hour == presetStart.hour &&
        currentStart.minute == presetStart.minute &&
        currentEnd.hour == presetEnd.hour &&
        currentEnd.minute == presetEnd.minute;
    return GestureDetector(
      onTap: () {
        onStartTime(presetStart);
        onEndTime(presetEnd);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected ? AppTheme.subtleShadow : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
