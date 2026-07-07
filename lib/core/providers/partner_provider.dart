import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_model.dart';
import '../utils/cache_utils.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class PartnerProvider extends ChangeNotifier {
  static final PartnerProvider _instance = PartnerProvider._internal();
  factory PartnerProvider() => _instance;
  PartnerProvider._internal();

  PartnerModel _partner = PartnerModel.empty();
  bool _isLoading = false;
  bool _isOnline = false;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _partnerSub;
  DateTime? _lastPartnerCacheWriteTime;

  // Track location permission override in state
  bool _locationAllowed = true;

  PartnerModel get partner => _partner;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  bool get isApproved => _partner.isApproved;
  bool get hasProfile => _partner.uid.isNotEmpty;
  bool get locationAllowed => _locationAllowed;
  bool get isCommissionBlocked => _partner.shouldBlockForCommission;

  final _db = FirebaseFirestore.instance;

  Future<void> loadPartner() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // ── Try loading cached partner details locally first ──────────────
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_partner_$uid');
      if (cachedJson != null) {
        try {
          final Map<String, dynamic> data = CacheUtils.decode(cachedJson);
          _partner = PartnerModel.fromJson(data);
          _isOnline = _partner.isOnline;
          // Notify listeners immediately so the UI is populated while Firestore queries
          notifyListeners();
        } catch (_) {}
      }

      final doc = await _db.collection('partners').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _partner = PartnerModel.fromJson(doc.data()!);
        _isOnline = _partner.isOnline;
        
        // Cache the fresh profile
        await prefs.setString('cached_partner_$uid', CacheUtils.encode(doc.data()!));
      }
      // Load saved permission settings
      final savedAllowed = prefs.getBool('location_allowed') ?? true;
      _locationAllowed = savedAllowed && await _isGpsReady();
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream partner updates in real-time
  void listenToPartner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _partnerSub?.cancel();
    _partnerSub = _db.collection('partners').doc(uid).snapshots().listen((doc) async {
      if (doc.exists && doc.data() != null) {
        final newPartner = PartnerModel.fromJson(doc.data()!);
        final isOnlineChanged = _isOnline != newPartner.isOnline;
        _partner = newPartner;
        _isOnline = _partner.isOnline;
        
        final prefs = await SharedPreferences.getInstance();
        
        // Cache the fresh profile updates (throttled to max once per 30 seconds or on online status changes)
        final now = DateTime.now();
        if (_lastPartnerCacheWriteTime == null ||
            isOnlineChanged ||
            now.difference(_lastPartnerCacheWriteTime!) > const Duration(seconds: 30)) {
          _lastPartnerCacheWriteTime = now;
          await prefs.setString('cached_partner_$uid', CacheUtils.encode(doc.data()!));
        }
        
        final savedAllowed = prefs.getBool('location_allowed') ?? true;
        _locationAllowed = savedAllowed && await _isGpsReady();
        
        // Enforce offline if location permission or commission status blocks orders.
        if ((!_locationAllowed || _partner.shouldBlockForCommission) && _isOnline) {
          await toggleOnline(false);
        } else if (_isOnline) {
          LocationTrackingService.instance.startTracking();
          NotificationService.instance.startLocalLeadListener(_partner);
        } else {
          LocationTrackingService.instance.stopTracking();
          NotificationService.instance.stopLocalLeadListener();
        }
        notifyListeners();
      }
    });
  }

  Future<void> toggleOnline(bool online) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Prevent online if location access is overridden off
    if (online && !_locationAllowed) {
      _locationAllowed = await _isGpsReady();
    }

    if (online && !_locationAllowed) {
      _error = 'Turn on GPS and allow location permission to receive instant pickups.';
      notifyListeners();
      return;
    }

    if (online && _partner.shouldBlockForCommission) {
      _error =
          'Commission payment is due. Pay Scrapwell commission to receive more orders.';
      notifyListeners();
      return;
    }

    _isOnline = online;
    notifyListeners();

    try {
      // ── 1. Update partners doc ─────────────────────────────────────────
      await _db.collection('partners').doc(uid).update({
        'isOnline': online,
        'isAvailable': online,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── 2. Immediately mirror online/availability into live_locations ──
      // This ensures instant-pickup broadcasts stop reaching this partner
      // the moment they go offline — without waiting for the next GPS tick.
      final updates = <String, dynamic>{
        'isOnline': online,
        'isAvailable': online,
        'updatedAt': FieldValue.serverTimestamp(),
        // Cache radius so instant-pickup filter reads it from live_locations
        'maxDistanceKm': _partner.maxDistanceKm,
        if (!online) 'assignedOrderId': null,
      };

      if (online) {
        final lat = _partner.currentLat != 0.0 ? _partner.currentLat : _partner.shopLat;
        final lng = _partner.currentLng != 0.0 ? _partner.currentLng : _partner.shopLng;
        if (lat != 0.0 && lng != 0.0) {
          updates['latitude'] = lat;
          updates['longitude'] = lng;
          updates['position'] = {
            'geohash': '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
            'geopoint': GeoPoint(lat, lng),
          };
        }
      }

      await _db.collection('live_locations').doc(uid).set(updates, SetOptions(merge: true));

      _error = null;
      if (online) {
        await LocationTrackingService.instance.startTracking();
        NotificationService.instance.startLocalLeadListener(_partner);
      } else {
        LocationTrackingService.instance.stopTracking();
        NotificationService.instance.stopLocalLeadListener();
      }
    } catch (e) {
      _isOnline = !online;
      notifyListeners();
    }
  }

  Future<void> setLocationAllowed(bool allowed) async {
    _locationAllowed = allowed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_allowed', allowed);
    
    // Take offline if disabled
    if (!allowed && _isOnline) {
      await toggleOnline(false);
    }
    notifyListeners();
  }

  double _currentHeading = 0.0;
  double get currentHeading => _currentHeading;

  Future<void> updateLocation(double lat, double lng, {double heading = 0.0}) async {
    _currentHeading = heading;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!_locationAllowed) return; // Prevent GPS writes if disallowed

    try {
      await _db.collection('partners').doc(uid).update({
        'currentLat': lat,
        'currentLng': lng,
        'position': {
          'geopoint': GeoPoint(lat, lng),
          'geohash': '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<bool> createPartnerProfile(PartnerModel partner) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _db.collection('partners').doc(partner.uid);

      final registrationData = {
        'uid': partner.uid,
        'phone': partner.phone,
        'fullName': partner.fullName,
        'shopName': partner.shopName,
        'shopAddress': partner.shopAddress,
        'exactShopAddress': partner.exactShopAddress,
        'shopLat': partner.shopLat,
        'shopLng': partner.shopLng,
        'currentLat': partner.shopLat,
        'currentLng': partner.shopLng,
        'isOnline': false,
        'isAvailable': false,
        'commissionDueBalance': 0.0,
        'commissionTotalBilled': 0.0,
        'commissionBlocked': false,
        'scrapCategories': partner.scrapCategories,
        'profilePhotoUrl': partner.profilePhotoUrl,
        'shopPhotoUrl': partner.shopPhotoUrl,
        'gstNumber': partner.gstNumber,
        'aadhaarNumber': partner.aadhaarNumber,
        'aadhaarFrontUrl': partner.aadhaarFrontUrl,
        'aadhaarBackUrl': partner.aadhaarBackUrl,
        'vehicleTypes': partner.vehicleTypes.map((e) => e.name).toList(),
        'workingHoursStart': partner.workingHoursStart,
        'workingHoursEnd': partner.workingHoursEnd,
        'status': partner.status.name, // 'pending'
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'position': {
          'geohash': '${partner.shopLat.toStringAsFixed(3)}_${partner.shopLng.toStringAsFixed(3)}',
          'geopoint': GeoPoint(partner.shopLat, partner.shopLng),
        },
      };

      await docRef.set(registrationData, SetOptions(merge: true));

      await loadPartner();
      
      // Update FCM push token for the newly created profile
      await NotificationService.instance.updateFcmToken();

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePartnerField(String field, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('partners').doc(uid).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshLocationAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAllowed = prefs.getBool('location_allowed') ?? true;
    _locationAllowed = savedAllowed && await _checkGpsOnly();
    if (!_locationAllowed && _isOnline) {
      await toggleOnline(false);
    }
    notifyListeners();
  }

  Future<bool> _checkGpsOnly() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> promptAndEnableGps(BuildContext context) async {
    final hi = Localizations.localeOf(context).languageCode == 'hi';
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(hi ? 'स्थान (GPS) अक्षम है' : 'GPS is Disabled', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(hi 
              ? 'कृपया जारी रखने के लिए अपने डिवाइस का स्थान (GPS) सक्षम करें।' 
              : 'Please enable device location (GPS) to go online and receive orders.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(hi ? 'रद्द करें' : 'Cancel', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(hi ? 'सेटिंग्स खोलें' : 'Open Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (proceed == true) {
          await Geolocator.openLocationSettings();
        }
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        AppTheme.showSnack(
          context,
          hi 
              ? 'स्थान अनुमति स्थायी रूप से अस्वीकार कर दी गई है। कृपया इसे सेटिंग्स में सक्षम करें।' 
              : 'Location permission permanently denied. Please enable it in app settings.',
          isError: true,
        );
        await Geolocator.openAppSettings();
      }
      return false;
    }

    final allowed = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    
    await setLocationAllowed(allowed);
    return allowed;
  }

  Future<bool> _isGpsReady() async {
    return _checkGpsOnly();
  }

  // -- Compliance Stack Direct Firestore Mutations --

  /// Save bank details and mark as verified
  Future<bool> updateBankDetails(String accountName, String accountNo, String ifsc) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('partners').doc(uid).update({
        'bankAccountName': accountName,
        'bankAccountNumber': accountNo,
        'bankIfsc': ifsc,
        'bankVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _partner = _partner.copyWith(
        bankAccountName: accountName,
        bankAccountNumber: accountNo,
        bankIfsc: ifsc,
        bankVerified: true,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save UPI ID and mark as verified
  Future<bool> updateUpiDetails(String upiId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('partners').doc(uid).update({
        'upiId': upiId,
        'bankVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _partner = _partner.copyWith(
        upiId: upiId,
        bankVerified: true,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save Aadhaar details, tokenized hash, and mark as verified
  Future<bool> verifyAadhaar(String aadhaarNo, String frontUrl, String backUrl, String secureHash) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('partners').doc(uid).update({
        'aadhaarNumber': aadhaarNo,
        'aadhaarFrontUrl': frontUrl,
        'aadhaarBackUrl': backUrl,
        'aadhaarHash': secureHash,
        'aadhaarVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _partner = _partner.copyWith(
        aadhaarNumber: aadhaarNo,
        aadhaarFrontUrl: frontUrl,
        aadhaarBackUrl: backUrl,
        aadhaarHash: secureHash,
        aadhaarVerified: true,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save location mapping details and mark address verified
  Future<bool> updateBusinessAddress(String address, double lat, double lng) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('partners').doc(uid).update({
        'shopAddress': address,
        'shopLat': lat,
        'shopLng': lng,
        'addressVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _partner = _partner.copyWith(
        shopAddress: address,
        shopLat: lat,
        shopLng: lng,
        addressVerified: true,
      );

      if (_isOnline) {
        final currentLat = _partner.currentLat != 0.0 ? _partner.currentLat : lat;
        final currentLng = _partner.currentLng != 0.0 ? _partner.currentLng : lng;

        await _db.collection('live_locations').doc(uid).set({
          'latitude': currentLat,
          'longitude': currentLng,
          'position': {
            'geohash': '${currentLat.toStringAsFixed(3)}_${currentLng.toStringAsFixed(3)}',
            'geopoint': GeoPoint(currentLat, currentLng),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update business profile name / GST status
  Future<bool> updateBusinessInfo(String shopName, String? gstNumber, String? shopPhotoUrl) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updates = {
        'shopName': shopName,
        'gstNumber': gstNumber,
        'businessInfoVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (shopPhotoUrl != null && shopPhotoUrl.isNotEmpty) {
        updates['shopPhotoUrl'] = shopPhotoUrl;
        updates['shopPhotosVerified'] = true;
      }
      await _db.collection('partners').doc(uid).update(updates);
      _partner = _partner.copyWith(
        shopName: shopName,
        gstNumber: gstNumber,
        businessInfoVerified: true,
        shopPhotoUrl: shopPhotoUrl ?? _partner.shopPhotoUrl,
        shopPhotosVerified: shopPhotoUrl != null ? true : _partner.shopPhotosVerified,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request account deletion (completely purges Firestore document and FirebaseAuth account)
  Future<bool> deleteAccountRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Delete Firestore document completely
      await _db.collection('partners').doc(uid).delete();
      
      // 2. Delete the user authentication record in Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }
      
      _partner = PartnerModel.empty();
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      // Force exit sign out if delete throws recent-login exception
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> updateSearchRadius(double km) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // ── Update partners doc ───────────────────────────────────────────
      await _db.collection('partners').doc(uid).update({
        'maxDistanceKm': km,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── Mirror maxDistanceKm into live_locations ──────────────────────
      // Instant-pickup stream reads maxDistanceKm from live_locations to
      // avoid a second collection read. Keep them in sync on every change.
      if (_isOnline) {
        final lat = _partner.currentLat != 0.0 ? _partner.currentLat : _partner.shopLat;
        final lng = _partner.currentLng != 0.0 ? _partner.currentLng : _partner.shopLng;
        final updates = <String, dynamic>{
          'maxDistanceKm': km,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (lat != 0.0 && lng != 0.0) {
          updates['latitude'] = lat;
          updates['longitude'] = lng;
          updates['position'] = {
            'geohash': '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}',
            'geopoint': GeoPoint(lat, lng),
          };
        }
        await _db.collection('live_locations').doc(uid).set(updates, SetOptions(merge: true));
      }

      _partner = _partner.copyWith(maxDistanceKm: km);
      notifyListeners();
    } catch (_) {}
  }

  void reset() {
    _partnerSub?.cancel();
    _partnerSub = null;
    LocationTrackingService.instance.stopTracking();
    NotificationService.instance.stopLocalLeadListener();
    _partner = PartnerModel.empty();
    _isOnline = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

/// Global locale notifier for instant language switching
final ValueNotifier<String> localeNotifier = ValueNotifier('en');

Future<void> initLocale() async {
  final prefs = await SharedPreferences.getInstance();
  localeNotifier.value = prefs.getString('language') ?? 'en';
}

Future<void> saveLocale(String lang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language', lang);
  localeNotifier.value = lang;
}
