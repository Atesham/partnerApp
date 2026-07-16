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
  final DateTime? partnerArrivedAt;
  final DateTime? pickupStartedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final String pickupOtp;
  final String pickupType; // "instant" or "scheduled"
  final String? reservedPartnerId;
  final Map<String, double> declinedPartners;
  final double tipAmount;
  final double pickupCharge;

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
    this.partnerArrivedAt,
    this.pickupStartedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiresAt,
    this.pickupOtp = '',
    this.pickupType = 'instant',
    this.reservedPartnerId,
    this.declinedPartners = const {},
    this.tipAmount = 0.0,
    this.pickupCharge = 0.0,
    this.scheduledDateTimestamp,
  });

  /// Firestore scheduledDate Timestamp (if set directly by customer app)
  /// Used as the authoritative source for scheduled pickup time when present.
  final DateTime? scheduledDateTimestamp;

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
      rawScrapCategories: List<String>.from(json['scrapCategories'] ?? []),
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
      partnerArrivedAt: (json['partnerArrivedAt'] as Timestamp?)?.toDate(),
      pickupStartedAt: (json['pickupStartedAt'] as Timestamp?)?.toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (json['cancelledAt'] as Timestamp?)?.toDate() ?? (json['status'] == 'cancelled' ? (json['updatedAt'] as Timestamp?)?.toDate() : null),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
      pickupOtp: json['otp']?.toString() ?? json['pickupOtp']?.toString() ?? '',
      pickupType: json['pickupType'] ?? json['orderType'] ?? 'instant',
      reservedPartnerId: json['reservedPartnerId'],
      declinedPartners: Map<String, double>.from(
        (json['declinedPartners'] as Map<dynamic, dynamic>?)?.map(
          (k, v) => MapEntry(k.toString(), (v ?? 0.0).toDouble())
        ) ?? {}
      ),
      tipAmount: (json['tipAmount'] ?? 0.0).toDouble(),
      pickupCharge: (json['pickupCharge'] ?? 0.0).toDouble(),
      // Try multiple Firestore field names for the scheduled timestamp
      scheduledDateTimestamp:
          (json['scheduledDate'] as Timestamp?)?.toDate() ??
          (json['scheduledAt'] as Timestamp?)?.toDate() ??
          (json['scheduledTime'] as Timestamp?)?.toDate(),
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
        'partnerArrivedAt': partnerArrivedAt != null ? Timestamp.fromDate(partnerArrivedAt!) : null,
        'pickupStartedAt': pickupStartedAt != null ? Timestamp.fromDate(pickupStartedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'pickupOtp': pickupOtp,
        'pickupType': pickupType,
        'reservedPartnerId': reservedPartnerId,
        'declinedPartners': declinedPartners,
        'tipAmount': tipAmount,
        'pickupCharge': pickupCharge,
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
    DateTime? partnerArrivedAt,
    DateTime? pickupStartedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? expiresAt,
    String? pickupOtp,
    String? pickupType,
    String? reservedPartnerId,
    Map<String, double>? declinedPartners,
    double? tipAmount,
    double? pickupCharge,
    DateTime? scheduledDateTimestamp,
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
      partnerArrivedAt: partnerArrivedAt ?? this.partnerArrivedAt,
      pickupStartedAt: pickupStartedAt ?? this.pickupStartedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      pickupType: pickupType ?? this.pickupType,
      reservedPartnerId: reservedPartnerId ?? this.reservedPartnerId,
      declinedPartners: declinedPartners ?? this.declinedPartners,
      tipAmount: tipAmount ?? this.tipAmount,
      pickupCharge: pickupCharge ?? this.pickupCharge,
      scheduledDateTimestamp: scheduledDateTimestamp ?? this.scheduledDateTimestamp,
    );
  }

  bool get isActive => [
        OrderStatus.partnerAssigned,
        OrderStatus.partnerArriving,
        OrderStatus.pickupStarted,
      ].contains(status);

  /// Parses the scheduled pickup time from multiple possible sources.
  ///
  /// Priority order:
  ///   1. `scheduledDateTimestamp` — a real Firestore Timestamp field (most reliable)
  ///   2. `pickupSlot` string — e.g. "today, 3PM-6PM" or "Today 3pm to 6pm"
  ///   3. Fallback: `createdAt + 1 hour` (never go to "tomorrow" by default)
  DateTime get scheduledDateTime {
    // ── Source 1: direct Firestore Timestamp ──────────────────────────────────
    if (scheduledDateTimestamp != null) return scheduledDateTimestamp!;

    // ── Source 2: parse pickupSlot string ────────────────────────────────────
    // Handles all known formats:
    //   "today, 3PM-6PM"       standard comma format
    //   "Today 3pm to 6pm"     no comma, space-separated, "to" separator
    //   "tomorrow, 9AM-12PM"   tomorrow
    //   "2026-07-17, 3PM-6PM"  ISO date format
    if (pickupSlot.isNotEmpty) {
      try {
        // Normalize: remove leading/trailing whitespace, collapse multiple spaces
        final raw = pickupSlot.trim();

        // Split date part from time part.
        // Accept comma OR (space before a digit/time token) as separators.
        // Pattern: split on first comma if present, else split on first numeric time token.
        String dateStr;
        String? timeStr;

        if (raw.contains(',')) {
          final commaIdx = raw.indexOf(',');
          dateStr = raw.substring(0, commaIdx).trim().toLowerCase();
          timeStr = raw.substring(commaIdx + 1).trim().toUpperCase();
        } else {
          // No comma — match 'today', 'tomorrow', or ISO date at start
          final noCommaMatch = RegExp(
            r'^(today|tomorrow|\d{4}-\d{2}-\d{2})\s+(.+)',
            caseSensitive: false,
          ).firstMatch(raw);
          if (noCommaMatch != null) {
            dateStr = noCommaMatch.group(1)!.trim().toLowerCase();
            timeStr = noCommaMatch.group(2)!.trim().toUpperCase();
          } else {
            dateStr = raw.toLowerCase();
          }
        }

        // Parse the date part
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        DateTime date;
        if (dateStr == 'today') {
          date = today;
        } else if (dateStr == 'tomorrow') {
          date = today.add(const Duration(days: 1));
        } else {
          date = DateTime.parse(dateStr);
        }

        // Parse the time part — find first hour in "3PM", "3pm", "3:00PM", "15"
        // Accept both "-" and " to " as range separators
        if (timeStr != null && timeStr.isNotEmpty) {
          // Replace " TO " with "-" so we can split uniformly
          final normalizedTime = timeStr.replaceAll(RegExp(r'\s+TO\s+'), '-');
          // Take the start of the range only
          final startPart = normalizedTime.split('-').first.trim();
          // Match hour with optional minutes and AM/PM
          final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?').firstMatch(startPart);
          if (match != null) {
            int hour = int.parse(match.group(1)!);
            final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
            final amPm = match.group(3);
            if (amPm == 'PM' && hour < 12) hour += 12;
            if (amPm == 'AM' && hour == 12) hour = 0;
            // If no AM/PM and hour <= 12, try to detect PM context
            // (e.g. "3" in "3-6PM" should be PM)
            if (amPm == null && hour < 12) {
              // Check if the whole time string contains PM anywhere
              if (timeStr.contains('PM')) hour += 12;
            }
            return DateTime(date.year, date.month, date.day, hour, minute);
          }
          // No time found — use noon as default for that date
          return DateTime(date.year, date.month, date.day, 12);
        }
        return DateTime(date.year, date.month, date.day, 12);
      } catch (_) {
        // fall through to fallback
      }
    }

    // ── Fallback: createdAt + 1 hour (NEVER jump to tomorrow by default) ─────
    // The old default was createdAt + 24h which caused the "pickup in 24h" bug.
    return createdAt.add(const Duration(hours: 1));
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
