/**
 * Scrapwell Partner — Firebase Cloud Functions
 * Codebase: kabad | Project: kabad-8fbc6
 *
 * Trigger: orders/{orderId} — onDocumentWritten
 *
 * When an order transitions INTO status='searchingPartner', fan out FCM
 * push notifications to every approved partner whose FCM token is on file
 * AND who is within range + category match.
 *
 * This fires for BOTH:
 *   - New instant pickup orders (notify all nearby partners simultaneously)
 *   - Scheduled orders re-entering searchingPartner after a cancel
 *
 * Deploy: firebase deploy --only functions:kabad
 */

"use strict";

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

const db = getFirestore();

// ─────────────────────────────────────────────────────────────────────────────
// Haversine distance (km) — pure JS, no dependencies
// ─────────────────────────────────────────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─────────────────────────────────────────────────────────────────────────────
// Main trigger
// ─────────────────────────────────────────────────────────────────────────────
exports.notifyPartnersOnNewOrder = onDocumentWritten(
  {
    document: "orders/{orderId}",
    region: "asia-south1", // Mumbai — lowest latency for India
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    // Guard: only fire when status TRANSITIONS INTO 'searchingPartner'
    const wasSearching = before?.status === "searchingPartner";
    const isSearching  = after?.status  === "searchingPartner";

    if (!isSearching) return null;          // Not entering searchingPartner
    if (isSearching && wasSearching) return null; // No status change, skip

    const order   = after;
    const orderId = event.params.orderId;
    const pickupType = order.pickupType || "instant";

    logger.info(`📦 Order broadcast: ${orderId} | type=${pickupType}`);

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

    // Collect eligible FCM tokens with their Firestore doc refs (for stale-token cleanup)
    const validTokens = [];

    for (const doc of partnersSnap.docs) {
      const partner = doc.data();

      // Must have a non-empty FCM token
      const token = (partner.fcmToken || "").trim();
      if (!token) continue;

      // For INSTANT pickups: radius + category filter
      if (pickupType === "instant") {
        const pLat  = partner.currentLat  || partner.shopLat  || 0;
        const pLng  = partner.currentLng  || partner.shopLng  || 0;
        const maxKm = Math.min(partner.maxDistanceKm || 10, 30); // hard cap 30 km

        if (pLat === 0 && pLng === 0) continue; // No location data

        const dist = haversineKm(pLat, pLng, orderLat, orderLng);
        if (dist > maxKm) continue; // Outside radius

        // Scrap category match — partner must handle ≥1 order category
        const orderCats   = (order.scrapItems || []).map((i) =>
          (i.category || "").trim().toLowerCase()
        );
        const partnerCats = (partner.scrapCategories || []).map((c) =>
          (c || "").trim().toLowerCase()
        );

        if (orderCats.length > 0 && partnerCats.length > 0) {
          const hasMatch = orderCats.some((c) => partnerCats.includes(c));
          if (!hasMatch) continue;
        }
      }
      // SCHEDULED orders: Cloud Function auto-assigns; still send a heads-up
      // notification to the assigned partner (or all approved for awareness)

      validTokens.push({ token, docRef: doc.ref });
    }

    if (validTokens.length === 0) {
      logger.info("No eligible partner tokens found for this order.");
      return null;
    }

    logger.info(`🔔 Sending FCM to ${validTokens.length} partner(s) for order ${orderId}`);

    // ── 2. Build FCM payload ─────────────────────────────────────────────────
    const est = order.estimatedPayout
      ? `₹${Math.round(order.estimatedPayout)}`
      : "Check app";

    const area = order.areaName || order.customerAddress || "nearby";

    const title =
      pickupType === "instant"
        ? "🚨 New Pickup Request!"
        : "📅 Scheduled Pickup Available!";

    const body =
      pickupType === "instant"
        ? `${area} · Est. ${est} — Accept fast before someone else does!`
        : `${order.pickupSlot || ""} · ${area} · Est. ${est}`;

    // ── 3. Send in batches of 500 (FCM multicast limit) ──────────────────────
    const messaging  = getMessaging();
    const BATCH_SIZE = 500;
    const tokens     = validTokens.map((v) => v.token);

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE);

      try {
        const response = await messaging.sendEachForMulticast({
          tokens: batch,

          // Notification block — shown by OS when app is killed or backgrounded
          notification: { title, body },

          // Data block — read by the Flutter background/foreground handler
          data: {
            orderId,
            pickupType,
            type: "new_order",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },

          android: {
            priority: "high",
            notification: {
              channelId: "scrapwell_partner_channel",
              priority: "max",
              defaultSound: true,
              defaultVibrateTimings: true,
              notificationCount: 1,
              // Large icon (optional — falls back to app icon)
              icon: "ic_launcher",
            },
          },

          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                alert: { title, body },
                sound: "default",
                badge: 1,
                "content-available": 1, // wake app in background
              },
            },
          },
        });

        logger.info(
          `  Batch ${Math.floor(i / BATCH_SIZE) + 1}: ` +
            `${response.successCount} ok, ${response.failureCount} failed`
        );

        // ── 4. Clean up stale/invalid tokens ──────────────────────────────
        response.responses.forEach(async (r, idx) => {
          const STALE_CODES = [
            "messaging/registration-token-not-registered",
            "messaging/invalid-registration-token",
          ];
          if (!r.success && STALE_CODES.includes(r.error?.code)) {
            const staleToken = batch[idx];
            logger.warn(
              `Removing stale token: ${staleToken.substring(0, 20)}...`
            );
            // Find the corresponding doc ref and clear the token
            const match = validTokens.find((v) => v.token === staleToken);
            if (match) {
              await match.docRef.update({ fcmToken: null }).catch(() => {});
            }
          }
        });
      } catch (err) {
        logger.error("FCM multicast error:", err);
      }
    }

    return null;
  }
);
