import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  searchingPartner,
  reserved,
  partnerAssigned,
  partnerArriving,
  pickupStarted,
  completed,
  cancelled,
}

class ScrapItem {
  final String category;
  final double estimatedWeight;
  final double estimatedRate;
  double actualWeight;
  double actualRate;

  ScrapItem({
    required this.category,
    this.estimatedWeight = 0,
    this.estimatedRate = 0,
    this.actualWeight = 0,
    this.actualRate = 0,
  });

  double get estimatedTotal => estimatedWeight * estimatedRate;
  double get actualTotal => actualWeight * actualRate;

  factory ScrapItem.fromJson(Map<String, dynamic> json) {
    return ScrapItem(
      category: json['category'] ?? '',
      estimatedWeight: (json['estimatedWeight'] ?? 0.0).toDouble(),
      estimatedRate: (json['estimatedRate'] ?? 0.0).toDouble(),
      actualWeight: (json['actualWeight'] ?? 0.0).toDouble(),
      actualRate: (json['actualRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'estimatedWeight': estimatedWeight,
        'estimatedRate': estimatedRate,
        'actualWeight': actualWeight,
        'actualRate': actualRate,
      };
}

class OrderModel {
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final String? partnerId;
  final String? partnerName;
  final List<ScrapItem> scrapItems;
  /// Top-level category list sent by the customer app (e.g. ["Metal"]).
  /// Used when scrapItems is empty (older/simple order format).
  final List<String> rawScrapCategories;
  /// Top-level estimated weight (kg) sent by the customer app.
  final double rawEstimatedWeight;
  final List<String> imageUrls;
  final String? customerNotes;
  final String pickupSlot;
  final OrderStatus status;
  final double estimatedPayout;
  final double finalPayout;
  final String areaName;
  final bool customerConfirmed;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String pickupOtp;
  final String pickupType; // "instant" or "scheduled"
  final String? reservedPartnerId;
  final Map<String, double> declinedPartners;
  final double tipAmount;

  const OrderModel({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    this.partnerId,
    this.partnerName,
    required this.scrapItems,
    this.rawScrapCategories = const [],
    this.rawEstimatedWeight = 0.0,
    this.imageUrls = const [],
    this.customerNotes,
    required this.pickupSlot,
    required this.status,
    required this.estimatedPayout,
    this.finalPayout = 0,
    required this.areaName,
    this.customerConfirmed = false,
    this.cancellationReason,
    required this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.expiresAt,
    this.pickupOtp = '',
    this.pickupType = 'instant',
    this.reservedPartnerId,
    this.declinedPartners = const {},
    this.tipAmount = 0.0,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['orderId'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      customerLat: (json['customerLat'] ?? 0.0).toDouble(),
      customerLng: (json['customerLng'] ?? 0.0).toDouble(),
      partnerId: json['partnerId'],
      partnerName: json['partnerName'],
      scrapItems: (json['scrapItems'] as List<dynamic>? ?? [])
          .map((e) => ScrapItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Support flat scrapCategories array (used by simpler customer app orders)
      rawScrapCategories: List<String>.from(json['scrapCategories'] ?? []),
      // Support top-level estimatedWeight (used by simpler customer app orders)
      rawEstimatedWeight: (json['estimatedWeight'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      customerNotes: json['customerNotes'],
      pickupSlot: json['pickupSlot'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'searchingPartner'),
        orElse: () => OrderStatus.searchingPartner,
      ),
      estimatedPayout: (json['estimatedPayout'] ?? 0.0).toDouble(),
      finalPayout: (json['finalPayout'] ?? 0.0).toDouble(),
      areaName: json['areaName'] ?? '',
      customerConfirmed: json['customerConfirmed'] ?? false,
      cancellationReason: json['cancellationReason'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAt: (json['assignedAt'] as Timestamp?)?.toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
      pickupOtp: json['otp']?.toString() ?? json['pickupOtp']?.toString() ?? '',
      // Support both pickupType and orderType fields from different app versions
      pickupType: json['pickupType'] ?? json['orderType'] ?? 'instant',
      reservedPartnerId: json['reservedPartnerId'],
      declinedPartners: Map<String, double>.from(
        (json['declinedPartners'] as Map<dynamic, dynamic>?)?.map(
          (k, v) => MapEntry(k.toString(), (v ?? 0.0).toDouble())
        ) ?? {}
      ),
      tipAmount: (json['tipAmount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'customerLat': customerLat,
        'customerLng': customerLng,
        'partnerId': partnerId,
        'partnerName': partnerName,
        'scrapItems': scrapItems.map((e) => e.toJson()).toList(),
        'scrapCategories': rawScrapCategories,
        'estimatedWeight': rawEstimatedWeight,
        'imageUrls': imageUrls,
        'customerNotes': customerNotes,
        'pickupSlot': pickupSlot,
        'status': status.name,
        'estimatedPayout': estimatedPayout,
        'finalPayout': finalPayout,
        'areaName': areaName,
        'customerConfirmed': customerConfirmed,
        'cancellationReason': cancellationReason,
        'createdAt': Timestamp.fromDate(createdAt),
        'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'pickupOtp': pickupOtp,
        'pickupType': pickupType,
        'reservedPartnerId': reservedPartnerId,
        'declinedPartners': declinedPartners,
        'tipAmount': tipAmount,
      };

  OrderModel copyWith({
    String? orderId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? customerLat,
    double? customerLng,
    String? partnerId,
    String? partnerName,
    List<ScrapItem>? scrapItems,
    List<String>? rawScrapCategories,
    double? rawEstimatedWeight,
    List<String>? imageUrls,
    String? customerNotes,
    String? pickupSlot,
    OrderStatus? status,
    double? estimatedPayout,
    double? finalPayout,
    String? areaName,
    bool? customerConfirmed,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? assignedAt,
    DateTime? completedAt,
    DateTime? expiresAt,
    String? pickupOtp,
    String? pickupType,
    String? reservedPartnerId,
    Map<String, double>? declinedPartners,
    double? tipAmount,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      scrapItems: scrapItems ?? this.scrapItems,
      rawScrapCategories: rawScrapCategories ?? this.rawScrapCategories,
      rawEstimatedWeight: rawEstimatedWeight ?? this.rawEstimatedWeight,
      imageUrls: imageUrls ?? this.imageUrls,
      customerNotes: customerNotes ?? this.customerNotes,
      pickupSlot: pickupSlot ?? this.pickupSlot,
      status: status ?? this.status,
      estimatedPayout: estimatedPayout ?? this.estimatedPayout,
      finalPayout: finalPayout ?? this.finalPayout,
      areaName: areaName ?? this.areaName,
      customerConfirmed: customerConfirmed ?? this.customerConfirmed,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      pickupType: pickupType ?? this.pickupType,
      reservedPartnerId: reservedPartnerId ?? this.reservedPartnerId,
      declinedPartners: declinedPartners ?? this.declinedPartners,
      tipAmount: tipAmount ?? this.tipAmount,
    );
  }

  bool get isActive => [
        OrderStatus.partnerAssigned,
        OrderStatus.partnerArriving,
        OrderStatus.pickupStarted,
      ].contains(status);

  DateTime get scheduledDateTime {
    final defaultDate = createdAt.add(const Duration(days: 1));
    try {
      if (pickupSlot.isEmpty) return defaultDate;
      final parts = pickupSlot.split(',');
      final dateStr = parts[0].trim().toLowerCase();
      DateTime date;
      if (dateStr == 'tomorrow') {
        final now = DateTime.now();
        date = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      } else if (dateStr == 'today') {
        final now = DateTime.now();
        date = DateTime(now.year, now.month, now.day);
      } else {
        date = DateTime.parse(dateStr);
      }
      if (parts.length > 1) {
        final timeStr = parts[1].trim().toUpperCase();
        final startHourStr = timeStr.split('-')[0].trim();
        final match = RegExp(r'(\d+)\s*(AM|PM)').firstMatch(startHourStr);
        if (match != null) {
          int hour = int.parse(match.group(1)!);
          final amPm = match.group(2);
          if (amPm == 'PM' && hour < 12) {
            hour += 12;
          } else if (amPm == 'AM' && hour == 12) {
            hour = 0;
          }
          return DateTime(date.year, date.month, date.day, hour);
        }
      }
      return DateTime(date.year, date.month, date.day, 12);
    } catch (_) {
      return defaultDate;
    }
  }

  /// Returns total estimated weight. Prefers scrapItems sum; falls back to
  /// the flat estimatedWeight field sent by the customer app.
  double get totalEstimatedWeight {
    final fromItems = scrapItems.fold(0.0, (acc, item) => acc + item.estimatedWeight);
    if (fromItems > 0) return fromItems;
    return rawEstimatedWeight;
  }

  /// Returns all scrap categories — from scrapItems or from rawScrapCategories.
  List<String> get allScrapCategories {
    if (scrapItems.isNotEmpty) {
      return scrapItems.map((e) => e.category).toList();
    }
    return rawScrapCategories;
  }

  String get categoryList => allScrapCategories.join(' · ');

  String get statusDisplay {
    switch (status) {
      case OrderStatus.searchingPartner:
        return 'Searching Partner';
      case OrderStatus.reserved:
        return 'Reserved (Scheduled)';
      case OrderStatus.partnerAssigned:
        return 'Partner Assigned';
      case OrderStatus.partnerArriving:
        return 'Partner Arriving';
      case OrderStatus.pickupStarted:
        return 'Pickup Started';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
