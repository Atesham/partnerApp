import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lead_model.dart';
import '../models/partner_model.dart';

class LeadService {
  static final LeadService instance = LeadService._();
  LeadService._();

  final _db = FirebaseFirestore.instance;

  /// Listen for new unassigned leads near this partner.
  /// Returns a stream of unassigned leads from the last 2 minutes.
  Stream<List<LeadModel>> nearbyLeadsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    final twoMinutesAgo = DateTime.now().subtract(const Duration(minutes: 2));

    return _db
        .collection('leads')
        .where('isAssigned', isEqualTo: false)
        .where('createdAt',
            isGreaterThan: Timestamp.fromDate(twoMinutesAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => LeadModel.fromJson(d.data()))
          .where((lead) => !lead.isExpired)
          .toList();
    });
  }

  /// Atomically accept a lead — first-come-first-served.
  /// Returns true if this partner won the assignment.
  Future<bool> acceptLead(LeadModel lead, PartnerModel partner) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      bool accepted = false;

      await _db.runTransaction((tx) async {
        final leadRef = _db.collection('leads').doc(lead.leadId);
        final orderRef = _db.collection('orders').doc(lead.orderId);

        final leadSnap = await tx.get(leadRef);
        if (!leadSnap.exists) throw Exception('Lead not found');

        final currentData = leadSnap.data()!;
        if (currentData['isAssigned'] == true) {
          throw Exception('Already assigned');
        }

        // Check expiry
        final expiresAt =
            (currentData['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          throw Exception('Lead expired');
        }

        // Assign atomically
        tx.update(leadRef, {
          'isAssigned': true,
          'assignedPartnerId': uid,
          'assignedAt': FieldValue.serverTimestamp(),
        });

        tx.update(orderRef, {
          'partnerId': uid,
          'partnerName': partner.fullName,
          'partnerPhone': partner.phone,
          'partnerShopName': partner.shopName,
          'status': 'partnerAssigned',
          'assignedAt': FieldValue.serverTimestamp(),
        });

        accepted = true;
      });

      return accepted;
    } catch (e) {
      return false;
    }
  }

  /// Decline a lead (no-op in DB, just UI dismiss)
  void declineLead(String leadId) {
    // Could log declinations for analytics
  }

  /// Create a demo lead for testing (dev only)
  Future<void> createDemoLead() async {
    final leadId = _db.collection('leads').doc().id;
    final orderId = _db.collection('orders').doc().id;
    final now = DateTime.now();

    final lead = LeadModel(
      leadId: leadId,
      orderId: orderId,
      customerId: 'demo_customer',
      customerName: 'Rahul Sharma',
      customerAddress: 'Sector 62, Noida',
      customerLat: 28.6278,
      customerLng: 77.3649,
      scrapCategories: ['Paper', 'Plastic', 'Metal'],
      estimatedWeight: 25.0,
      estimatedPayout: 480.0,
      imageUrls: [],
      customerNotes: 'Please bring bags for packaging',
      pickupSlot: 'Today, 3:00 PM – 5:00 PM',
      areaName: 'Sector 62, Noida',
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 90)),
    );

    final order = {
      'orderId': orderId,
      'customerId': 'demo_customer',
      'customerName': 'Rahul Sharma',
      'customerPhone': '+919999999999',
      'customerAddress': 'Sector 62, Noida',
      'customerLat': 28.6278,
      'customerLng': 77.3649,
      'scrapItems': [
        {'category': 'Paper', 'estimatedWeight': 10.0, 'estimatedRate': 15.0, 'actualWeight': 0.0, 'actualRate': 15.0},
        {'category': 'Plastic', 'estimatedWeight': 5.0, 'estimatedRate': 20.0, 'actualWeight': 0.0, 'actualRate': 20.0},
        {'category': 'Metal', 'estimatedWeight': 10.0, 'estimatedRate': 23.0, 'actualWeight': 0.0, 'actualRate': 23.0},
      ],
      'imageUrls': [],
      'customerNotes': 'Please bring bags for packaging',
      'pickupSlot': 'Today, 3:00 PM – 5:00 PM',
      'status': 'searchingPartner',
      'estimatedPayout': 480.0,
      'finalPayout': 0.0,
      'areaName': 'Sector 62, Noida',
      'customerConfirmed': false,
      'createdAt': Timestamp.fromDate(now),
    };

    final batch = _db.batch();
    batch.set(_db.collection('leads').doc(leadId), lead.toJson());
    batch.set(_db.collection('orders').doc(orderId), order);
    await batch.commit();
  }
}
