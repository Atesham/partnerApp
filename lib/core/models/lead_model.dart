import 'package:cloud_firestore/cloud_firestore.dart';

/// A broadcast lead that all online partners in range can see.
/// First accept wins — assigned atomically via Firestore transaction.
class LeadModel {
  final String leadId;
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final List<String> scrapCategories;
  final double estimatedWeight;
  final double estimatedPayout;
  final List<String> imageUrls;
  final String? customerNotes;
  final String pickupSlot;
  final String areaName;
  final bool isAssigned;
  final String? assignedPartnerId;
  final DateTime createdAt;
  final DateTime expiresAt;

  const LeadModel({
    required this.leadId,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    required this.scrapCategories,
    required this.estimatedWeight,
    required this.estimatedPayout,
    this.imageUrls = const [],
    this.customerNotes,
    required this.pickupSlot,
    required this.areaName,
    this.isAssigned = false,
    this.assignedPartnerId,
    required this.createdAt,
    required this.expiresAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      leadId: json['leadId'] ?? '',
      orderId: json['orderId'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      customerLat: (json['customerLat'] ?? 0.0).toDouble(),
      customerLng: (json['customerLng'] ?? 0.0).toDouble(),
      scrapCategories: List<String>.from(json['scrapCategories'] ?? []),
      estimatedWeight: (json['estimatedWeight'] ?? 0.0).toDouble(),
      estimatedPayout: (json['estimatedPayout'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      customerNotes: json['customerNotes'],
      pickupSlot: json['pickupSlot'] ?? '',
      areaName: json['areaName'] ?? '',
      isAssigned: json['isAssigned'] ?? false,
      assignedPartnerId: json['assignedPartnerId'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(seconds: 120)),
    );
  }

  Map<String, dynamic> toJson() => {
        'leadId': leadId,
        'orderId': orderId,
        'customerId': customerId,
        'customerName': customerName,
        'customerAddress': customerAddress,
        'customerLat': customerLat,
        'customerLng': customerLng,
        'scrapCategories': scrapCategories,
        'estimatedWeight': estimatedWeight,
        'estimatedPayout': estimatedPayout,
        'imageUrls': imageUrls,
        'customerNotes': customerNotes,
        'pickupSlot': pickupSlot,
        'areaName': areaName,
        'isAssigned': isAssigned,
        'assignedPartnerId': assignedPartnerId,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        // For geo-querying
        'position': {
          'geopoint': GeoPoint(customerLat, customerLng),
        },
      };

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  String get categoryList => scrapCategories.join(' · ');
  int get secondsRemaining {
    final secs = timeUntilExpiry.inSeconds;
    return secs < 0 ? 0 : secs;
  }
}
