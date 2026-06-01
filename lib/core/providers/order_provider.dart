import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  static final OrderProvider _instance = OrderProvider._internal();
  factory OrderProvider() => _instance;
  OrderProvider._internal();

  final _db = FirebaseFirestore.instance;

  List<OrderModel> _activeOrders = [];
  List<OrderModel> _completedOrders = [];
  List<OrderModel> _cancelledOrders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get activeOrders => _activeOrders;
  List<OrderModel> get completedOrders => _completedOrders;
  List<OrderModel> get cancelledOrders => _cancelledOrders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveOrder => _currentOrder != null;

  void listenToOrders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _db
        .collection('orders')
        .where('partnerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final all = snapshot.docs
          .map((d) => OrderModel.fromJson(d.data()))
          .toList();

      _activeOrders = all.where((o) => o.isActive).toList();
      _completedOrders =
          all.where((o) => o.status == OrderStatus.completed).toList();
      _cancelledOrders =
          all.where((o) => o.status == OrderStatus.cancelled).toList();

      // Current active order (first partner-assigned or higher)
      _currentOrder = _activeOrders.isNotEmpty ? _activeOrders.first : null;

      notifyListeners();
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
    double totalPayout,
  ) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'scrapItems': items.map((e) => e.toJson()).toList(),
        'finalPayout': totalPayout,
        'status': OrderStatus.pickupStarted.name,
        'pricingSubmittedAt': FieldValue.serverTimestamp(),
      });
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
    _activeOrders = [];
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
  bool _isLoading = false;

  double get todayEarnings => _todayEarnings;
  double get weekEarnings => _weekEarnings;
  double get monthEarnings => _monthEarnings;
  int get todayOrders => _todayOrders;
  int get weekOrders => _weekOrders;
  int get monthOrders => _monthOrders;
  double get walletBalance => _walletBalance;
  bool get isLoading => _isLoading;

  Future<void> loadEarnings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

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
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  void reset() {
    _todayEarnings = 0;
    _weekEarnings = 0;
    _monthEarnings = 0;
    _todayOrders = 0;
    _weekOrders = 0;
    _monthOrders = 0;
    _walletBalance = 0;
    notifyListeners();
  }
}
