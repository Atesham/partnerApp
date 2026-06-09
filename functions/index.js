/**
 * Scrapwell Partner — Firebase Cloud Functions
 *
 * Trigger: orders/{orderId} onWrite
 * Action:  When an order transitions INTO status='searchingPartner',
 *          fan out FCM push notifications to all approved, online partners
 *          whose FCM tokens are stored in the partners collection.
 *
 * Deploy:  firebase deploy --only functions
 */

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();

// ─────────────────────────────────────────────────────────────────────────────
// Haversine distance helper (km)
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Main trigger — fires on every write to orders/{orderId}
// ─────────────────────────────────────────────────────────────────────────────
exports.notifyPartnersOnNewOrder = onDocumentWritten(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Only fire when status TRANSITIONS INTO 'searchingPartner'
    // (new order created OR re-broadcast after cancel)
    const wasSearching = before?.status === "searchingPartner";
    const isSearching = after?.status === "searchingPartner";

    if (isSearching && wasSearching) return null; // No change — skip
    if (!isSearching) return null; // Not entering searchingPartner — skip

    const order = after;
    const orderId = event.params.orderId;

    logger.info(`New order broadcast: ${orderId} (type=${order.pickupType})`);

    // ── 1. Fetch all approved partners with FCM tokens ───────────────────────
    const partnersSnap = await db
      .collection("partners")
      .where("status", "==", "approved")
      .get();

    if (partnersSnap.empty) {
      logger.warn("No approved partners found.");
      return null;
    }

    const orderLat = order.customerLat || 0;
    const orderLng = order.customerLng || 0;
    const pickupType = order.pickupType || "instant";

    const tokens = [];

    for (const doc of partnersSnap.docs) {
      const partner = doc.data();

      // Must have an FCM token
      if (!partner.fcmToken || partner.fcmToken.trim() === "") continue;

      // For instant pickups: only notify partners within their configured radius
      if (pickupType === "instant") {
        const pLat = partner.currentLat || partner.shopLat || 0;
        const pLng = partner.currentLng || partner.shopLng || 0;
        const maxKm = Math.min(partner.maxDistanceKm || 10, 30); // hard cap 30 km

        if (pLat === 0 && pLng === 0) continue; // No location data

        const dist = haversineKm(pLat, pLng, orderLat, orderLng);
        if (dist > maxKm) continue; // Outside radius — skip

        // Scrap category match — partner must handle at least one category
        if (
          order.scrapItems &&
          order.scrapItems.length > 0 &&
          partner.scrapCategories &&
          partner.scrapCategories.length > 0
        ) {
          const orderCats = order.scrapItems.map((i) =>
            (i.category || "").trim().toLowerCase()
          );
          const partnerCats = partner.scrapCategories.map((c) =>
            (c || "").trim().toLowerCase()
          );
          const hasMatch = orderCats.some((c) => partnerCats.includes(c));
          if (!hasMatch) continue;
        }
      }
      // For scheduled: notify all eligible approved partners (auto-assignment handles the rest)

      tokens.push(partner.fcmToken);
    }

    if (tokens.length === 0) {
      logger.info("No eligible partner tokens to notify.");
      return null;
    }

    logger.info(`Sending FCM to ${tokens.length} partners for order ${orderId}`);

    // ── 2. Build FCM payload ─────────────────────────────────────────────────
    const estimatedPayout = order.estimatedPayout
      ? `₹${Math.round(order.estimatedPayout)}`
      : "Check app";

    const title =
      pickupType === "instant"
        ? "🚨 New Instant Pickup Nearby!"
        : "📅 New Scheduled Pickup Assigned!";

    const body =
      pickupType === "instant"
        ? `${order.areaName || order.customerAddress} · Est. ${estimatedPayout} — Accept fast!`
        : `${order.pickupSlot} · ${order.areaName || order.customerAddress} · Est. ${estimatedPayout}`;

    // ── 3. Send in batches of 500 (FCM multicast limit) ──────────────────────
    const messaging = getMessaging();
    const batchSize = 500;
    const results = [];

    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: batch,
          notification: {
            title,
            body,
          },
          data: {
            orderId,
            pickupType,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "new_order",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "scrapwell_partner_channel",
              priority: "max",
              defaultSound: true,
              defaultVibrateTimings: true,
              notificationCount: 1,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: { title, body },
                sound: "default",
                badge: 1,
                contentAvailable: true,
              },
            },
          },
        });

        results.push(response);
        logger.info(
          `Batch ${i / batchSize + 1}: ${response.successCount} success, ${response.failureCount} failed`
        );

        // Clean up stale tokens (optional — prevents token buildup)
        response.responses.forEach(async (r, idx) => {
          if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
            const staleToken = batch[idx];
            logger.warn(`Removing stale FCM token: ${staleToken.substring(0, 20)}...`);
            // Find and clear the stale token from partners collection
            const staleSnap = await db
              .collection("partners")
              .where("fcmToken", "==", staleToken)
              .limit(1)
              .get();
            if (!staleSnap.empty) {
              await staleSnap.docs[0].ref.update({ fcmToken: null });
            }
          }
        });
      } catch (err) {
        logger.error("FCM batch send error:", err);
      }
    }

    return null;
  }
);
