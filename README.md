 Full Criteria Checklist Used for schedule orders 
When a scheduled order is created, the system loops through all approved partners and evaluates them based on these criteria in :

Approval Status: Partner status must be approved and the profile must not be marked as deleted.
Financial Good Standing: The partner must not be blocked due to outstanding commissions (shouldBlockForCommission must be false).
Declination History: The partner must not have previously declined/ignored this order ID (unless the customer has increased the tip amount).
Coverage Distance: The distance from the partner's current location (or fallback shop location if offline/GPS unavailable) to the customer must be less than or equal to the partner's preferred maximum search radius (maxDistanceKm).
Scrap Categories Match: The partner must buy at least one of the scrap categories requested in the order.
Working Hours: The order scheduled time must fall within the partner's declared working hours (workingHoursStart to workingHoursEnd).
Time Conflict Buffer: The partner must not have any conflicting reservations within a 30-minute window (kScheduledBufferMinutes) before or after the order's scheduled time.
Capacity Check: The partner's total active reserved slots must be strictly less than their maximum allowed scheduled slots (maxScheduledSlots).
Proximity Optimization: Out of all partners who satisfy the above conditions, the one with the shortest distance to the customer is selected.




Instanct pickup Broadcast Eligibility Criteria
For an instant pickup lead to appear in a partner's feed, it must pass the following filters in -

Online & Available Status: The partner must be Online (location tracking active) and not currently on another active order.
Financial Standing: The partner must not have any pending commission blocks (shouldBlockForCommission must be false).
Decline History: The order is hidden if the partner already declined/ignored it (unless the customer has increased the tip amount).
Radius Coverage: The distance between the customer and the partner's live GPS location (or shop location fallback) must be within the partner's maximum radius (hard capped at 30 km).
Category Match: The partner must accept at least one of the scrap categories requested in the order.
Active Order: The lead must not have expired (checked against the order's expiresAt timestamp with a 5-minute buffer).
Sorting: Eligible orders are sorted and displayed closest first.
2. The Acceptance Race ("First-Come, First-Served")
When a partner clicks Accept, the app executes a Firestore Transaction xecutes a Firestore Transaction in acceptOrder to guarantee fairness:

Order Availability Lock: It checks that the order's status is still exactly searchingPartner. If another partner accepted it a millisecond earlier, the transaction fails and the screen updates to show "Order already taken".
Double-Booking Prevention: It verifies that the accepting partner hasn't gone offline or accepted another order in the meantime.
Atomic Assignment: If all checks pass, it atomically updates:
The order status to partnerAssigned with the partner's details.
The partner's state to isAvailable: false in both partners and live_locations collections, instantly removing them from receiving other broadcast feeds until this order is completed or cancelled.
 
