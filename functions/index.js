/**
 * Scrapwell Partner Firebase Cloud Functions.
 *
 * Existing behavior preserved:
 * - Notify eligible partners when an order enters searchingPartner.
 * - Credit the customer wallet and activity log when an order completes.
 *
 * Added:
 * - Add 2% partner commission due on every completed order.
 * - Keep commission totals on partners/{partnerId} in real time.
 * - Pause partners when due is overdue or reaches Rs 500.
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();
const COMMISSION_RATE = 0.02;
const COMMISSION_LIMIT = 500;
const MAX_INSTANT_PARTNERS = 30;
const LIVE_LOCATION_STALE_MS = 15 * 60 * 1000; // 15 minutes
const SCHEDULED_BUFFER_MINUTES = 30;
const LEAD_CHANNEL_ID = "scrapwell_leads_channel";

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) *
    Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function roundMoney(value) {
  return Math.round(value * 100) / 100;
}

function nextTuesdayFrom(date) {
  const result = new Date(date);
  result.setHours(23, 59, 59, 999);
  const day = result.getDay();
  const daysUntilTuesday = (2 - day + 7) % 7 || 7;
  result.setDate(result.getDate() + daysUntilTuesday);
  return result;
}

function isCommissionBlocked(partner, now = new Date()) {
  const due = toNumber(partner.commissionDueBalance);
  if (due <= 0) return false;
  if (due >= COMMISSION_LIMIT) return true;
  const dueAt = partner.commissionDueAt?.toDate?.();
  return Boolean(dueAt && dueAt.getTime() < now.getTime());
}

function orderCategoriesMatch(order, partner) {
  // Support both nested scrapItems[].category and flat scrapCategories array
  const fromItems = (order.scrapItems || [])
    .map((i) => (i.category || "").trim().toLowerCase())
    .filter(Boolean);
  const fromFlat = (order.scrapCategories || [])
    .map((c) => (c || "").trim().toLowerCase())
    .filter(Boolean);
  const orderCats = fromItems.length > 0 ? fromItems : fromFlat;
  const partnerCats = (partner.scrapCategories || [])
    .map((c) => (c || "").trim().toLowerCase())
    .filter(Boolean);
  // If either side has no categories, allow (don't filter out)
  if (orderCats.length === 0 || partnerCats.length === 0) return true;
  return orderCats.some((c) => partnerCats.includes(c));
}

function parseScheduledDate(order) {
  if (order.scheduledAt?.toDate) return order.scheduledAt.toDate();
  const fallback = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const slot = (order.pickupSlot || "").split(",");
  try {
    const datePart = (slot[0] || "").trim().toLowerCase();
    let date = fallback;
    if (datePart === "today") {
      const now = new Date();
      date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    } else if (datePart === "tomorrow") {
      const now = new Date();
      date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    } else if (datePart) {
      date = new Date(datePart);
    }
    const timePart = (slot[1] || "").trim().toUpperCase();
    const match = /(\d+)\s*(AM|PM)/.exec(timePart.split("-")[0] || "");
    if (!match) return new Date(date.setHours(12, 0, 0, 0));
    let hour = Number(match[1]);
    if (match[2] === "PM" && hour < 12) hour += 12;
    if (match[2] === "AM" && hour === 12) hour = 0;
    return new Date(date.setHours(hour, 0, 0, 0));
  } catch (_) {
    return fallback;
  }
}

function isWithinWorkingHours(partner, time) {
  try {
    const [sh, sm] = (partner.workingHoursStart || "09:00")
      .split(":")
      .map(Number);
    const [eh, em] = (partner.workingHoursEnd || "18:00")
      .split(":")
      .map(Number);
    const start = sh * 60 + sm;
    const end = eh * 60 + em;
    const current = time.getHours() * 60 + time.getMinutes();
    return end > start
      ? current >= start && current <= end
      : current >= start || current <= end;
  } catch (_) {
    return true;
  }
}

function parseReservedSlot(slot) {
  try {
    const parts = (slot.slot || "").split(",");
    const datePart = (parts[0] || slot.date || "").trim().toLowerCase();
    let date;
    if (datePart === "today") {
      const now = new Date();
      date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    } else if (datePart === "tomorrow") {
      const now = new Date();
      date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    } else {
      date = new Date(datePart);
    }
    const timePart = (parts[1] || "").trim().toUpperCase();
    const match = /(\d+)\s*(AM|PM)/.exec(timePart.split("-")[0] || "");
    if (match) {
      let hour = Number(match[1]);
      if (match[2] === "PM" && hour < 12) hour += 12;
      if (match[2] === "AM" && hour === 12) hour = 0;
      date.setHours(hour, 0, 0, 0);
    }
    return Number.isNaN(date.getTime()) ? null : date;
  } catch (_) {
    return null;
  }
}

function hasSlotConflict(partner, scheduledTime) {
  return (partner.reservedSlots || []).some((slot) => {
    const slotTime = parseReservedSlot(slot);
    if (!slotTime) return false;
    const diff = Math.abs(slotTime.getTime() - scheduledTime.getTime());
    return diff < SCHEDULED_BUFFER_MINUTES * 60 * 1000;
  });
}

async function pausePartnerForCommission(partnerId, partner, now = new Date()) {
  if (!isCommissionBlocked(partner, now)) return false;

  const updates = {
    isOnline: false,
    isAvailable: false,
    commissionBlocked: true,
    commissionBlockedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await Promise.all([
    db.collection("partners").doc(partnerId).set(updates, { merge: true }),
    db.collection("live_locations").doc(partnerId).set({
      isOnline: false,
      isAvailable: false,
      assignedOrderId: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true }),
  ]);
  return true;
}

async function sendToTokens(tokens, payload) {
  const messaging = getMessaging();
  const batchSize = 500;

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);
    const response = await messaging.sendEachForMulticast({
      tokens: batch,
      ...payload,
    });

    logger.info(
      `FCM batch ${i / batchSize + 1}: ` +
      `${response.successCount} success, ${response.failureCount} failed`
    );

    await Promise.all(response.responses.map(async (r, idx) => {
      if (
        r.success ||
        r.error?.code !== "messaging/registration-token-not-registered"
      ) {
        return;
      }
      const staleToken = batch[idx];
      const staleSnap = await db
        .collection("partners")
        .where("fcmToken", "==", staleToken)
        .limit(1)
        .get();
      if (!staleSnap.empty) {
        await staleSnap.docs[0].ref.update({ fcmToken: null });
      }
    }));
  }
}

function leadPayload({ order, orderId, pickupType, title, body }) {
  return {
    notification: { title, body },
    data: {
      orderId,
      pickupType,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      type: "new_order",
      sound: "default",
    },
    android: {
      priority: "high",
      ttl: 90 * 1000,
      notification: {
        channelId: LEAD_CHANNEL_ID,
        priority: "max",
        sound: "default",
        defaultSound: true,
        defaultVibrateTimings: true,
        visibility: "public",
        notificationCount: 1,
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          badge: 1,
        },
      },
    },
  };
}

async function findInstantPartners(order, now) {
  const orderLat = toNumber(order.customerLat);
  const orderLng = toNumber(order.customerLng);
  const liveSnap = await db
    .collection("live_locations")
    .where("isOnline", "==", true)
    .where("isAvailable", "==", true)
    .get();

  const candidates = [];
  await Promise.all(liveSnap.docs.map(async (liveDoc) => {
    const live = liveDoc.data();
    const updatedAt = live.updatedAt?.toDate?.();
    if (updatedAt && now.getTime() - updatedAt.getTime() > LIVE_LOCATION_STALE_MS) {
      return;
    }

    const partnerId = live.partnerId || liveDoc.id;
    const partnerSnap = await db.collection("partners").doc(partnerId).get();
    if (!partnerSnap.exists) return;
    const partner = partnerSnap.data();
    // Only skip truly deleted partners or commission-blocked ones
    // (pending partners can still receive and accept orders in the app)
    if (partner.deleted === true) return;
    if (!partner.fcmToken || partner.fcmToken.trim() === "") return;
    if (isCommissionBlocked(partner, now)) {
      await pausePartnerForCommission(partnerId, partner, now);
      return;
    }
    if (!orderCategoriesMatch(order, partner)) return;

    // Use live lat/lng first; fall back to partner doc's current/shop coords
    const pLat = toNumber(live.latitude || live.lat ||
      partner.currentLat || partner.shopLat);
    const pLng = toNumber(live.longitude || live.lng ||
      partner.currentLng || partner.shopLng);
    const maxKm = Math.min(
      toNumber(live.maxDistanceKm || partner.maxDistanceKm) || 10,
      30
    );
    if (pLat === 0 && pLng === 0) return;
    const distanceKm = haversineKm(pLat, pLng, orderLat, orderLng);
    if (distanceKm > maxKm) return;

    candidates.push({
      partnerId,
      token: partner.fcmToken,
      distanceKm,
    });
  }));

  candidates.sort((a, b) => a.distanceKm - b.distanceKm);
  return candidates.slice(0, MAX_INSTANT_PARTNERS);
}

async function assignScheduledOrder(orderId, order, now) {
  const scheduledTime = parseScheduledDate(order);
  const orderLat = toNumber(order.customerLat);
  const orderLng = toNumber(order.customerLng);
  const snap = await db
    .collection("partners")
    .where("status", "==", "approved")
    .get();

  const candidates = [];
  for (const doc of snap.docs) {
    const partner = doc.data();
    if (partner.deleted === true) continue;
    if (!partner.fcmToken || partner.fcmToken.trim() === "") continue;
    if (isCommissionBlocked(partner, now)) {
      await pausePartnerForCommission(doc.id, partner, now);
      continue;
    }
    if (!orderCategoriesMatch(order, partner)) continue;
    if (!isWithinWorkingHours(partner, scheduledTime)) continue;
    if (hasSlotConflict(partner, scheduledTime)) continue;
    if ((partner.reservedSlots || []).length >= (partner.maxScheduledSlots || 10)) {
      continue;
    }

    const pLat = toNumber(partner.currentLat || partner.shopLat);
    const pLng = toNumber(partner.currentLng || partner.shopLng);
    const distanceKm = haversineKm(pLat, pLng, orderLat, orderLng);
    if (distanceKm > (toNumber(partner.maxDistanceKm) || 15)) continue;

    candidates.push({
      partnerId: doc.id,
      partner,
      distanceKm,
      rosterLoad: (partner.reservedSlots || []).length,
    });
  }

  candidates.sort((a, b) =>
    a.rosterLoad - b.rosterLoad || a.distanceKm - b.distanceKm
  );
  const selected = candidates[0];
  if (!selected) return null;

  const dateStr = [
    scheduledTime.getFullYear(),
    String(scheduledTime.getMonth() + 1).padStart(2, "0"),
    String(scheduledTime.getDate()).padStart(2, "0"),
  ].join("-");
  const newSlot = {
    date: dateStr,
    slot: order.pickupSlot || "",
    orderId,
  };

  await db.runTransaction(async (tx) => {
    const orderRef = db.collection("orders").doc(orderId);
    const partnerRef = db.collection("partners").doc(selected.partnerId);
    const orderSnap = await tx.get(orderRef);
    const partnerSnap = await tx.get(partnerRef);
    if (!orderSnap.exists || !partnerSnap.exists) {
      throw new Error("Order or partner missing");
    }
    const freshOrder = orderSnap.data();
    if (freshOrder.status !== "searchingPartner") {
      throw new Error("Order already assigned");
    }
    const freshPartner = partnerSnap.data();
    const freshSlots = freshPartner.reservedSlots || [];
    if (hasSlotConflict(freshPartner, scheduledTime)) {
      throw new Error("Fresh slot conflict");
    }
    if (freshSlots.length >= (freshPartner.maxScheduledSlots || 10)) {
      throw new Error("Fresh capacity full");
    }

    tx.update(orderRef, {
      partnerId: selected.partnerId,
      partnerName: freshPartner.fullName || "",
      partnerPhone: freshPartner.phone || "",
      partnerShopName: freshPartner.shopName || "",
      reservedPartnerId: selected.partnerId,
      status: "reserved",
      assignedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(partnerRef, {
      reservedSlots: [...freshSlots, newSlot],
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection("live_locations").doc(selected.partnerId), {
      assignedScheduledOrderId: orderId,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return selected;
}

exports.notifyPartnersOnNewOrder = onDocumentWritten(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const wasSearching = before?.status === "searchingPartner";
    const isSearching = after?.status === "searchingPartner";

    if (!isSearching || wasSearching) return null;

    const order = after;
    const orderId = event.params.orderId;
    const pickupType = order.pickupType || "instant";
    const now = new Date();
    const estimatedPayout = order.estimatedPayout
      ? `Rs ${Math.round(order.estimatedPayout)}`
      : "Check app";
    const title = pickupType === "instant"
      ? "New instant pickup nearby"
      : "New scheduled pickup";
    const body = pickupType === "instant"
      ? `${order.areaName || order.customerAddress} - Est. ${estimatedPayout}`
      : `${order.pickupSlot} - ${order.areaName || order.customerAddress}`;

    if (pickupType === "scheduled") {
      const assigned = await assignScheduledOrder(orderId, order, now);
      if (!assigned) {
        logger.info(`No scheduled partner available for order ${orderId}.`);
        return null;
      }
      await sendToTokens([assigned.partner.fcmToken], leadPayload({
        order,
        orderId,
        pickupType,
        title: "Scheduled pickup assigned",
        body,
      }));
      logger.info(`Scheduled order ${orderId} assigned to ${assigned.partnerId}.`);
      return null;
    }

    // For instant orders: ensure expiresAt is set (120 seconds from now)
    // This allows the Firestore stream on the partner app to auto-expire orders.
    if (!order.expiresAt) {
      const expiresAt = new Date(now.getTime() + 120 * 1000);
      await db.collection("orders").doc(orderId).set(
        { expiresAt, updatedAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      logger.info(`Set expiresAt on instant order ${orderId} to ${expiresAt.toISOString()}`);
    }

    const candidates = await findInstantPartners(order, now);
    const tokens = candidates.map((c) => c.token);
    if (tokens.length === 0) {
      logger.info(`No eligible instant partners for order ${orderId}.`);
      return null;
    }

    await db.collection("orders").doc(orderId).set({
      eligiblePartnerIds: candidates.map((c) => c.partnerId),
      leadBroadcastedAt: FieldValue.serverTimestamp(),
      leadBroadcastCount: FieldValue.increment(1),
    }, { merge: true });

    await sendToTokens(tokens, leadPayload({
      order,
      orderId,
      pickupType,
      title,
      body,
    }));

    return null;
  }
);

exports.handleOrderCompletion = onDocumentWritten(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    const wasCompleted = before?.status === "completed";
    const isCompleted = after?.status === "completed";

    if (!isCompleted || wasCompleted) return null;

    const orderId = event.params.orderId;
    const order = after;
    const finalPayout = toNumber(order.finalPayout || order.estimatedPayout);
    const commissionAmount = roundMoney(finalPayout * COMMISSION_RATE);
    const partnerId = order.partnerId || order.reservedPartnerId;
    const customerId = order.customerId;

    try {
      await db.runTransaction(async (tx) => {
        const activityQuery = db
          .collection("activities")
          .where("orderId", "==", orderId)
          .limit(1);
        const existingActivity = await tx.get(activityQuery);
        const partnerRef = partnerId
          ? db.collection("partners").doc(partnerId)
          : null;
        const ledgerRef = partnerRef
          ? partnerRef.collection("commission_ledger").doc(orderId)
          : null;
        const ledgerSnap = ledgerRef ? await tx.get(ledgerRef) : null;
        const partnerSnap = partnerRef ? await tx.get(partnerRef) : null;

        if (existingActivity.empty && customerId) {
          const scrapItems = order.scrapItems || [];
          const categories = scrapItems
            .map((e) => e.category || "")
            .filter((c) => c.length > 0);
          const totalWeight = scrapItems.reduce((sum, e) => {
            const actual = toNumber(e.actualWeight);
            const estimated = toNumber(e.estimatedWeight);
            return sum + (actual > 0 ? actual : estimated);
          }, 0);
          const fullAddress = order.customerAddress || "";
          const locality = fullAddress.length > 0
            ? fullAddress.split(",")[0].trim()
            : "Near you";
          const shortOrderId = orderId.length > 6
            ? orderId.substring(orderId.length - 6)
            : orderId;

          tx.set(db.collection("activities").doc(), {
            orderId,
            type: categories[0] || "Scrap Materials",
            amount: finalPayout,
            kg: totalWeight,
            locality,
            city: order.city || "Unknown",
            timestamp: FieldValue.serverTimestamp(),
          });

          const userRef = db.collection("users").doc(customerId);
          tx.update(userRef, {
            walletBalance: FieldValue.increment(finalPayout),
          });
          tx.set(userRef.collection("transactions").doc(), {
            title: `Scrap Sold (#${shortOrderId})`,
            amount: finalPayout,
            isCredit: true,
            type: "sell",
            timestamp: FieldValue.serverTimestamp(),
            orderId,
          });
        }

        if (!partnerRef || !ledgerRef || commissionAmount <= 0) return;
        if (ledgerSnap?.exists) return;

        const partner = partnerSnap.exists ? partnerSnap.data() : {};
        const currentDue = toNumber(partner.commissionDueBalance);
        const newDue = roundMoney(currentDue + commissionAmount);
        const existingDueAt = partner.commissionDueAt?.toDate?.();
        const dueAt = existingDueAt || nextTuesdayFrom(new Date());
        const blocked = newDue >= COMMISSION_LIMIT ||
          dueAt.getTime() < Date.now();

        tx.set(ledgerRef, {
          orderId,
          billedAmount: finalPayout,
          commissionRate: COMMISSION_RATE,
          commissionAmount,
          status: "due",
          createdAt: FieldValue.serverTimestamp(),
          dueAt,
        });

        tx.set(partnerRef, {
          commissionDueBalance: newDue,
          commissionTotalBilled: FieldValue.increment(finalPayout),
          commissionCycleStartedAt:
            partner.commissionCycleStartedAt || FieldValue.serverTimestamp(),
          commissionDueAt: dueAt,
          commissionBlocked: blocked,
          isOnline: blocked ? false : partner.isOnline,
          isAvailable: blocked ? false : true,
          totalEarnings: FieldValue.increment(finalPayout),
          totalOrders: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        if (blocked) {
          tx.set(db.collection("live_locations").doc(partnerId), {
            isOnline: false,
            isAvailable: false,
            assignedOrderId: null,
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      });

      logger.info(`Processed completion and commission for order ${orderId}.`);
    } catch (error) {
      logger.error(`Completion processing failed for order ${orderId}:`, error);
    }

    return null;
  }
);

exports.enforcePartnerCommissionStatus = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Asia/Kolkata",
  },
  async () => {
    const snap = await db
      .collection("partners")
      .where("commissionDueBalance", ">", 0)
      .get();
    const now = new Date();
    let blocked = 0;

    for (const doc of snap.docs) {
      if (await pausePartnerForCommission(doc.id, doc.data(), now)) {
        blocked += 1;
      }
    }

    logger.info(`Commission enforcement completed. Blocked ${blocked} partners.`);
    return null;
  }
);