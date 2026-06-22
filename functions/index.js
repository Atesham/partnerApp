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

const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");

initializeApp();

const db = getFirestore();
const COMMISSION_RATE = 0.02;
const COMMISSION_LIMIT = 500;

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
    db.collection("partners").doc(partnerId).set(updates, {merge: true}),
    db.collection("live_locations").doc(partnerId).set({
      isOnline: false,
      isAvailable: false,
      assignedOrderId: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
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
        await staleSnap.docs[0].ref.update({fcmToken: null});
      }
    }));
  }
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
    const orderLat = toNumber(order.customerLat);
    const orderLng = toNumber(order.customerLng);
    const pickupType = order.pickupType || "instant";

    const partnersSnap = await db
      .collection("partners")
      .where("status", "==", "approved")
      .where("isOnline", "==", true)
      .get();

    const tokens = [];
    const now = new Date();

    for (const doc of partnersSnap.docs) {
      const partner = doc.data();
      if (!partner.fcmToken || partner.fcmToken.trim() === "") continue;
      if (isCommissionBlocked(partner, now)) {
        await pausePartnerForCommission(doc.id, partner, now);
        continue;
      }

      if (pickupType === "instant") {
        const pLat = toNumber(partner.currentLat || partner.shopLat);
        const pLng = toNumber(partner.currentLng || partner.shopLng);
        const maxKm = Math.min(toNumber(partner.maxDistanceKm) || 10, 30);
        if (pLat === 0 && pLng === 0) continue;
        if (haversineKm(pLat, pLng, orderLat, orderLng) > maxKm) continue;

        const orderCats = (order.scrapItems || [])
          .map((i) => (i.category || "").trim().toLowerCase())
          .filter(Boolean);
        const partnerCats = (partner.scrapCategories || [])
          .map((c) => (c || "").trim().toLowerCase());
        if (
          orderCats.length > 0 &&
          partnerCats.length > 0 &&
          !orderCats.some((c) => partnerCats.includes(c))
        ) {
          continue;
        }
      }

      tokens.push(partner.fcmToken);
    }

    if (tokens.length === 0) {
      logger.info(`No eligible tokens for order ${orderId}.`);
      return null;
    }

    const estimatedPayout = order.estimatedPayout
      ? `Rs ${Math.round(order.estimatedPayout)}`
      : "Check app";
    const title = pickupType === "instant"
      ? "New instant pickup nearby"
      : "New scheduled pickup";
    const body = pickupType === "instant"
      ? `${order.areaName || order.customerAddress} - Est. ${estimatedPayout}`
      : `${order.pickupSlot} - ${order.areaName || order.customerAddress}`;

    await sendToTokens(tokens, {
      notification: {title, body},
      data: {
        orderId,
        pickupType,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "new_order",
      },
      android: {
        priority: "high",
        ttl: 60 * 1000,
        notification: {
          channelId: "scrapwell_partner_channel",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        headers: {"apns-priority": "10"},
        payload: {
          aps: {
            alert: {title, body},
            sound: "default",
            badge: 1,
          },
        },
      },
    });

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
        }, {merge: true});

        if (blocked) {
          tx.set(db.collection("live_locations").doc(partnerId), {
            isOnline: false,
            isAvailable: false,
            assignedOrderId: null,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
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
