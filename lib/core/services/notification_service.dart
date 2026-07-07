import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';
import '../models/order_model.dart';
import '../models/partner_model.dart';
import 'lead_service.dart';

// Top level background message handler required by FCM.
// Must be annotated with @pragma('vm:entry-point') to prevent tree shaking.
// This runs in a SEPARATE isolate when the app is fully killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized before accessing Firebase services.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Background FCM message: ${message.messageId} | type=${message.data['type']}');
  // Show local heads-up notification for data-only messages
  // (FCM notification messages are auto-displayed by the system when the app is killed.)
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.instance.showLocalNotification(message);
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Local lead stream listener variables
  StreamSubscription<List<OrderModel>>? _localLeadSub;
  Set<String> _knownOrderIds = {};

  // Scheduled order notification tracker
  // Watches for newly-assigned reserved orders and fires alerts identical to instant pickup.
  StreamSubscription<QuerySnapshot>? _scheduledAlertSub;
  Set<String> _alertedScheduledIds = {};

  // Notification Channel configuration for Android 8.0+
  // Note: Channel ID is incremented to 'v3' to force recreation with the custom sound.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'scrapwell_leads_channel_v3',
    'Scrapwell Lead Alerts',
    description: 'High priority ringtone and vibration alerts for pickup leads',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('crisp_fast_two_sec_1_1782943688959_oglrigsj'),
    enableVibration: true,
    showBadge: true,
  );

  /// Initialize Firebase Messaging and Local Notifications
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      // ── 1. Request Notification Permissions ──
      await requestNotificationPermissions();

      // ── 2. Initialize Local Notifications ──
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channel
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_channel);
      }

      // Set foreground presentation options for iOS/macOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // ── 3. Register Foreground & Background Message Handlers ──
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle message when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message in the foreground: ${message.messageId}');
        showLocalNotification(message);
      });

      // Handle message when app was in background and user tapped the notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('User tapped background notification: ${message.messageId}');
        _handleNotificationClick(message.data);
      });

      // Check if the app was opened from a completely terminated state via a notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state via notification: ${initialMessage.messageId}');
        // Wait a bit to ensure the navigator is fully ready
        Future.delayed(const Duration(milliseconds: 1500), () {
          _handleNotificationClick(initialMessage.data);
        });
      }

      // ── 4. Set up FCM Token registration & updates ──
      await updateFcmToken();
      _fcm.onTokenRefresh.listen((token) {
        _saveTokenToFirestore(token);
      });

      _initialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Start listening to the nearby leads stream locally (active online state backup)
  /// Also starts watching for newly-assigned scheduled orders.
  void startLocalLeadListener(PartnerModel partner) {
    if (partner.uid.isEmpty) return;
    
    final wasListening = _localLeadSub != null;
    _localLeadSub?.cancel();
    
    if (!wasListening) {
      _knownOrderIds.clear();
    }
    
    bool isFirstRun = !wasListening;

    _localLeadSub = LeadService.instance.instantPickupStream(partner).listen((orders) {
      final currentIds = orders.map((o) => o.orderId).toSet();
      
      if (isFirstRun) {
        final recentCutoff = DateTime.now().subtract(const Duration(minutes: 5));
        for (final order in orders.where((o) => o.createdAt.isAfter(recentCutoff))) {
          _showLocalLeadNotification(order);
        }
        _knownOrderIds = currentIds;
        isFirstRun = false;
        return;
      }

      // Identify newly appeared orders in the stream
      final newIds = currentIds.difference(_knownOrderIds);
      if (newIds.isNotEmpty) {
        for (final orderId in newIds) {
          final order = orders.firstWhere((o) => o.orderId == orderId);
          _showLocalLeadNotification(order);
        }
      }

      _knownOrderIds = currentIds;
    }, onError: (err) {
      debugPrint('Error in NotificationService local lead stream: $err');
    });
    
    // ── Start scheduled order alert listener ──────────────────────────────
    _startScheduledOrderAlertListener(partner.uid);

    debugPrint('Local lead stream listener started for partner ${partner.uid}');
  }

  /// Watches Firestore for scheduled orders newly assigned to this partner.
  /// When detected, fires the same loud notification as instant pickup.
  void _startScheduledOrderAlertListener(String partnerUid) {
    if (_scheduledAlertSub != null) return;
    _scheduledAlertSub?.cancel();
    _alertedScheduledIds.clear();

    _scheduledAlertSub = FirebaseFirestore.instance
        .collection('orders')
        .where('reservedPartnerId', isEqualTo: partnerUid)
        .where('status', isEqualTo: OrderStatus.reserved.name)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final orderId = doc.id.isNotEmpty ? (doc.data()['orderId'] ?? doc.id) as String : doc.id;
        if (_alertedScheduledIds.contains(orderId)) continue;

        final order = OrderModel.fromJson({...doc.data(), 'orderId': orderId});

        // Only alert for recently assigned orders (within last 10 minutes)
        final age = DateTime.now().difference(
          (doc.data()['assignedAt'] as Timestamp?)?.toDate() ?? order.createdAt,
        );
        if (age.inMinutes > 10) {
          _alertedScheduledIds.add(orderId); // Don't alert stale orders
          continue;
        }

        _alertedScheduledIds.add(orderId);
        _showScheduledOrderNotification(order);
        debugPrint('Scheduled order alert fired for orderId=$orderId');
      }
    }, onError: (err) {
      debugPrint('Error in scheduled order alert listener: $err');
    });

    debugPrint('Scheduled order alert listener started for partner $partnerUid');
  }

  /// Stop listening to the nearby leads stream
  void stopLocalLeadListener() {
    _localLeadSub?.cancel();
    _localLeadSub = null;
    _knownOrderIds.clear();
    _scheduledAlertSub?.cancel();
    _scheduledAlertSub = null;
    _alertedScheduledIds.clear();
    debugPrint('Local lead stream listener stopped.');
  }

  /// Request runtime permissions for notifications (Android 13+ and iOS)
  Future<void> requestNotificationPermissions() async {
    try {
      // FCM request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('User notification permission status: ${settings.authorizationStatus}');

      // For Android 13+, request explicit local notification permission if needed
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Get current FCM token and save to Firestore
  Future<void> updateFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Helper to write/update FCM token in the partner's document
  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('partners').doc(uid).update({
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token successfully saved to Firestore: $token');
    } catch (e) {
      // Fallback to merge set if update fails (e.g. document does not exist yet)
      try {
        await FirebaseFirestore.instance.collection('partners').doc(uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM Token merged to Firestore.');
      } catch (err) {
        debugPrint('Failed to save FCM token to Firestore: $err');
      }
    }
  }

  /// Show a local notification when a new instant lead is detected in the stream
  Future<void> _showLocalLeadNotification(OrderModel order) async {
    final int id = order.orderId.hashCode.remainder(100000);
    final vibrationPattern = Int64List.fromList([0, 800, 350, 800, 350, 1200]);
    
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: _channel.importance,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('crisp_fast_two_sec_1_1782943688959_oglrigsj'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(
        'New instant pickup lead is available near ${order.customerAddress}. Tap to view details.',
      ),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'crisp_fast_two_sec_1_1782943688959_oglrigsj.wav',
      ),
    );

    try {
      await _localNotifications.show(
        id,
        '⚡ New Pickup Lead Alert! 💰',
        'Lead available near ${order.customerAddress}.',
        notificationDetails,
        payload: order.orderId,
      );
    } catch (e) {
      debugPrint('Error showing local lead notification: $e');
    }
  }

  /// Show a loud notification when a scheduled order is newly assigned to this partner.
  /// Uses the same high-priority channel, ringtone, and vibration as instant pickup.
  Future<void> _showScheduledOrderNotification(OrderModel order) async {
    final int id = (order.orderId + '_sched').hashCode.remainder(100000);
    final vibrationPattern = Int64List.fromList([0, 800, 350, 800, 350, 1200]);

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: _channel.importance,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('crisp_fast_two_sec_1_1782943688959_oglrigsj'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(
        'Scheduled pickup assigned for ${order.pickupSlot.isNotEmpty ? order.pickupSlot : "upcoming slot"} at ${order.customerAddress}. Tap to view details.',
      ),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'crisp_fast_two_sec_1_1782943688959_oglrigsj.wav',
      ),
    );

    try {
      await _localNotifications.show(
        id,
        '📅 Scheduled Pickup Assigned!',
        'New booking: ${order.pickupSlot.isNotEmpty ? order.pickupSlot : "Scheduled slot"} — ${order.customerAddress}.',
        notificationDetails,
        payload: order.orderId,
      );
    } catch (e) {
      debugPrint('Error showing scheduled order notification: $e');
    }
  }

  /// Show a local heads-up notification using Flutter Local Notifications (FCM callback)
  Future<void> showLocalNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? 
        message.data['title'] ?? 
        'New Lead Assigned';
    final String body = message.notification?.body ?? 
        message.data['body'] ?? 
        'You have a new pick up lead nearby.';

    // Create unique ID for notification
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final vibrationPattern = Int64List.fromList([0, 800, 350, 800, 350, 1200]);

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: _channel.importance,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('crisp_fast_two_sec_1_1782943688959_oglrigsj'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      styleInformation: BigTextStyleInformation(body),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'crisp_fast_two_sec_1_1782943688959_oglrigsj.wav',
      ),
    );

    try {
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: message.data['click_action'] ?? message.data['orderId'] ?? '',
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Triggered when the user taps on a local notification
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _handleNotificationClick({'orderId': payload});
    }
  }

  /// Navigate or change tab depending on the payload action
  void _handleNotificationClick(Map<String, dynamic> data) {
    if (_navigatorKey == null || _navigatorKey!.currentState == null) {
      debugPrint('Navigator state is not ready — queuing navigation.');
      // Retry after a short delay to allow the navigator to mount
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationClick(data);
      });
      return;
    }

    final String? type = data['type'];
    final String? orderId = data['orderId'];

    if (type == 'new_order' || (orderId != null && orderId.isNotEmpty)) {
      debugPrint('FCM tap → navigating to Home tab (orderId=$orderId)');
      // Pop all routes back to root (SplashScreen) which will redirect to MainScreen,
      // then the HomeScreen's lead stream will auto-show the popup for that order.
      _navigatorKey!.currentState?.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }
}
