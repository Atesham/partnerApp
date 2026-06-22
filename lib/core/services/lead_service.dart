import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
import '../models/partner_model.dart';
import '../utils/location_utils.dart';
import '../services/location_tracking_service.dart';

/// Instant pickup radius hard cap — orders beyond this are never shown
/// regardless of the partner's configured maxDistanceKm.
const double kInstantPickupMaxRadiusKm = 30.0;

/// Buffer between scheduled pickups (minutes). A partner won't be assigned
/// a new slot if another slot exists within this window.
const int kScheduledBufferMinutes = 30;

class LeadService {
  static final LeadService instance = LeadService._();
  LeadService._();

  final _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // INSTANT PICKUP — Broadcast to all live partners in radius
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream of instant pickup orders that this partner is eligible to see.
  ///
  /// Flow:
  ///   1. Listen to orders with status='searchingPartner' + pickupType='instant'
  ///   2. Filter client-side by partner's live location + radius
  ///   3. ALL eligible partners receive the same stream simultaneously
  ///   4. First-accept wins via atomic Firestore transaction
  Stream<List<OrderModel>> instantPickupStream(PartnerModel partner) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    if (partner.shouldBlockForCommission) return Stream.value(const []);

    final partnerLat = partner.currentLat != 0.0 ? partner.currentLat : partner.shopLat;
    final partnerLng = partner.currentLng != 0.0 ? partner.currentLng : partner.shopLng;

    // Effective radius: the smaller of partner's preference and the hard cap
    final effectiveRadius = partner.maxDistanceKm.clamp(1.0, kInstantPickupMaxRadiusKm);

