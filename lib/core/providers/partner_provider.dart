import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_model.dart';

class PartnerProvider extends ChangeNotifier {
  static final PartnerProvider _instance = PartnerProvider._internal();
  factory PartnerProvider() => _instance;
  PartnerProvider._internal();

  PartnerModel _partner = PartnerModel.empty();
  bool _isLoading = false;
  bool _isOnline = false;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _partnerSub;

  PartnerModel get partner => _partner;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  bool get isApproved => _partner.isApproved;
  bool get hasProfile => _partner.uid.isNotEmpty;

  final _db = FirebaseFirestore.instance;

  Future<void> loadPartner() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _db.collection('partners').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _partner = PartnerModel.fromJson(doc.data()!);
        _isOnline = _partner.isOnline;
      }
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
    _partnerSub = _db.collection('partners').doc(uid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        _partner = PartnerModel.fromJson(doc.data()!);
        _isOnline = _partner.isOnline;
        notifyListeners();
      }
    });
  }

  Future<void> toggleOnline(bool online) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isOnline = online;
    notifyListeners();

    try {
      await _db.collection('partners').doc(uid).update({
        'isOnline': online,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Revert on failure
      _isOnline = !online;
      notifyListeners();
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

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
      await _db
          .collection('partners')
          .doc(partner.uid)
          .set(partner.toJson());
      _partner = partner;
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _partnerSub?.cancel();
    _partnerSub = null;
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
