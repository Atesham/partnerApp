import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/partner_provider.dart';
import '../providers/order_provider.dart';

class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._();
  LocationTrackingService._() {
    _initServiceStatusListener();
  }

  final _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  bool _isTracking = false;

  double? _lastUploadedLat;
  double? _lastUploadedLng;
  DateTime? _lastUploadTime;

  bool get isTracking => _isTracking;

  void _initServiceStatusListener() {
    _serviceStatusSub?.cancel();
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        stopTracking();
        PartnerProvider().refreshLocationAvailability();
      }
    });
  }

  /// Request location permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Start location tracking — marks partner as live in live_locations
  Future<void> startTracking() async {
    if (_isTracking) return;
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    _isTracking = true;

    // Mark live_locations as online immediately (before first GPS tick)
    await _markLiveAvailability(isOnline: true, isAvailable: true);

    // ── CRITICAL: Get current position RIGHT NOW so live_locations has a valid
    // lat/lng immediately. Without this, orders created in the next 2 minutes
    // would not be routed to this partner because pLat/pLng === 0.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _uploadLocation(position);
    } catch (_) {
      // If getCurrentPosition fails (e.g. cold GPS fix), the stream will
      // still pick up the position within the first interval tick.
    }

    _setupTrackingStream();

    // Listen to order status changes to dynamically adjust tracking interval
    OrderProvider().addListener(_onOrderStatusChanged);
  }

  /// Stop location tracking — marks partner as offline in live_locations
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    if (!_isTracking) return;
    _isTracking = false;
    OrderProvider().removeListener(_onOrderStatusChanged);

    // Mark offline in live_locations immediately — no order will be routed
    _markLiveAvailability(isOnline: false, isAvailable: false);
  }

  void _onOrderStatusChanged() {
    if (!_isTracking) return;
    _setupTrackingStream();
  }

  void _setupTrackingStream() {
    _positionSub?.cancel();

    final hasActiveOrder = OrderProvider().hasActiveOrder;
    const distanceFilter = 20; // 20 meters minimum moved for high accuracy
    final interval = hasActiveOrder
        ? const Duration(seconds: 10)  // fast updates when on active order
        : const Duration(seconds: 60); // 60s idle — battery-efficient

    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      intervalDuration: interval,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Scrapwell Partner Active",
        notificationText:
            "Scrapwell is tracking your live location for pickup discoverability",
      ),
    );

    final appleSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    final selectedSettings =
        _getPlatformSettings(androidSettings, appleSettings, locationSettings);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: selectedSettings,
    ).listen(
      (Position position) {
        _uploadLocation(position);
      },
      onError: (error) {
        stopTracking();
        PartnerProvider().refreshLocationAvailability();
      },
    );
  }

  LocationSettings _getPlatformSettings(
    AndroidSettings android,
    AppleSettings apple,
    LocationSettings fallback,
  ) {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) return android;
      if (defaultTargetPlatform == TargetPlatform.iOS) return apple;
    } catch (_) {}
    return fallback;
  }

  Future<void> _uploadLocation(Position position) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final partner = PartnerProvider().partner;
    if (!PartnerProvider().locationAllowed) return;

    final now = DateTime.now();

    // Stationary filtering to save battery / network data
    final double? lastLat = _lastUploadedLat;
    final double? lastLng = _lastUploadedLng;
    bool shouldUpload = false;

    if (lastLat == null || lastLng == null) {
      shouldUpload = true;
    } else {
      final distance = Geolocator.distanceBetween(
        lastLat,
        lastLng,
        position.latitude,
        position.longitude,
      );
      final timeSinceLastUpload = _lastUploadTime != null
          ? now.difference(_lastUploadTime!)
          : const Duration(minutes: 6);

      // Upload if moved >= 20 meters, or if on active order, or if last upload was >= 5 minutes ago (heartbeat)
      if (distance >= 20.0 || OrderProvider().hasActiveOrder || timeSinceLastUpload.inMinutes >= 5) {
        shouldUpload = true;
      }
    }

    if (!shouldUpload) return;

    _lastUploadedLat = position.latitude;
    _lastUploadedLng = position.longitude;
    _lastUploadTime = now;

    final geohash = _geohash(position.latitude, position.longitude);

    // ── 1. Update partners/{uid} with current GPS coordinates ──────────────
    // This enables fast fallback lookups for scheduled order auto-assignment
    // without having to join live_locations.
    PartnerProvider().updateLocation(
      position.latitude,
      position.longitude,
      heading: position.heading,
    );

    // ── 2. Write to live_locations/{uid} with full live availability data ──
    // This is the primary lookup table for instant pickup broadcasts.
    // Fields written here drive the entire Instant Pickup → Radius Filter pipeline.
    try {
      final docRef = _db.collection('live_locations').doc(uid);

      // Determine availability — not available if actively on an instant order
      final hasActiveOrder = OrderProvider().hasActiveOrder;
      final isAvailable = !hasActiveOrder;

      await docRef.set({
        'partnerId': uid,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'accuracy': position.accuracy,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),

        // ── Live availability flags ─────────────────────────────────────────
        'isOnline': true,
        'isAvailable': isAvailable,

        // Cache partner's radius preference so instant-pickup filter is instant
        // (no need to read partners doc to know the partner's coverage radius)
        'maxDistanceKm': partner.maxDistanceKm,

        // Geo-index for Firestore geoqueries (geoflutterfire_plus compatible)
        'position': {
          'geohash': geohash,
          'geopoint': GeoPoint(position.latitude, position.longitude),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Mark the partner's online/available status in live_locations without
  /// waiting for the next GPS tick. Called immediately on toggle and on stop.
  Future<void> _markLiveAvailability({
    required bool isOnline,
    required bool isAvailable,
    String? assignedOrderId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final updates = <String, dynamic>{
        'isOnline': isOnline,
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (assignedOrderId != null) {
        updates['assignedOrderId'] = assignedOrderId;
      } else if (!isAvailable && isOnline) {
        // On active order — keep assignedOrderId as-is (set by acceptInstantOrder)
      } else if (!isOnline) {
        // Going offline — clear any assigned order reference
        updates['assignedOrderId'] = null;
      }

      if (isOnline) {
        final partner = PartnerProvider().partner;
        final lat = partner.currentLat != 0.0 ? partner.currentLat : partner.shopLat;
        final lng = partner.currentLng != 0.0 ? partner.currentLng : partner.shopLng;
        updates['maxDistanceKm'] = partner.maxDistanceKm;

        if (lat != 0.0 && lng != 0.0) {
          updates['latitude'] = lat;
          updates['longitude'] = lng;
          updates['position'] = {
            'geohash': _geohash(lat, lng),
            'geopoint': GeoPoint(lat, lng),
          };
        }
      }

      await _db
          .collection('live_locations')
          .doc(uid)
          .set(updates, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Called by LeadService after partner accepts an instant order.
  Future<void> markOrderAssigned(String orderId) async {
    await _markLiveAvailability(
      isOnline: true,
      isAvailable: false,
      assignedOrderId: orderId,
    );
  }

  /// Called by OrderProvider when an order is completed or cancelled.
  Future<void> markOrderCompleted() async {
    await _markLiveAvailability(isOnline: true, isAvailable: true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('live_locations')
          .doc(uid)
          .set({'assignedOrderId': null}, SetOptions(merge: true));
    } catch (_) {}
  }

  static String _geohash(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }
}