    return _db
        .collection('orders')
        .where('status', isEqualTo: 'searchingPartner')
        .where('pickupType', isEqualTo: 'instant')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map((d) => OrderModel.fromJson(d.data()))
          .where((order) {
            // Exclude expired orders (allowing a 5-minute buffer for client-server clock skew)
            if (order.expiresAt != null && now.isAfter(order.expiresAt!.add(const Duration(minutes: 5)))) {
              return false;
            }
            // Scrap Category Filter — partner must accept at least one of the order's categories
            final dealsInOrderScrap = order.scrapItems.isEmpty ||
                order.scrapItems.any((item) {
                  final orderCat = item.category.trim().toLowerCase();
                  return partner.scrapCategories.any((pCat) => pCat.trim().toLowerCase() == orderCat);
                });
            if (!dealsInOrderScrap) return false;

            // Radius filter — Haversine distance from partner's live location
            final dist = LocationUtils.calculateDistance(
              partnerLat,
              partnerLng,
              order.customerLat,
              order.customerLng,
            );
            return dist <= effectiveRadius;
          })
          .toList()
        // Sort nearest-first so the feed is always ordered by distance
        ..sort((a, b) {
          final da = LocationUtils.calculateDistance(
              partnerLat, partnerLng, a.customerLat, a.customerLng);
          final db = LocationUtils.calculateDistance(
              partnerLat, partnerLng, b.customerLat, b.customerLng);
          return da.compareTo(db);
        });
    });
  }

  /// Unified stream for the home feed — combines instant orders visible to
  /// this partner with their reserved/scheduled orders.
  Stream<List<OrderModel>> nearbyOrdersStream(PartnerModel partner) {
    return instantPickupStream(partner);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ACCEPT — Atomic first-come-first-served for instant pickup
  // ────────────────────────────────────────────────────────────────────────────

  /// Atomically accept an instant pickup order.
  /// Returns true only if this partner won the assignment race.
  Future<bool> acceptOrder(OrderModel order, PartnerModel partner) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (partner.shouldBlockForCommission) return false;

    try {
      bool accepted = false;

      await _db.runTransaction((tx) async {
        final orderRef = _db.collection('orders').doc(order.orderId);
        final partnerRef = _db.collection('partners').doc(uid);
        final liveLocRef = _db.collection('live_locations').doc(uid);

        // ── 1. Verify order is still open ──────────────────────────────────
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) throw Exception('Order not found');

        final orderData = orderSnap.data()!;
        if (orderData['status'] != 'searchingPartner') {
          throw Exception('Order already taken');
        }

        // Check expiry (allowing a 5-minute buffer for client-server clock skew)
        if (orderData['expiresAt'] != null) {
          final expiresAt = (orderData['expiresAt'] as Timestamp).toDate();
          if (DateTime.now().isAfter(expiresAt.add(const Duration(minutes: 5)))) {
            throw Exception('Order expired');
          }
        }

        // ── 2. Verify partner is approved and available ────────────────────
        final partnerSnap = await tx.get(partnerRef);
        if (!partnerSnap.exists) throw Exception('Partner not found');

        final partnerData = partnerSnap.data()!;
        final freshPartner = PartnerModel.fromJson(partnerData);
        if (freshPartner.shouldBlockForCommission) {
          throw Exception('Commission payment due');
        }
        if (partnerData['isAvailable'] != true) {
          throw Exception('Partner not available');
        }

        // ── 3. Verify partner is in live_locations (online + available) ────
        final liveLocSnap = await tx.get(liveLocRef);
        if (!liveLocSnap.exists) {
          throw Exception('Partner not found in live_locations');
        }
        final liveData = liveLocSnap.data()!;
        if (liveData['isOnline'] != true) {
          throw Exception('Partner is offline');
        }
        if (liveData['isAvailable'] != true) {
          throw Exception('Partner is currently on another order');
        }

        // ── 4. Atomic assignment ───────────────────────────────────────────
        // Update order
        tx.update(orderRef, {
          'partnerId': uid,
          'partnerName': partner.fullName,
          'partnerPhone': partner.phone,
          'partnerShopName': partner.shopName,
          'status': 'partnerAssigned',
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Mark partner unavailable in partners collection
        tx.update(partnerRef, {
          'isAvailable': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Mark partner unavailable in live_locations and store the order ref
        tx.set(
          liveLocRef,
          {
            'isAvailable': false,
            'assignedOrderId': order.orderId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        accepted = true;
      });

      // Update location tracking service state (outside transaction — best-effort)
      if (accepted) {
        await LocationTrackingService.instance.markOrderAssigned(order.orderId);
      }

      return accepted;
    } catch (_) {
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SCHEDULED ORDER AUTO-ASSIGNMENT
  // ────────────────────────────────────────────────────────────────────────────

  /// Auto-assign a scheduled order to the nearest eligible partner.
  ///
  /// Eligibility criteria (in order):
  ///   1. Partner must be online (live_locations.isOnline=true) OR in partners collection
  ///   2. Partner status must be 'approved'
  ///   3. Currently within their working hours
  ///   4. Distance from shop/current location ≤ their maxDistanceKm
  ///   5. No reserved slot within [kScheduledBufferMinutes] of the order's scheduled time
  ///   6. reservedSlots.length < maxScheduledSlots (capacity check)
  ///
  /// Returns the uid of the partner assigned, or null if none found.
  Future<String?> autoAssignScheduledOrder(OrderModel order) async {
    if (order.pickupType != 'scheduled') return null;

    final scheduledTime = order.scheduledDateTime;

    PartnerModel? bestPartner;
    double minDistance = double.infinity;

    try {
      final partnersSnap = await _db
          .collection('partners')
          .where('status', isEqualTo: 'approved')
          .get();

      for (final doc in partnersSnap.docs) {
        final p = PartnerModel.fromJson(doc.data());
        final candidate = evaluateScheduledCandidate(
          partner: p,
          order: order,
          scheduledTime: scheduledTime,
          minDistance: minDistance,
        );
        if (candidate != null) {
          minDistance = candidate.$2;
          bestPartner = candidate.$1;
        }
      }
    } catch (_) {}

    if (bestPartner == null) return null;

    // ── Step 3: Assign the order to bestPartner ────────────────────────────
    try {
      final assignedUid = bestPartner.uid;
      await _db.runTransaction((tx) async {
        final orderRef = _db.collection('orders').doc(order.orderId);
        final partnerRef = _db.collection('partners').doc(assignedUid);
        final liveLocRef = _db.collection('live_locations').doc(assignedUid);

        // Re-verify order is still unassigned
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) throw Exception('Order not found');
        if (orderSnap.data()!['status'] != 'searchingPartner') {
          throw Exception('Order already assigned');
        }

        // Re-fetch partner for fresh reservedSlots
        final partnerSnap = await tx.get(partnerRef);
        if (!partnerSnap.exists) throw Exception('Partner not found');
        final freshPartner = PartnerModel.fromJson(partnerSnap.data()!);

        // Re-check eligibility with fresh data
        if (!isWithinWorkingHours(freshPartner, scheduledTime)) {
          throw Exception('Partner outside working hours');
        }
        if (hasSlotConflict(freshPartner, scheduledTime)) {
          throw Exception('Slot conflict');
        }
        if (freshPartner.reservedSlots.length >= freshPartner.maxScheduledSlots) {
          throw Exception('Partner at capacity');
        }

        // Build new slot
        final dateStr = '${scheduledTime.year}-${scheduledTime.month.toString().padLeft(2, '0')}-${scheduledTime.day.toString().padLeft(2, '0')}';
        final newSlot = ReservedSlot(
          date: dateStr,
          slot: order.pickupSlot,
          orderId: order.orderId,
        );
        final updatedSlots = [...freshPartner.reservedSlots, newSlot];

        // Assign order
        tx.update(orderRef, {
          'partnerId': assignedUid,
          'partnerName': freshPartner.fullName,
          'partnerPhone': freshPartner.phone,
          'partnerShopName': freshPartner.shopName,
          'reservedPartnerId': assignedUid,
          'status': OrderStatus.reserved.name,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update partner's reserved slots
        tx.update(partnerRef, {
          'reservedSlots': updatedSlots.map((s) => s.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update live_locations with assigned order reference (non-blocking
        // for partner availability — scheduled orders don't block instant pickups)
        final liveSnap = await tx.get(liveLocRef);
        if (liveSnap.exists) {
          tx.set(
            liveLocRef,
            {
              'assignedScheduledOrderId': order.orderId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      return bestPartner.uid;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CANCEL RESERVED ORDER — reassign to next eligible
  // ────────────────────────────────────────────────────────────────────────────

  /// Cancel a reserved/scheduled order and automatically reassign it to the
  /// next nearest eligible partner.
  Future<bool> cancelReservedOrder(OrderModel order) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // Security: Cannot cancel within 1 hour of scheduled pickup time
    final diff = order.scheduledDateTime.difference(DateTime.now());
    if (diff.inMinutes < 60) {
      throw Exception(
          'Cannot cancel reservation within 1 hour of scheduled pickup time.');
    }

    try {
      final orderRef = _db.collection('orders').doc(order.orderId);
      final currentPartnerRef = _db.collection('partners').doc(uid);

      // Get other approved partners
      final partnersSnap = await _db
          .collection('partners')
          .where('status', isEqualTo: 'approved')
          .get();

      PartnerModel? nextPartner;
      double minDistance = double.infinity;
      final scheduledTime = order.scheduledDateTime;

      for (final doc in partnersSnap.docs) {
        final p = PartnerModel.fromJson(doc.data());
        if (p.uid == uid) continue; // Skip current partner

        final candidate = evaluateScheduledCandidate(
          partner: p,
          order: order,
          scheduledTime: scheduledTime,
          minDistance: minDistance,
        );
        if (candidate != null) {
          minDistance = candidate.$2;
          nextPartner = candidate.$1;
        }
      }

      await _db.runTransaction((tx) async {
        // Remove from current partner's calendar
        final currentPartnerSnap = await tx.get(currentPartnerRef);
        if (currentPartnerSnap.exists) {
          final currentData =
              PartnerModel.fromJson(currentPartnerSnap.data()!);
          final updatedSlots = currentData.reservedSlots
              .where((s) => s.orderId != order.orderId)
              .toList();
          tx.update(currentPartnerRef, {
            'reservedSlots': updatedSlots.map((s) => s.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (nextPartner != null) {
          // Reassign to next partner
          final nextRef = _db.collection('partners').doc(nextPartner.uid);
          final nextSnap = await tx.get(nextRef);
          if (nextSnap.exists) {
            final nextData = PartnerModel.fromJson(nextSnap.data()!);
            final dateStr =
                '${scheduledTime.year}-${scheduledTime.month.toString().padLeft(2, '0')}-${scheduledTime.day.toString().padLeft(2, '0')}';
            final updatedSlots = [
              ...nextData.reservedSlots,
              ReservedSlot(
                date: dateStr,
                slot: order.pickupSlot,
                orderId: order.orderId,
              )
            ];
            tx.update(nextRef, {
              'reservedSlots': updatedSlots.map((s) => s.toJson()).toList(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          tx.update(orderRef, {
            'partnerId': nextPartner.uid,
            'partnerName': nextPartner.fullName,
            'partnerPhone': nextPartner.phone,
            'partnerShopName': nextPartner.shopName,
            'reservedPartnerId': nextPartner.uid,
            'status': OrderStatus.reserved.name,
            'assignedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // No eligible partner — return to broadcast pool
          tx.update(orderRef, {
            'partnerId': null,
            'partnerName': null,
            'partnerPhone': null,
            'partnerShopName': null,
            'reservedPartnerId': null,
            'status': OrderStatus.searchingPartner.name,
            'assignedAt': null,
            'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(minutes: 2))),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Decline an instant lead (UI dismiss only — no DB write needed for broadcast model)
  void declineLead(String orderId) {
    // Declinations are UI-only — the order stays open for other partners.
    // Could log to analytics if needed.
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  /// Evaluate a partner as a candidate for a scheduled order assignment.
  /// Returns (partner, distance) if eligible, null otherwise.
  (PartnerModel, double)? evaluateScheduledCandidate({
    required PartnerModel partner,
    required OrderModel order,
    required DateTime scheduledTime,
    required double minDistance,
  }) {
    if (partner.status != PartnerStatus.approved) return null;
    if (partner.deleted) return null;
    if (partner.shouldBlockForCommission) return null;

    // Use live GPS location if available, else fall back to shop location
    final pLat = partner.currentLat != 0.0 ? partner.currentLat : partner.shopLat;
    final pLng = partner.currentLng != 0.0 ? partner.currentLng : partner.shopLng;

    final dist = LocationUtils.calculateDistance(
      pLat,
      pLng,
      order.customerLat,
      order.customerLng,
    );

    // Must be within partner's chosen coverage radius
    if (dist > partner.maxDistanceKm) return null;

    // Scrap Category Filter — partner must accept at least one of the order's categories
    final dealsInOrderScrap = order.scrapItems.isEmpty ||
        order.scrapItems.any((item) {
          final orderCat = item.category.trim().toLowerCase();
          return partner.scrapCategories.any((pCat) => pCat.trim().toLowerCase() == orderCat);
        });
    if (!dealsInOrderScrap) return null;

    // Must be within working hours of the scheduled time
    if (!isWithinWorkingHours(partner, scheduledTime)) return null;

    // Must not have a conflicting slot within the buffer window
    if (hasSlotConflict(partner, scheduledTime)) return null;

    // Must have capacity
    if (partner.reservedSlots.length >= partner.maxScheduledSlots) return null;

    // Is this partner closer than the current best?
    if (dist >= minDistance) return null;

    return (partner, dist);
  }

  /// Check if the target time is within the partner's declared working hours.
  bool isWithinWorkingHours(PartnerModel partner, DateTime time) {
    try {
      final startParts = partner.workingHoursStart.split(':');
      final endParts = partner.workingHoursEnd.split(':');
 
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes =
          int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final timeMinutes = time.hour * 60 + time.minute;
 
      if (endMinutes > startMinutes) {
        // Normal window e.g. 09:00–18:00
        return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
      } else {
        // Overnight window e.g. 22:00–06:00
        return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
      }
    } catch (_) {
      return true; // Assume available if parsing fails
    }
  }

  /// Returns true if the partner already has a reserved slot within
  /// [kScheduledBufferMinutes] of the given [scheduledTime].
  bool hasSlotConflict(PartnerModel partner, DateTime scheduledTime) {
    for (final slot in partner.reservedSlots) {
      final slotOrder = _parseSlotDateTime(slot);
      if (slotOrder == null) continue;

      final diff = slotOrder.difference(scheduledTime).abs();
      if (diff.inMinutes < kScheduledBufferMinutes) return true;
    }
    return false;
  }

  /// Parse a ReservedSlot into a DateTime (best-effort).
  DateTime? _parseSlotDateTime(ReservedSlot slot) {
    try {
      // slot.slot format: "2026-06-10, 10AM-12PM" or similar
      final parts = slot.slot.split(',');
      final dateStr = parts[0].trim().toLowerCase();
      DateTime date;
      if (dateStr == 'today') {
        final now = DateTime.now();
        date = DateTime(now.year, now.month, now.day);
      } else if (dateStr == 'tomorrow') {
        final now = DateTime.now();
        date = DateTime(now.year, now.month, now.day + 1);
      } else {
        date = DateTime.parse(dateStr);
      }
      if (parts.length > 1) {
        final timeStr = parts[1].trim().toUpperCase();
        final startStr = timeStr.split('-')[0].trim();
        final match = RegExp(r'(\d+)\s*(AM|PM)').firstMatch(startStr);
        if (match != null) {
          int hour = int.parse(match.group(1)!);
          final amPm = match.group(2);
          if (amPm == 'PM' && hour < 12) hour += 12;
          if (amPm == 'AM' && hour == 12) hour = 0;
          return DateTime(date.year, date.month, date.day, hour);
        }
      }
      return DateTime(date.year, date.month, date.day, 12);
    } catch (_) {
      return null;
    }
  }
}
