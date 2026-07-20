import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../utils/cache_utils.dart';
import '../services/lead_service.dart';
import '../services/location_tracking_service.dart';

class OrderProvider extends ChangeNotifier {
  static final OrderProvider _instance = OrderProvider._internal();
  factory OrderProvider() => _instance;
  OrderProvider._internal();

  final _db = FirebaseFirestore.instance;

  List<OrderModel> _activeOrders = [];
  List<OrderModel> _reservedOrders = [];
  List<OrderModel> _completedOrders = [];
  List<OrderModel> _cancelledOrders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot>? _ordersSub;
  StreamSubscription<QuerySnapshot>? _scheduledSub;
  StreamSubscription<QuerySnapshot>? _partnerCancellationsSub;
  final Set<String> _autoAssigning = {}; // guard against duplicate triggers
  DateTime? _lastOrdersCacheWriteTime;
  int _lastActiveOrdersCount = 0;

  List<OrderModel> get activeOrders => _activeOrders;
  List<OrderModel> get reservedOrders => _reservedOrders;
  List<OrderModel> get completedOrders => _completedOrders;
  List<OrderModel> get cancelledOrders => _cancelledOrders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveOrder => _currentOrder != null;

  void listenToOrders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Load cached orders first for instant UI response
    _loadCachedOrders(uid);

    List<OrderModel> dbCancelledOrders = [];
    List<OrderModel> mainCancelledOrders = [];

    void updateCancelledOrdersList() {
      final combined = [
        ...mainCancelledOrders,
        ...dbCancelledOrders,
      ];
      final seenIds = <String>{};
      final unique = <OrderModel>[];
      for (final o in combined) {
        if (!seenIds.contains(o.orderId)) {
          seenIds.add(o.orderId);
          unique.add(o);
        }
      }
      unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cancelledOrders = unique;
    }

    _ordersSub?.cancel();
    _ordersSub = _db
        .collection('orders')
        .where(
          Filter.or(
            Filter('partnerId', isEqualTo: uid),
            Filter('reservedPartnerId', isEqualTo: uid),
          ),
        )
        .snapshots()
        .listen((snapshot) {
          final all = snapshot.docs
              .map((d) => OrderModel.fromJson({
                    ...d.data(),
                    'orderId': d.id,
                  }))
              .toList();
          all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _activeOrders = all.where((o) => o.isActive).toList();
          _reservedOrders =
              all.where((o) => o.status == OrderStatus.reserved).toList();
          _completedOrders =
              all.where((o) => o.status == OrderStatus.completed).toList();
          
          mainCancelledOrders =
              all.where((o) => o.status == OrderStatus.cancelled).toList();
          updateCancelledOrdersList();

          // Current active order (first partner-assigned or higher)
          _currentOrder = _activeOrders.isNotEmpty ? _activeOrders.first : null;
 
          notifyListeners();
 
          // Cache the fresh orders list locally (throttled to once per 30 seconds or on active orders count changes)
          final activeCountChanged = _lastActiveOrdersCount != _activeOrders.length;
          _lastActiveOrdersCount = _activeOrders.length;
          final now = DateTime.now();
          if (_lastOrdersCacheWriteTime == null ||
              activeCountChanged ||
              now.difference(_lastOrdersCacheWriteTime!) > const Duration(seconds: 30)) {
            _lastOrdersCacheWriteTime = now;
            SharedPreferences.getInstance().then((prefs) {
              final jsonList = all.map((o) => o.toJson()).toList();
              prefs.setString('cached_orders_$uid', CacheUtils.encode(jsonList));
            }).catchError((_) {});
          }
        });

