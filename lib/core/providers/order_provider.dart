import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
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
  final Set<String> _autoAssigning = {}; // guard against duplicate triggers

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

    _ordersSub?.cancel();
    _ordersSub = _db
        .collection('orders')
        .where(Filter.or(
          Filter('partnerId', isEqualTo: uid),
          Filter('reservedPartnerId', isEqualTo: uid),
        ))
        .snapshots()
        .listen((snapshot) {
      final all = snapshot.docs
          .map((d) => OrderModel.fromJson(d.data()))
          .toList();
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _activeOrders = all.where((o) => o.isActive).toList();
      _reservedOrders = all.where((o) => o.status == OrderStatus.reserved).toList();
      _completedOrders =
          all.where((o) => o.status == OrderStatus.completed).toList();
      _cancelledOrders =
          all.where((o) => o.status == OrderStatus.cancelled).toList();

      // Current active order (first partner-assigned or higher)
      _currentOrder = _activeOrders.isNotEmpty ? _activeOrders.first : null;

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
        final order = OrderModel.fromJson(doc.data());

        // Skip if we're already processing this order
        if (_autoAssigning.contains(order.orderId)) continue;

        // Only trigger for orders created recently (within the last 5 minutes)
        // to avoid re-processing stale unassigned orders on app resume.
        final age = DateTime.now().difference(order.createdAt);
        if (age.inMinutes > 5) continue;

        _autoAssigning.add(order.orderId);
        LeadService.instance.autoAssignScheduledOrder(order).then((assignedUid) {
          _autoAssigning.remove(order.orderId);
        }).catchError((_) {
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
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'scrapItems': items.map((e) => e.toJson()).toList(),
        'finalPayout': totalPayout,
        'status': OrderStatus.completed.name,
        'customerConfirmed': true,
        'completedAt': FieldValue.serverTimestamp(),
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
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _ordersSub?.cancel();
    _ordersSub = null;
    _scheduledSub?.cancel();
    _scheduledSub = null;
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
  bool _commissionBlocked = false;
  String _scrapwellUpiId = 'scrapwell@upi';
  String _scrapwellPayeeName = 'Scrapwell';
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
  DateTime? get commissionDueAt => _commissionDueAt;
  bool get commissionBlocked => _commissionBlocked;
  String get scrapwellUpiId => _scrapwellUpiId;
  String get scrapwellPayeeName => _scrapwellPayeeName;
  bool get hasCommissionDue => _commissionDueBalance > 0.01;
  bool get shouldBlockForCommission =>
      _commissionBlocked ||
      _commissionDueBalance >= 500 ||
      (hasCommissionDue &&
          _commissionDueAt != null &&
          DateTime.now().isAfter(_commissionDueAt!));
  bool get isLoading => _isLoading;

  void listenToWallet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _partnerWalletSub?.cancel();
    _partnerWalletSub =
        _db.collection('partners').doc(uid).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      _walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
      _commissionDueBalance =
          (data['commissionDueBalance'] ?? 0.0).toDouble();
      _commissionDueAt =
          (data['commissionDueAt'] as Timestamp?)?.toDate();
      _commissionBlocked = data['commissionBlocked'] ?? false;
      notifyListeners();
    });

    _paymentConfigSub?.cancel();
    _paymentConfigSub =
        _db.collection('app_config').doc('payments').snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      _scrapwellUpiId = (data['scrapwellUpiId'] ?? _scrapwellUpiId).toString();
      _scrapwellPayeeName =
          (data['scrapwellPayeeName'] ?? _scrapwellPayeeName).toString();
      notifyListeners();
    });
  }

  Future<void> loadEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Future.microtask(() {
      _isLoading = true;
      notifyListeners();
    });

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final snap = await _db
          .collection('orders')
          .where('partnerId', isEqualTo: uid)
          .where('status', isEqualTo: OrderStatus.completed.name)
          .orderBy('completedAt', descending: true)
          .get();

      final orders = snap.docs
          .map((d) => OrderModel.fromJson(d.data()))
          .where((o) => o.completedAt != null)
          .toList();

      _todayEarnings = orders
          .where((o) => o.completedAt!.isAfter(todayStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _todayOrders = orders
          .where((o) => o.completedAt!.isAfter(todayStart))
          .length;

      _weekEarnings = orders
          .where((o) => o.completedAt!.isAfter(weekStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _weekOrders = orders
          .where((o) => o.completedAt!.isAfter(weekStart))
          .length;

      _monthEarnings = orders
          .where((o) => o.completedAt!.isAfter(monthStart))
          .fold(0, (sum, o) => sum + o.finalPayout);
      _monthOrders = orders
          .where((o) => o.completedAt!.isAfter(monthStart))
          .length;

      // Wallet: fetch from partner doc
      final partnerDoc =
          await _db.collection('partners').doc(uid).get();
      if (partnerDoc.exists) {
        _walletBalance =
            (partnerDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        _commissionDueBalance =
            (partnerDoc.data()?['commissionDueBalance'] ?? 0.0).toDouble();
        _commissionDueAt =
            (partnerDoc.data()?['commissionDueAt'] as Timestamp?)?.toDate();
        _commissionBlocked =
            partnerDoc.data()?['commissionBlocked'] ?? false;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
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
    _commissionBlocked = false;
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
