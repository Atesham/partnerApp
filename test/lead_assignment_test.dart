import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwell_partner/core/services/lead_service.dart';
import 'package:scrapwell_partner/core/models/order_model.dart';
import 'package:scrapwell_partner/core/models/partner_model.dart';

void main() {
  group('LeadService - Working Hours Validation', () {
    final service = LeadService.instance;

    test('Standard working hours (09:00 - 18:00)', () {
      final partner = PartnerModel(
        uid: 'p1',
        phone: '1234567890',
        fullName: 'Partner One',
        shopName: 'Shop One',
        shopAddress: 'Address One',
        shopLat: 28.6139,
        shopLng: 77.2090,
        scrapCategories: ['paper'],
        aadhaarNumber: '111122223333',
        vehicleTypes: [VehicleType.motorcycle],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        workingHoursStart: '09:00',
        workingHoursEnd: '18:00',
      );

      // Within hours
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 10, 0)),
        isTrue,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 9, 0)),
        isTrue,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 18, 0)),
        isTrue,
      );

      // Outside hours
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 8, 59)),
        isFalse,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 18, 01)),
        isFalse,
      );
    });

    test('Overnight working hours (22:00 - 06:00)', () {
      final partner = PartnerModel(
        uid: 'p2',
        phone: '1234567890',
        fullName: 'Partner Two',
        shopName: 'Shop Two',
        shopAddress: 'Address Two',
        shopLat: 28.6139,
        shopLng: 77.2090,
        scrapCategories: ['paper'],
        aadhaarNumber: '111122223333',
        vehicleTypes: [VehicleType.motorcycle],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        workingHoursStart: '22:00',
        workingHoursEnd: '06:00',
      );

      // Within hours
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 23, 0)),
        isTrue,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 3, 0)),
        isTrue,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 5, 59)),
        isTrue,
      );

      // Outside hours
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 21, 59)),
        isFalse,
      );
      expect(
        service.isWithinWorkingHours(partner, DateTime(2026, 6, 10, 6, 01)),
        isFalse,
      );
    });
  });

  group('LeadService - Slot Conflict Validation', () {
    final service = LeadService.instance;

    test('Conflicting slots within 30-minute window', () {
      final partner = PartnerModel(
        uid: 'p1',
        phone: '1234567890',
        fullName: 'Partner One',
        shopName: 'Shop One',
        shopAddress: 'Address One',
        shopLat: 28.6139,
        shopLng: 77.2090,
        scrapCategories: ['paper'],
        aadhaarNumber: '111122223333',
        vehicleTypes: [VehicleType.motorcycle],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reservedSlots: [
          const ReservedSlot(
            date: '2026-06-10',
            slot: '2026-06-10, 10AM-12PM',
            orderId: 'order1',
          ),
        ],
      );

      // Conflict (exactly at slot start, or within 30 minutes)
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 10, 10, 0)),
        isTrue,
      );
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 10, 10, 15)),
        isTrue,
      );
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 10, 9, 45)),
        isTrue,
      );

      // No conflict (outside 30 minutes window)
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 10, 9, 30)),
        isFalse,
      );
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 10, 10, 30)),
        isFalse,
      );
      expect(
        service.hasSlotConflict(partner, DateTime(2026, 6, 11, 10, 0)),
        isFalse,
      );
    });
  });

  group('LeadService - Candidate Evaluation', () {
    final service = LeadService.instance;

    final baseOrder = OrderModel(
      orderId: 'o1',
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: '1111111111',
      customerAddress: 'Delhi',
      customerLat: 28.6139,
      customerLng: 77.2090, // New Delhi center
      scrapItems: [ScrapItem(category: 'paper', estimatedWeight: 5.0, estimatedRate: 10.0)],
      pickupSlot: '2026-06-10, 10AM-12PM',
      status: OrderStatus.searchingPartner,
      estimatedPayout: 50.0,
      areaName: 'Connaught Place',
      createdAt: DateTime(2026, 6, 9, 12, 0),
      pickupType: 'scheduled',
    );

    final basePartner = PartnerModel(
      uid: 'p1',
      phone: '1234567890',
      fullName: 'Partner One',
      shopName: 'Shop One',
      shopAddress: 'Address One',
      shopLat: 28.6100, // Very close to New Delhi center (0.98 km away)
      shopLng: 77.2000,
      scrapCategories: ['paper'],
      aadhaarNumber: '111122223333',
      vehicleTypes: [VehicleType.motorcycle],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: PartnerStatus.approved,
      maxDistanceKm: 5.0,
      workingHoursStart: '09:00',
      workingHoursEnd: '18:00',
    );

    test('Eligible Partner - successfully matched', () {
      final res = service.evaluateScheduledCandidate(
        partner: basePartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNotNull);
      expect(res!.$1.uid, equals('p1'));
      expect(res.$2, lessThan(2.0)); // < 2km distance
    });

    test('Ineligible Partner - Too far away', () {
      final farPartner = basePartner.copyWith(
        shopLat: 28.9100, // Very far away (~30 km away)
        shopLng: 77.2000,
      );

      final res = service.evaluateScheduledCandidate(
        partner: farPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });

    test('Ineligible Partner - Scrap category mismatch', () {
      final plasticPartner = basePartner.copyWith(
        scrapCategories: ['plastic', 'metal'], // Does not deal in 'paper'
      );

      final res = service.evaluateScheduledCandidate(
        partner: plasticPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });

    test('Ineligible Partner - Working hours conflict', () {
      final nightPartner = basePartner.copyWith(
        workingHoursStart: '22:00', // Outside order time (10:00)
        workingHoursEnd: '06:00',
      );

      final res = service.evaluateScheduledCandidate(
        partner: nightPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });

    test('Ineligible Partner - Booking slot overlap', () {
      final busyPartner = basePartner.copyWith(
        reservedSlots: [
          const ReservedSlot(
            date: '2026-06-10',
            slot: '2026-06-10, 10AM-12PM', // Overlaps with 10:00 booking time
            orderId: 'other_order',
          ),
        ],
      );

      final res = service.evaluateScheduledCandidate(
        partner: busyPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });

    test('Ineligible Partner - Capacity limit reached', () {
      final fullPartner = basePartner.copyWith(
        maxScheduledSlots: 2,
        reservedSlots: [
          const ReservedSlot(date: '2026-06-10', slot: '2026-06-10, 1PM-3PM', orderId: 'id1'),
          const ReservedSlot(date: '2026-06-10', slot: '2026-06-10, 4PM-6PM', orderId: 'id2'),
        ],
      );

      final res = service.evaluateScheduledCandidate(
        partner: fullPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });

    test('Ineligible Partner - Not approved', () {
      final pendingPartner = basePartner.copyWith(
        status: PartnerStatus.pending,
      );

      final res = service.evaluateScheduledCandidate(
        partner: pendingPartner,
        order: baseOrder,
        scheduledTime: DateTime(2026, 6, 10, 10, 0),
        minDistance: double.infinity,
      );

      expect(res, isNull);
    });
  });
}