    _partnerCancellationsSub?.cancel();
    _partnerCancellationsSub = _db
        .collection('partners')
        .doc(uid)
        .collection('cancelled_orders')
        .snapshots()
        .listen((snapshot) {
          dbCancelledOrders = snapshot.docs
              .map((d) => OrderModel.fromJson({
                    ...d.data(),
                    'orderId': d.id,
                    'status': 'cancelled',
                  }))
              .toList();
          updateCancelledOrdersList();
          notifyListeners();
        });
  }

  /// Watches for unassigned scheduled orders and triggers auto-assignment.
  /// Call this once after the partner is loaded and approved.
  void listenForScheduledOrders() {
    _scheduledSub?.cancel();
    _scheduledSub = _db
        .collection('orders')
        .where('status', isEqualTo: 'searchingPartner')
        .where('pickupType', isEqualTo: 'scheduled')
        .snapshots()
        .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final order = OrderModel.fromJson({
              ...doc.data(),
              'orderId': doc.id,
            });

            // Skip if we're already processing this order
            if (_autoAssigning.contains(order.orderId)) continue;

            // Skip if the scheduled pickup time has already passed by more than 60 minutes.
            if (DateTime.now().difference(order.scheduledDateTime).inMinutes > 60) continue;

            _autoAssigning.add(order.orderId);
            LeadService.instance
                .autoAssignScheduledOrder(order)
                .then((assignedUid) {
                  _autoAssigning.remove(order.orderId);
                })
                .catchError((_) {
                  _autoAssigning.remove(order.orderId);
                });
          }
        });
  }

  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      final Map<String, dynamic> update = {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == OrderStatus.partnerArriving) {
        update['partnerArrivedAt'] = FieldValue.serverTimestamp();
      } else if (status == OrderStatus.pickupStarted) {
        update['pickupStartedAt'] = FieldValue.serverTimestamp();
      } else if (status == OrderStatus.completed) {
        update['completedAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('orders').doc(orderId).update(update);

      if (status == OrderStatus.completed || status == OrderStatus.cancelled) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          // ── Restore partner availability in partners collection ────────────
          await _db.collection('partners').doc(uid).update({
            'isAvailable': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // ── Restore live availability in live_locations ────────────────
          // This puts the partner back into the instant pickup broadcast
          // pool immediately so they can receive the next order.
          await LocationTrackingService.instance.markOrderCompleted();
        }
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitFinalPricing(
    String orderId,
    List<ScrapItem> items,
    double totalPayout, {
    String? weighingPhotoUrl,
    double effectivePickupCharge = 0.0,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'scrapItems': items.map((e) => e.toJson()).toList(),
        'finalPayout': totalPayout,
        'status': OrderStatus.completed.name,
        'customerConfirmed': true,
        'completedAt': FieldValue.serverTimestamp(),
        // Write the effective pickup charge back (may differ from original if waived)
        'pickupCharge': effectivePickupCharge,
      };
      if (weighingPhotoUrl != null) {
        updateData['weighingPhotoUrl'] = weighingPhotoUrl;
      }
      await _db.collection('orders').doc(orderId).update(updateData);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Restore partner availability
        await _db.collection('partners').doc(uid).update({
          'isAvailable': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await LocationTrackingService.instance.markOrderCompleted();

        // ── Update partner totalEarnings, totalOrders, and commission atomically ────
        // We use a transaction so concurrent completions don't race.
        final commission = totalPayout * 0.02;
        await _db.runTransaction((tx) async {
          final partnerRef = _db.collection('partners').doc(uid);
          final snap = await tx.get(partnerRef);
          if (!snap.exists) return;
          final data = snap.data()!;
          final prevEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
          final prevOrders = (data['totalOrders'] ?? 0) as int;
          final prevCommission = (data['commissionDueBalance'] ?? 0.0).toDouble();
          final prevCycleStart = data['commissionCycleStartedAt'];

          // Compute next Tuesday from today for commissionDueAt
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int daysUntilTuesday = (DateTime.tuesday - today.weekday) % 7;
          if (daysUntilTuesday == 0) daysUntilTuesday = 7; // today IS Tuesday, go to next week
          final nextTuesdayEOD = today
              .add(Duration(days: daysUntilTuesday))
              .add(const Duration(hours: 23, minutes: 59, seconds: 59));

          final Map<String, dynamic> partnerUpdates = {
            'totalEarnings': prevEarnings + totalPayout,
            'totalOrders': prevOrders + 1,
            // Accumulate commission due balance
            'commissionDueBalance': prevCommission + commission,
            // commissionDueAt = always next upcoming Tuesday
            'commissionDueAt': Timestamp.fromDate(nextTuesdayEOD),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Set cycle start only when first commission in this cycle (prev was 0)
          if (prevCommission <= 0.01 || prevCycleStart == null) {
            partnerUpdates['commissionCycleStartedAt'] = FieldValue.serverTimestamp();
          }

          tx.update(partnerRef, partnerUpdates);
        });
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Listens to [orderId] for the customer's partnerRating field.
  /// When the customer rates the partner (writes partnerRating 1-5),
  /// we compute the new rolling average and write it back to the
  /// partner's Firestore document. The existing listenToPartner()
  /// real-time stream then propagates the updated rating to the UI.
  StreamSubscription<DocumentSnapshot>? listenForPartnerRating(String orderId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    bool ratingProcessed = false;

    final sub = _db.collection('orders').doc(orderId).snapshots().listen((
      snap,
    ) async {
      if (ratingProcessed) return;
      final data = snap.data();
      if (data == null) return;

      final rawRating = data['partnerRating'];
      if (rawRating == null) return; // customer hasn't rated yet

      final customerRating = (rawRating as num).toDouble();
      if (customerRating < 1 || customerRating > 5) return;

      ratingProcessed = true; // process only once

      try {
        await _db.runTransaction((tx) async {
          final partnerRef = _db.collection('partners').doc(uid);
          final snap = await tx.get(partnerRef);
          if (!snap.exists) return;
          final pData = snap.data()!;
          final prevRating = (pData['rating'] ?? 0.0).toDouble();
          final totalRatedOrders = (pData['totalRatedOrders'] ?? 0) as int;

          // Compute rolling average: newAvg = (prevAvg * n + newRating) / (n + 1)
          final newCount = totalRatedOrders + 1;
          final newRating =
              ((prevRating * totalRatedOrders) + customerRating) / newCount;

          tx.update(partnerRef, {
            'rating': double.parse(newRating.toStringAsFixed(1)),
            'totalRatedOrders': newCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        debugPrint('Error updating partner rating: $e');
      }
    });

    return sub;
  }


  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _loadCachedOrders(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_orders_$uid');
      if (cachedJson != null) {
        final List<dynamic> list = CacheUtils.decode(cachedJson);
        final all = list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
        _activeOrders = all.where((o) => o.isActive).toList();
        _reservedOrders = all.where((o) => o.status == OrderStatus.reserved).toList();
        _completedOrders = all.where((o) => o.status == OrderStatus.completed).toList();
        _cancelledOrders = all.where((o) => o.status == OrderStatus.cancelled).toList();
        _currentOrder = _activeOrders.isNotEmpty ? _activeOrders.first : null;
        notifyListeners();
      }
    } catch (_) {}
  }

  void reset() {
    _ordersSub?.cancel();
    _ordersSub = null;
    _scheduledSub?.cancel();
    _scheduledSub = null;
    _partnerCancellationsSub?.cancel();
    _partnerCancellationsSub = null;
    _autoAssigning.clear();
    _activeOrders = [];
    _reservedOrders = []; // was missing — caused stale orders after logout
    _completedOrders = [];
    _cancelledOrders = [];
    _currentOrder = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

class EarningsProvider extends ChangeNotifier {
  static final EarningsProvider _instance = EarningsProvider._internal();
  factory EarningsProvider() => _instance;
  EarningsProvider._internal();

  final _db = FirebaseFirestore.instance;

  double _todayEarnings = 0;
  double _weekEarnings = 0;
  double _monthEarnings = 0;
  int _todayOrders = 0;
  int _weekOrders = 0;
  int _monthOrders = 0;
  double _walletBalance = 0;
  double _commissionDueBalance = 0;
  DateTime? _commissionDueAt;
  DateTime? _commissionCycleStartedAt;
  bool _commissionBlocked = false;
  double _lifetimeEarnings = 0;
  int _lifetimeOrders = 0;
  String _scrapwellUpiId = 'ateshamali0@okicici';
  String _scrapwellPayeeName = 'Atesham Ali';
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _partnerWalletSub;
  StreamSubscription<DocumentSnapshot>? _paymentConfigSub;

  double get todayEarnings => _todayEarnings;
  double get weekEarnings => _weekEarnings;
  double get monthEarnings => _monthEarnings;
  int get todayOrders => _todayOrders;
  int get weekOrders => _weekOrders;
  int get monthOrders => _monthOrders;
  double get walletBalance => _walletBalance;
  double get commissionDueBalance => _commissionDueBalance;
  double get lifetimeEarnings => _lifetimeEarnings;
  int get lifetimeOrders => _lifetimeOrders;
  DateTime? get commissionDueAt {
    if (_commissionDueBalance <= 0.01) return null;
    if (_commissionDueBalance >= 500) {
      // Over limit: must pay immediately in real time.
      return DateTime.now().subtract(const Duration(seconds: 1));
    }
    // Always compute next upcoming Tuesday from TODAY (not from cycle start)
    // This ensures the date is always current and never stale.
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    int daysUntilTuesday = (DateTime.tuesday - todayDate.weekday) % 7;
    if (daysUntilTuesday == 0) daysUntilTuesday = 7; // today IS Tuesday -> show next Tuesday
    return todayDate
        .add(Duration(days: daysUntilTuesday))
        .add(const Duration(hours: 23, minutes: 59, seconds: 59));
  }
  bool get commissionBlocked => _commissionBlocked;
  String get scrapwellUpiId => _scrapwellUpiId;
  String get scrapwellPayeeName => _scrapwellPayeeName;
  bool get hasCommissionDue => _commissionDueBalance > 0.01;
  bool get shouldBlockForCommission =>
      hasCommissionDue &&
      (_commissionBlocked ||
       // commissionDueAt returns DateTime.now()-1s when balance >= 500 (immediate block)
       // and returns next Tuesday EOD otherwise — so isAfter() handles both cases.
       (commissionDueAt != null && DateTime.now().isAfter(commissionDueAt!)));
  bool get isLoading => _isLoading;

  /// Safely notify listeners after the current frame to avoid triggering
  /// a rebuild while the rendering pipeline is still laying out.
  bool _notifyScheduled = false;
  void _safeNotifyListeners() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void listenToWallet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    double? _prevCommissionBalance;

    _partnerWalletSub?.cancel();
    _partnerWalletSub = _db.collection('partners').doc(uid).snapshots().listen((
      doc,
    ) async {
      final data = doc.data();
      if (data == null) return;
      final newBalance = (data['commissionDueBalance'] ?? 0.0).toDouble();

      // Detect balance transition from >0 → 0 (admin cleared it)
      // When this happens, reset commissionCycleStartedAt so next cycle starts fresh
      if (_prevCommissionBalance != null && _prevCommissionBalance! > 0.01 && newBalance <= 0.01) {
        // Admin set commissionBalance to 0 — reset the cycle start so the next
        // commission accrual starts a fresh Tuesday cycle
        try {
          await _db.collection('partners').doc(uid).update({
            'commissionCycleStartedAt': FieldValue.delete(),
            'commissionDueAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
      _prevCommissionBalance = newBalance;

      _walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
      _commissionDueBalance = newBalance;
      _commissionDueAt = (data['commissionDueAt'] as Timestamp?)?.toDate();
      _commissionCycleStartedAt = (data['commissionCycleStartedAt'] as Timestamp?)?.toDate();
      _commissionBlocked = data['commissionBlocked'] ?? false;
      _lifetimeEarnings = (data['totalEarnings'] ?? 0.0).toDouble();
      _lifetimeOrders = (data['totalOrders'] ?? 0) as int;
      _safeNotifyListeners();
    });

    _paymentConfigSub?.cancel();
    _paymentConfigSub = _db
        .collection('app_config')
        .doc('payments')
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (data == null) return;
          _scrapwellUpiId =
              (data['scrapwellUpiId'] ?? _scrapwellUpiId).toString();
          _scrapwellPayeeName =
              (data['scrapwellPayeeName'] ?? _scrapwellPayeeName).toString();
          _safeNotifyListeners();
        });
  }

  Future<void> loadEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final snap =
          await _db
              .collection('orders')
              .where('partnerId', isEqualTo: uid)
              .where('status', isEqualTo: OrderStatus.completed.name)
              .orderBy('completedAt', descending: true)
              .get();

      final orders = snap.docs
          .map((d) => OrderModel.fromJson({
                ...d.data(),
                'orderId': d.id,
              }))
          .where((o) => o.completedAt != null)
          .toList();

      _todayEarnings = orders
          .where((o) => o.completedAt!.isAfter(todayStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _todayOrders =
          orders.where((o) => o.completedAt!.isAfter(todayStart)).length;

      _weekEarnings = orders
          .where((o) => o.completedAt!.isAfter(weekStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _weekOrders =
          orders.where((o) => o.completedAt!.isAfter(weekStart)).length;

      _monthEarnings = orders
          .where((o) => o.completedAt!.isAfter(monthStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _monthOrders =
          orders.where((o) => o.completedAt!.isAfter(monthStart)).length;

      // Wallet: fetch from partner doc
      final partnerDoc = await _db.collection('partners').doc(uid).get();
      if (partnerDoc.exists) {
        _walletBalance =
            (partnerDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        _commissionDueBalance =
            (partnerDoc.data()?['commissionDueBalance'] ?? 0.0).toDouble();
        _commissionDueAt =
            (partnerDoc.data()?['commissionDueAt'] as Timestamp?)?.toDate();
        _commissionCycleStartedAt =
            (partnerDoc.data()?['commissionCycleStartedAt'] as Timestamp?)?.toDate();
        _commissionBlocked = partnerDoc.data()?['commissionBlocked'] ?? false;
        _lifetimeEarnings = (partnerDoc.data()?['totalEarnings'] ?? 0.0).toDouble();
        _lifetimeOrders = (partnerDoc.data()?['totalOrders'] ?? 0) as int;
      }
    } catch (_) {}

    _isLoading = false;
    _safeNotifyListeners();
  }

  void reset() {
    _partnerWalletSub?.cancel();
    _partnerWalletSub = null;
    _paymentConfigSub?.cancel();
    _paymentConfigSub = null;
    _todayEarnings = 0;
    _weekEarnings = 0;
    _monthEarnings = 0;
    _todayOrders = 0;
    _weekOrders = 0;
    _monthOrders = 0;
    _walletBalance = 0;
    _commissionDueBalance = 0;
    _commissionDueAt = null;
    _commissionCycleStartedAt = null;
    _commissionBlocked = false;
    _lifetimeEarnings = 0;
    _lifetimeOrders = 0;
    _scrapwellUpiId = 'scrapwell@upi';
    _scrapwellPayeeName = 'Scrapwell';
    notifyListeners();
  }

  Future<void> recordCommissionPaymentOpened() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _commissionDueBalance <= 0) return;

    final partnerRef = _db.collection('partners').doc(uid);
    await partnerRef.collection('commission_payment_attempts').add({
      'amount': _commissionDueBalance,
      'status': 'initiated',
      'upiId': _scrapwellUpiId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
