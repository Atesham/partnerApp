import 'package:cloud_firestore/cloud_firestore.dart';

enum PartnerStatus { pending, approved, suspended }

enum VehicleType { bicycle, motorcycle, autoRickshaw, miniTruck, handCart }

class ReservedSlot {
  final String date;
  final String slot;
  final String orderId;

  const ReservedSlot({
    required this.date,
    required this.slot,
    required this.orderId,
  });

  factory ReservedSlot.fromJson(Map<String, dynamic> json) {
    return ReservedSlot(
      date: json['date'] ?? '',
      slot: json['slot'] ?? '',
      orderId: json['orderId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'slot': slot,
        'orderId': orderId,
      };
}

class PartnerModel {
  final String uid;
  final String phone;
  final String fullName;
  final String shopName;
  final String shopAddress;
  final String exactShopAddress;
  final double shopLat;
  final double shopLng;
  final List<String> scrapCategories;
  final String profilePhotoUrl;
  final String shopPhotoUrl;
  final String? gstNumber;
  final String aadhaarNumber;
  final String aadhaarFrontUrl;
  final String aadhaarBackUrl;
  final List<VehicleType> vehicleTypes;
  final String workingHoursStart;
  final String workingHoursEnd;
  final PartnerStatus status;
  final bool isOnline;
  final double currentLat;
  final double currentLng;
  final double totalEarnings;
  final int totalOrders;
  final double rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  // -- Compliance, Trust & Operations Stack Fields --
  final double trustScore;
  final double completionRate;
  final double cancellationRate;
  final String fraudScore;
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String upiId;
  final bool bankVerified;
  final String aadhaarHash;
  final bool aadhaarVerified;
  final bool shopPhotosVerified;
  final bool businessInfoVerified;
  final bool addressVerified;
  final bool deleted;
  final double maxDistanceKm;
  final int maxScheduledSlots;
  final List<ReservedSlot> reservedSlots;
  final double commissionDueBalance;
  final double commissionTotalBilled;
  final DateTime? commissionCycleStartedAt;
  final DateTime? commissionDueAt;
  final DateTime? commissionLastPaymentAt;
  final bool commissionBlocked;

  const PartnerModel({
    required this.uid,
    required this.phone,
    required this.fullName,
    required this.shopName,
    required this.shopAddress,
    this.exactShopAddress = '',
    required this.shopLat,
    required this.shopLng,
    required this.scrapCategories,
    this.profilePhotoUrl = '',
    this.shopPhotoUrl = '',
    this.gstNumber,
    required this.aadhaarNumber,
    this.aadhaarFrontUrl = '',
    this.aadhaarBackUrl = '',
    required this.vehicleTypes,
    this.workingHoursStart = '09:00',
    this.workingHoursEnd = '18:00',
    this.status = PartnerStatus.pending,
    this.isOnline = false,
    this.currentLat = 0.0,
    this.currentLng = 0.0,
    this.totalEarnings = 0.0,
    this.totalOrders = 0,
    this.rating = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.trustScore = 95.0,
    this.completionRate = 98.0,
    this.cancellationRate = 2.0,
    this.fraudScore = 'Low Risk',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.upiId = '',
    this.bankVerified = false,
    this.aadhaarHash = '',
    this.aadhaarVerified = false,
    this.shopPhotosVerified = false,
    this.businessInfoVerified = false,
    this.addressVerified = false,
    this.deleted = false,
    this.maxDistanceKm = 15.0,
    this.maxScheduledSlots = 10,
    this.reservedSlots = const [],
    this.commissionDueBalance = 0.0,
    this.commissionTotalBilled = 0.0,
    this.commissionCycleStartedAt,
    this.commissionDueAt,
    this.commissionLastPaymentAt,
    this.commissionBlocked = false,
  });

  factory PartnerModel.empty() => PartnerModel(
        uid: '',
        phone: '',
        fullName: '',
        shopName: '',
        shopAddress: '',
        exactShopAddress: '',
        shopLat: 0,
        shopLng: 0,
        scrapCategories: [],
        aadhaarNumber: '',
        vehicleTypes: [VehicleType.motorcycle],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        maxDistanceKm: 15.0,
        maxScheduledSlots: 10,
        reservedSlots: const [],
        commissionDueBalance: 0.0,
        commissionTotalBilled: 0.0,
        commissionBlocked: false,
      );

  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    return PartnerModel(
      uid: json['uid'] ?? '',
      phone: json['phone'] ?? '',
      fullName: json['fullName'] ?? '',
      shopName: json['shopName'] ?? '',
      shopAddress: json['shopAddress'] ?? '',
      exactShopAddress: json['exactShopAddress'] ?? '',
      shopLat: (json['shopLat'] ?? 0.0).toDouble(),
      shopLng: (json['shopLng'] ?? 0.0).toDouble(),
      scrapCategories: List<String>.from(json['scrapCategories'] ?? []),
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      shopPhotoUrl: json['shopPhotoUrl'] ?? '',
      gstNumber: json['gstNumber'],
      aadhaarNumber: json['aadhaarNumber'] ?? '',
      aadhaarFrontUrl: json['aadhaarFrontUrl'] ?? '',
      aadhaarBackUrl: json['aadhaarBackUrl'] ?? '',
      vehicleTypes: (json['vehicleTypes'] as List<dynamic>?)?.map((e) {
        return VehicleType.values.firstWhere(
          (v) => v.name == e,
          orElse: () => VehicleType.motorcycle,
        );
      }).toList() ?? [VehicleType.motorcycle],
      workingHoursStart: json['workingHoursStart'] ?? '09:00',
      workingHoursEnd: json['workingHoursEnd'] ?? '18:00',
      status: PartnerStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => PartnerStatus.pending,
      ),
      isOnline: json['isOnline'] ?? false,
      currentLat: (json['currentLat'] ?? 0.0).toDouble(),
      currentLng: (json['currentLng'] ?? 0.0).toDouble(),
      maxDistanceKm: (json['maxDistanceKm'] ?? 15.0).toDouble(),
      totalEarnings: double.tryParse(json['totalEarnings']?.toString() ?? '0') ?? 0.0,
      totalOrders: (json['totalOrders'] ?? 0),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      trustScore: (json['trustScore'] ?? 95.0).toDouble(),
      completionRate: (json['completionRate'] ?? 98.0).toDouble(),
      cancellationRate: (json['cancellationRate'] ?? 2.0).toDouble(),
      fraudScore: json['fraudScore'] ?? 'Low Risk',
      bankAccountName: json['bankAccountName'] ?? '',
      bankAccountNumber: json['bankAccountNumber'] ?? '',
      bankIfsc: json['bankIfsc'] ?? '',
      upiId: json['upiId'] ?? '',
      bankVerified: json['bankVerified'] ?? false,
      aadhaarHash: json['aadhaarHash'] ?? '',
      aadhaarVerified: json['aadhaarVerified'] ?? false,
      shopPhotosVerified: json['shopPhotosVerified'] ?? false,
      businessInfoVerified: json['businessInfoVerified'] ?? false,
      addressVerified: json['addressVerified'] ?? false,
      deleted: json['deleted'] ?? false,
      maxScheduledSlots: json['maxScheduledSlots'] ?? 10,
      reservedSlots: (json['reservedSlots'] as List<dynamic>? ?? [])
          .map((e) => ReservedSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      commissionDueBalance:
          (json['commissionDueBalance'] ?? 0.0).toDouble(),
      commissionTotalBilled:
          (json['commissionTotalBilled'] ?? 0.0).toDouble(),
      commissionCycleStartedAt:
          (json['commissionCycleStartedAt'] as Timestamp?)?.toDate(),
      commissionDueAt: (json['commissionDueAt'] as Timestamp?)?.toDate(),
      commissionLastPaymentAt:
          (json['commissionLastPaymentAt'] as Timestamp?)?.toDate(),
      commissionBlocked: json['commissionBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phone': phone,
      'fullName': fullName,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'exactShopAddress': exactShopAddress,
      'shopLat': shopLat,
      'shopLng': shopLng,
      'scrapCategories': scrapCategories,
      'profilePhotoUrl': profilePhotoUrl,
      'shopPhotoUrl': shopPhotoUrl,
      'gstNumber': gstNumber,
      'aadhaarNumber': aadhaarNumber,
      'aadhaarFrontUrl': aadhaarFrontUrl,
      'aadhaarBackUrl': aadhaarBackUrl,
      'vehicleTypes': vehicleTypes.map((e) => e.name).toList(),
      'workingHoursStart': workingHoursStart,
      'workingHoursEnd': workingHoursEnd,
      'status': status.name,
      'isOnline': isOnline,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'maxDistanceKm': maxDistanceKm,
      'totalEarnings': totalEarnings,
      'totalOrders': totalOrders,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Geohash for geoflutterfire
      'position': {
        'geohash': _geohash(currentLat, currentLng),
        'geopoint': GeoPoint(currentLat, currentLng),
      },
      'trustScore': trustScore,
      'completionRate': completionRate,
      'cancellationRate': cancellationRate,
      'fraudScore': fraudScore,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
      'upiId': upiId,
      'bankVerified': bankVerified,
      'aadhaarHash': aadhaarHash,
      'aadhaarVerified': aadhaarVerified,
      'shopPhotosVerified': shopPhotosVerified,
      'businessInfoVerified': businessInfoVerified,
      'addressVerified': addressVerified,
      'deleted': deleted,
      'maxScheduledSlots': maxScheduledSlots,
      'reservedSlots': reservedSlots.map((e) => e.toJson()).toList(),
      'commissionDueBalance': commissionDueBalance,
      'commissionTotalBilled': commissionTotalBilled,
      'commissionCycleStartedAt': commissionCycleStartedAt != null
          ? Timestamp.fromDate(commissionCycleStartedAt!)
          : null,
      'commissionDueAt':
          commissionDueAt != null ? Timestamp.fromDate(commissionDueAt!) : null,
      'commissionLastPaymentAt': commissionLastPaymentAt != null
          ? Timestamp.fromDate(commissionLastPaymentAt!)
          : null,
      'commissionBlocked': commissionBlocked,
    };
  }

  PartnerModel copyWith({
    String? uid,
    String? phone,
    String? fullName,
    String? shopName,
    String? shopAddress,
    String? exactShopAddress,
    double? shopLat,
    double? shopLng,
    List<String>? scrapCategories,
    String? profilePhotoUrl,
    String? shopPhotoUrl,
    String? gstNumber,
    String? aadhaarNumber,
    String? aadhaarFrontUrl,
    String? aadhaarBackUrl,
    List<VehicleType>? vehicleTypes,
    String? workingHoursStart,
    String? workingHoursEnd,
    PartnerStatus? status,
    bool? isOnline,
    double? currentLat,
    double? currentLng,
    double? totalEarnings,
    int? totalOrders,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? trustScore,
    double? completionRate,
    double? cancellationRate,
    String? fraudScore,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? upiId,
    bool? bankVerified,
    String? aadhaarHash,
    bool? aadhaarVerified,
    bool? shopPhotosVerified,
    bool? businessInfoVerified,
    bool? addressVerified,
    bool? deleted,
    double? maxDistanceKm,
    int? maxScheduledSlots,
    List<ReservedSlot>? reservedSlots,
    double? commissionDueBalance,
    double? commissionTotalBilled,
    DateTime? commissionCycleStartedAt,
    DateTime? commissionDueAt,
    DateTime? commissionLastPaymentAt,
    bool? commissionBlocked,
  }) {
    return PartnerModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      exactShopAddress: exactShopAddress ?? this.exactShopAddress,
      shopLat: shopLat ?? this.shopLat,
      shopLng: shopLng ?? this.shopLng,
      scrapCategories: scrapCategories ?? this.scrapCategories,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      shopPhotoUrl: shopPhotoUrl ?? this.shopPhotoUrl,
      gstNumber: gstNumber ?? this.gstNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      aadhaarFrontUrl: aadhaarFrontUrl ?? this.aadhaarFrontUrl,
      aadhaarBackUrl: aadhaarBackUrl ?? this.aadhaarBackUrl,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalOrders: totalOrders ?? this.totalOrders,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trustScore: trustScore ?? this.trustScore,
      completionRate: completionRate ?? this.completionRate,
      cancellationRate: cancellationRate ?? this.cancellationRate,
      fraudScore: fraudScore ?? this.fraudScore,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      upiId: upiId ?? this.upiId,
      bankVerified: bankVerified ?? this.bankVerified,
      aadhaarHash: aadhaarHash ?? this.aadhaarHash,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      shopPhotosVerified: shopPhotosVerified ?? this.shopPhotosVerified,
      businessInfoVerified: businessInfoVerified ?? this.businessInfoVerified,
      addressVerified: addressVerified ?? this.addressVerified,
      deleted: deleted ?? this.deleted,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      maxScheduledSlots: maxScheduledSlots ?? this.maxScheduledSlots,
      reservedSlots: reservedSlots ?? this.reservedSlots,
      commissionDueBalance:
          commissionDueBalance ?? this.commissionDueBalance,
      commissionTotalBilled:
          commissionTotalBilled ?? this.commissionTotalBilled,
      commissionCycleStartedAt:
          commissionCycleStartedAt ?? this.commissionCycleStartedAt,
      commissionDueAt: commissionDueAt ?? this.commissionDueAt,
      commissionLastPaymentAt:
          commissionLastPaymentAt ?? this.commissionLastPaymentAt,
      commissionBlocked: commissionBlocked ?? this.commissionBlocked,
    );
  }

  // Simple geohash approximation (real implementation uses geoflutterfire)
  static String _geohash(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  bool get isApproved => status == PartnerStatus.approved;
  bool get isPending => status == PartnerStatus.pending;
  bool get hasCommissionDue => commissionDueBalance > 0.01;
  bool get isCommissionOverLimit => commissionDueBalance >= 500;
  bool get isCommissionOverdue =>
      hasCommissionDue &&
      commissionDueAt != null &&
      DateTime.now().isAfter(commissionDueAt!);
  bool get shouldBlockForCommission =>
      commissionBlocked || isCommissionOverLimit || isCommissionOverdue;
  String get displayName => fullName.isNotEmpty ? fullName : 'Partner';
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
