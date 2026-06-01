import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
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
        return File(pickedFile.path);
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
      if (mounted)
        AppTheme.showSnack(
          context,
          'Location services are disabled.',
          isError: true,
        );
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
          'Location permissions are permanently denied.',
          isError: true,
        );
      return;
    }

    if (mounted) AppTheme.showSnack(context, 'Fetching location...');
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
          _shopAddress.text =
              '${place.subLocality}, ${place.locality}, ${place.postalCode}'
                  .replaceAll(', ,', ',');
        }
      });
    } catch (e) {
      if (mounted)
        AppTheme.showSnack(context, 'Failed to fetch location.', isError: true);
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
      Navigator.pop(context);
    }
  }

  Future<String> _uploadToCloudinary(File file, String folderPath) async {
    // Compress image locally first
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'\.jp|\.png|\.jpeg'));
    String outPath;
    if (lastIndex == -1) {
      outPath = '${filePath}_out.jpg';
    } else {
      outPath = '${filePath.substring(0, lastIndex)}_out${filePath.substring(lastIndex)}';
    }
    
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, 
      outPath,
      quality: 70,
    );
    
    final uploadFile = result != null ? File(result.path) : file;

    const cloudName = 'dxw2a6qre';
    const apiKey = '869265725253875';
    const apiSecret = 'FpxbdxUTzQtj7m1hlmSlAQofaVo';
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();

    // Alphabetical order for signature: folder, timestamp
    final paramsToSign = 'folder=$folderPath&timestamp=$timestamp$apiSecret';
    final bytes = utf8.encode(paramsToSign);
    final signature = sha1.convert(bytes).toString();

    var request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'));
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp;
    request.fields['signature'] = signature;
    request.fields['folder'] = folderPath;
    
    request.files.add(await http.MultipartFile.fromPath('file', uploadFile.path));
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonMap = jsonDecode(responseData);
    
    if (response.statusCode == 200) {
      return jsonMap['secure_url'];
    } else {
      throw Exception('Cloudinary upload failed: ${jsonMap["error"]["message"]}');
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    try {
      // Upload Images to Cloudinary
      final String profileUrl =
          _profileImage != null
              ? await _uploadToCloudinary(_profileImage!, 'partners/$uid')
              : '';
      final String shopUrl =
          _shopImage != null
              ? await _uploadToCloudinary(_shopImage!, 'partners/$uid')
              : '';
      final String aadhaarFrontUrl =
          _aadhaarFront != null
              ? await _uploadToCloudinary(
                _aadhaarFront!,
                'partners/$uid',
              )
              : '';
      final String aadhaarBackUrl =
          _aadhaarBack != null
              ? await _uploadToCloudinary(
                _aadhaarBack!,
                'partners/$uid',
              )
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
        try {
          final url = Uri.parse(
            'https://wa.me/918744081962?text=New%20Vendor%20Registration%20Alert:%20${partner.shopName}%20needs%20verification.',
          );
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          // ignore WhatsApp error
        }

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
          'Failed to submit registration. Please try again.',
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
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
                                '${context.t('step')} ${_step + 1} ${context.t('of')} 4 · ${_stepTitles[_step]}',
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
                  label: _step < 3 ? context.t('next') : context.t('submitReg'),
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
    );
  }
}

// ── Step 1: Basic Info ─────────────────────────────────────────────────────

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

// ── Step 2: Shop Details ──────────────────────────────────────────────────

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
          Row(children: [Expanded(child: _label(context.t('shopAddress')))]),
          const SizedBox(height: 8),
          shopAddressCtrl.text.isEmpty
              ? GestureDetector(
                onTap: onFetchLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t('fetchLocation') ??
                              'Fetch Location from Map',
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        shopAddressCtrl.text,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onClearLocation,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
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

// ── Step 3: Scrap Categories ───────────────────────────────────────────────

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

// ── Step 4: Vehicle & Hours ────────────────────────────────────────────────

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

          const SizedBox(height: 24),
          Text(
            context.t('workingHoursLabel'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  context,
                  context.t('opensAt') ?? 'Opens at',
                  workStart,
                  () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: workStart,
                    );
                    if (t != null) onStartTime(t);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeTile(
                  context,
                  context.t('closesAt') ?? 'Closes at',
                  workEnd,
                  () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: workEnd,
                    );
                    if (t != null) onEndTime(t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
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

  Widget _timeTile(
    BuildContext context,
    String label,
    TimeOfDay time,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
