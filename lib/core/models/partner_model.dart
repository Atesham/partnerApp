import 'package:cloud_firestore/cloud_firestore.dart';

enum PartnerStatus { pending, approved, suspended }

enum VehicleType { bicycle, motorcycle, autoRickshaw, miniTruck, handCart }

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
      totalEarnings: double.tryParse(json['totalEarnings']?.toString() ?? '0') ?? 0.0,
      totalOrders: (json['totalOrders'] ?? 0),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
    );
  }

  // Simple geohash approximation (real implementation uses geoflutterfire)
  static String _geohash(double lat, double lng) {
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  bool get isApproved => status == PartnerStatus.approved;
  bool get isPending => status == PartnerStatus.pending;
  String get displayName => fullName.isNotEmpty ? fullName : 'Partner';
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
