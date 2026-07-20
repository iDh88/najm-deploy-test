// firebase-functions v5 exports the 2nd-gen API at the package root; the
// 1st-gen builder used throughout this file (region().https.onCall, and
// the auth.user() trigger, which has no 2nd-gen equivalent) lives under
// the /v1 entrypoint. Importing the root here fails `tsc --noEmit` with
// ^5.0.0 (audit A1).
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {
  buildLegalityPayload,
  buildAiChatPayload,
  resolveSubscriptionsEnabled,
  resolveAiDailyLimit,
} from "./mapping";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

const PYTHON_SERVICE_URL = process.env.PYTHON_SERVICE_URL || "https://cip-python-service-xxxx.run.app";
const INTERNAL_SERVICE_TOKEN = process.env.INTERNAL_SERVICE_TOKEN || "";

// ─── Helper: shared runtime config (subscriptionConfig/main) ─────────────────
// F19/F20: the Python services read the master subscription switch from
// Firestore (subscription_engine/config_service.py). Functions previously read
// only env vars, so an admin flipping the switch changed one side of the
// system but not the other. Firestore is now the source of truth on both
// sides; env vars remain the fallback when the doc/field is absent.
let _cfgCache: { data: FirebaseFirestore.DocumentData | null; at: number } | null = null;
const _CFG_TTL_MS = 60_000;

async function getSharedConfig(): Promise<FirebaseFirestore.DocumentData | null> {
  const now = Date.now();
  if (_cfgCache && now - _cfgCache.at < _CFG_TTL_MS) return _cfgCache.data;
  try {
    const snap = await db.collection("subscriptionConfig").doc("main").get();
    _cfgCache = { data: snap.exists ? snap.data() ?? null : null, at: now };
  } catch (e: any) {
    functions.logger.warn(`getSharedConfig failed, using env fallback: ${e?.message ?? e}`);
    _cfgCache = { data: null, at: now };
  }
  return _cfgCache.data;
}

async function subscriptionsEnabled(): Promise<boolean> {
  const cfg = await getSharedConfig();
  return resolveSubscriptionsEnabled(
    cfg?.subscriptionsEnabled, process.env.SUBSCRIPTIONS_ENABLED);
}

async function aiDailyFreeLimit(): Promise<number> {
  const cfg = await getSharedConfig();
  return resolveAiDailyLimit(
    cfg?.aiDailyFreeLimit, process.env.AI_DAILY_FREE_LIMIT);
}

// ─── Helper: call Python microservice ────────────────────────────────────────
async function callPythonService(path: string, data: object): Promise<any> {
  const response = await axios.post(`${PYTHON_SERVICE_URL}${path}`, data, {
    headers: {
      "Content-Type": "application/json",
      "X-Service-Token": INTERNAL_SERVICE_TOKEN,
    },
    timeout: 60000,
  });
  return response.data;
}

// ─── Helper: send push notification ──────────────────────────────────────────
async function sendNotification(
  userId: string,
  title: string,
  titleAr: string,
  body: string,
  bodyAr: string,
  deepLink: string,
  type: string
): Promise<void> {
  // Get user's FCM token
  const userDoc = await db.collection("users").doc(userId).get();
  const userData = userDoc.data();
  const fcmToken = userData?.fcmToken;
  const locale = userData?.locale || "ar";

  // Save to notifications collection
  await db.collection("notifications").add({
    userId,
    type,
    title,
    titleAr,
    body,
    bodyAr,
    deepLink,
    read: false,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send push if token available
  if (fcmToken) {
    const displayTitle = locale === "ar" ? titleAr : title;
    const displayBody = locale === "ar" ? bodyAr : body;
    await messaging.send({
      token: fcmToken,
      notification: { title: displayTitle, body: displayBody },
      data: { deepLink, type },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: On Excel file upload → trigger parser
// ═══════════════════════════════════════════════════════════════════════════
export const onRosterUpload = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .storage.object()
  .onFinalize(async (object) => {
    const filePath = object.name || "";

    // Only process files in users/{userId}/rosters/ path
    if (!filePath.match(/^users\/[^/]+\/rosters\/.+\.xlsx$/)) return;

    const pathParts = filePath.split("/");
    const userId = pathParts[1];

    // Extract month from filename (expects YYYY-MM.xlsx)
    const filename = pathParts[pathParts.length - 1];
    const monthMatch = filename.match(/(\d{4}-\d{2})/);
    const month = monthMatch ? monthMatch[1] : new Date().toISOString().slice(0, 7);

    functions.logger.info(`Parsing roster for user ${userId}, month ${month}`);

    try {
      const result = await callPythonService("/v1/parser/parse", {
        userId,
        month,
        storageRef: filePath,
      });

      functions.logger.info(`Parsed ${result.linesProcessed} lines for ${userId}`);

      await sendNotification(
        userId,
        "Roster Parsed Successfully",
        "تم تحليل جدول الرحلات",
        `${result.linesProcessed} flight lines ready to view`,
        `تم تحليل ${result.linesProcessed} خطوط طيران`,
        "/lines",
        "roster_parsed"
      );
    } catch (error) {
      functions.logger.error("Parser failed:", error);
      await sendNotification(
        userId,
        "Roster Parse Failed",
        "فشل تحليل جدول الرحلات",
        "We could not process your Excel file. Please check the format.",
        "لم نتمكن من معالجة ملف Excel. يرجى التحقق من التنسيق.",
        "/lines",
        "roster_error"
      );
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: On bid created → run legality check + notify
// ═══════════════════════════════════════════════════════════════════════════
export const onBidCreated = functions.firestore
  .document("bids/{bidId}")
  .onCreate(async (snap, context) => {
    const bid = snap.data();
    const bidId = context.params.bidId;

    functions.logger.info(`New bid ${bidId} by user ${bid.userId}`);

    // Log behavior event
    await db.collection("behaviorEvents").add({
      userId: bid.userId,
      eventType: "bid_submitted",
      metadata: {
        bidId,
        lineId: bid.lineId,
        lineNumber: bid.lineNumber,
        month: bid.month,
        priority: bid.priority,
        isAutoBid: bid.isAutoBid || false,
        userMode: bid.userMode,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: On bid status update → notify user
// ═══════════════════════════════════════════════════════════════════════════
export const onBidStatusChanged = functions.firestore
  .document("bids/{bidId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    const userId = after.userId;
    const lineNumber = after.lineNumber;

    if (after.status === "awarded") {
      await sendNotification(
        userId,
        "Bid Awarded! 🎉",
        "تهانينا! تم منح عطاءك 🎉",
        `You were awarded Line ${lineNumber} for ${after.month}`,
        `تم منحك الخط ${lineNumber} لشهر ${after.month}`,
        `/lines/${after.lineId}`,
        "bid_awarded"
      );

      // Log outcome for ML training
      await db.collection("behaviorEvents").add({
        userId,
        eventType: "bid_outcome",
        metadata: { bidId: context.params.bidId, lineId: after.lineId, awarded: true, month: after.month },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (after.status === "rejected") {
      await sendNotification(
        userId,
        "Bid Not Awarded",
        "لم يتم منح العطاء",
        `Line ${lineNumber} was not awarded this month`,
        `لم يتم منح الخط ${lineNumber} هذا الشهر`,
        "/bids",
        "bid_rejected"
      );

      await db.collection("behaviorEvents").add({
        userId,
        eventType: "bid_outcome",
        metadata: { bidId: context.params.bidId, lineId: after.lineId, awarded: false, month: after.month },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// TRIGGER: On trade status update → notify both parties
// ═══════════════════════════════════════════════════════════════════════════
export const onTradeStatusChanged = functions.firestore
  .document("trades/{tradeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    const tradeId = context.params.tradeId;
    const offeredFlight = after.offeredLeg?.flightNumber || "Unknown";

    if (after.status === "matched" || after.status === "pendingConfirm") {
      // Notify initiator someone is interested
      if (after.receiverId && after.receiverId !== after.initiatorId) {
        await sendNotification(
          after.initiatorId,
          "Trade Match Found!",
          "تم العثور على تطابق للمبادلة!",
          `Someone wants to trade ${offeredFlight} with you`,
          `شخص ما يريد مبادلة رحلة ${offeredFlight} معك`,
          `/trades/${tradeId}`,
          "trade_matched"
        );
      }
    } else if (after.status === "confirmed") {
      // Notify both parties
      for (const uid of [after.initiatorId, after.receiverId].filter(Boolean)) {
        await sendNotification(
          uid,
          "Trade Confirmed ✓",
          "تم تأكيد المبادلة ✓",
          `Trade for flight ${offeredFlight} has been confirmed`,
          `تم تأكيد مبادلة رحلة ${offeredFlight}`,
          `/trades/${tradeId}`,
          "trade_confirmed"
        );
      }
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// HTTP: Legality check endpoint (called by Flutter before bid/trade)
// ═══════════════════════════════════════════════════════════════════════════
export const checkLegality = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }

    // F16: the Python endpoint (legality/engine.py LegalityCheckRequest)
    // expects { crew_schedule: DutyPeriod[], proposed_duty?: DutyPeriod }.
    // The previous payload ({ schedule, proposedChange, changeType }) failed
    // pydantic validation with a 422 on every call. Mapping lives in
    // src/mapping.ts (buildLegalityPayload) and is pinned by unit tests.
    const mapped = buildLegalityPayload(data);
    if (!mapped.ok) {
      throw new functions.https.HttpsError("invalid-argument", mapped.error);
    }

    try {
      const result = await callPythonService("/v1/legality/check", mapped.value);
      return result;
    } catch (error: any) {
      functions.logger.error("Legality check failed:", error);
      throw new functions.https.HttpsError("internal", "Legality check failed");
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// HTTP: AI assistant endpoint
// ═══════════════════════════════════════════════════════════════════════════
export const aiAssistant = functions
  .runWith({ timeoutSeconds: 60, memory: "256MB" })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }

    const userId = context.auth.uid;

    // Rate limit check
    const userDoc = await db.collection("users").doc(userId).get();
    // 0.3 — single source of entitlement. Subscriptions launch DISABLED, so every
    // user gets the free allowance. When subscriptions are enabled, source this
    // limit from the feature-gate (userSubscriptions), not a constant.
    // F20: limit sourced from subscriptionConfig/main.aiDailyFreeLimit when
    // set (admin-adjustable), env AI_DAILY_FREE_LIMIT otherwise.
    const dailyLimit = await aiDailyFreeLimit();

    const today = new Date().toISOString().slice(0, 10);
    const usageRef = db.collection("aiUsage").doc(`${userId}_${today}`);
    const usageDoc = await usageRef.get();
    const currentUsage = usageDoc.exists ? (usageDoc.data()?.count || 0) : 0;

    if (currentUsage >= dailyLimit) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Daily AI query limit (${dailyLimit}) reached. Upgrade to PRO for unlimited queries.`
      );
    }

    try {
      // F17: ChatRequest (ai/nlp_router.py) expects snake_case user_id and
      // reads userMode from the context dict — top-level locale/userMode were
      // silently dropped, and camelCase userId 422'd every call. Mapping
      // lives in src/mapping.ts (buildAiChatPayload), pinned by unit tests.
      const result = await callPythonService(
        "/v1/ai/chat",
        buildAiChatPayload(userId, data, userDoc.data() ?? null),
      );

      // Increment usage counter
      await usageRef.set({ count: currentUsage + 1, date: today }, { merge: true });

      // Save to session
      if (data.sessionId) {
        await db.collection("aiSessions").doc(data.sessionId).update({
          messages: admin.firestore.FieldValue.arrayUnion(
            { role: "user", content: data.message, timestamp: new Date() },
            // ChatResponse returns snake_case intent_type.
            { role: "assistant", content: result.text, intentType: result.intent_type ?? null, timestamp: new Date() }
          ),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return result;
    } catch (error: any) {
      functions.logger.error("AI assistant failed:", error);
      throw new functions.https.HttpsError("internal", "AI assistant unavailable");
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// HTTP: Auto-bid suggestions (triggered 72h before bid window)
// ═══════════════════════════════════════════════════════════════════════════
export const triggerAutoBidSuggestions = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .pubsub.schedule("0 9 * * *")  // 9am daily — check if 72h before bid window
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    functions.logger.info("Running auto-bid suggestion job");

    // 0.3 — auto-bid is a PRO feature. Subscriptions launch DISABLED, so this job
    // is a no-op until enabled. When enabling, replace the legacy `subscriptionTier`
    // query below with an entitlement lookup against userSubscriptions.
    // F19: master switch read from subscriptionConfig/main (env fallback) so
    // the admin panel toggle governs Functions and Python consistently.
    if (!(await subscriptionsEnabled())) {
      functions.logger.info("Subscriptions disabled — skipping auto-bid job");
      return;
    }

    // Get all PRO+ users
    const usersSnap = await db.collection("users")
      .where("subscriptionTier", "in", ["pro", "elite", "enterprise"])
      .get();

    const currentMonth = new Date().toISOString().slice(0, 7);

    const promises = usersSnap.docs.map(async (userDoc) => {
      const user = userDoc.data();
      const userId = userDoc.id;

      try {
        // Get available lines for this month
        const linesSnap = await db.collection("flightLines")
          .where("month", "==", currentMonth)
          .get();
        const lineIds = linesSnap.docs.map((d) => d.id);

        if (lineIds.length === 0) return;

        const result = await callPythonService("/v1/auto-bid/suggest", {
          userId,
          month: currentMonth,
          userMode: user.userMode || "balanced",
          availableLineIds: lineIds,
          autoSubmit: user.subscriptionTier === "elite" && user.autoSubmitEnabled === true,
        });

        if (result.suggestions?.length > 0) {
          await sendNotification(
            userId,
            "Your Bid Suggestions Are Ready ⭐",
            "اقتراحات عطاءاتك جاهزة ⭐",
            `Najm ranked ${result.suggestions.length} lines for you this month`,
            `نجم رتّب ${result.suggestions.length} خطوط لك هذا الشهر`,
            "/bids",
            "auto_bid_ready"
          );
        }
      } catch (error) {
        functions.logger.error(`Auto-bid failed for user ${userId}:`, error);
      }
    });

    await Promise.allSettled(promises);
    functions.logger.info(`Auto-bid suggestions sent to ${usersSnap.size} users`);
  });

// ═══════════════════════════════════════════════════════════════════════════
// HTTP: Account deletion pipeline (PDPL compliance)
// ═══════════════════════════════════════════════════════════════════════════
export const processAccountDeletion = functions.firestore
  .document("deletionRequests/{requestId}")
  .onCreate(async (snap) => {
    const { userId } = snap.data();
    functions.logger.info(`Processing deletion request for user ${userId}`);
    const FieldValue = admin.firestore.FieldValue;

    // Chunked deletion (Firestore batch limit is 500; use 400 for headroom).
    // Idempotent: safe to re-run if the function retries after a partial failure.
    const deleteQuery = async (query: FirebaseFirestore.Query): Promise<void> => {
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const page = await query.limit(400).get();
        if (page.empty) break;
        const b = db.batch();
        page.docs.forEach((d) => b.delete(d.ref));
        await b.commit();
        if (page.size < 400) break;
      }
    };

    try {
      await snap.ref.update({ status: "processing", startedAt: FieldValue.serverTimestamp() });

      // ── Per-user collections keyed by a `userId` field (single source of truth).
      //    NOTE: field name confirmed for bids/notifications/aiSessions/tradeContacts/
      //    likes/saves/ratings/monthly_lines; inferred for behaviorEvents/subscriptionEvents/
      //    uploads/flightLines — reconcile against the data model. A wrong field only
      //    under-deletes (query returns empty), it does not error.
      const byUserIdField = [
        "bids", "notifications", "aiSessions", "behaviorEvents", "monthly_lines",
        "subscriptionEvents", "uploads", "flightLines",
        "userLikes", "userSaves", "userRatings", "tradeContacts",
      ];
      for (const col of byUserIdField) {
        await deleteQuery(db.collection(col).where("userId", "==", userId));
      }

      // ── Collections whose document id IS the userId.
      for (const col of ["userSubscriptions", "userReferralStatus", "fcmTokens"]) {
        await db.collection(col).doc(userId).delete().catch(() => undefined);
      }

      // ── Collections whose doc id is prefixed `${userId}_...`.
      for (const col of ["usageCounters", "aiUsage"]) {
        await deleteQuery(
          db.collection(col)
            .orderBy(admin.firestore.FieldPath.documentId())
            .startAt(`${userId}_`)
            .endAt(`${userId}_\uf8ff`)
        );
      }

      // ── Shared records: cancel the user's OPEN trades but preserve the
      //    counterparty's data (do not hard-delete a two-party trade).
      for (const field of ["initiatorId", "receiverId"]) {
        const trades = await db.collection("trades").where(field, "==", userId).get();
        if (trades.empty) continue;
        const b = db.batch();
        trades.forEach((d) => {
          const st = d.data().status;
          if (st === "open" || st === "matched") b.update(d.ref, { status: "cancelled" });
        });
        await b.commit();
      }

      // ── Delete the user document itself.
      await db.collection("users").doc(userId).delete().catch(() => undefined);

      // ── Delete Storage objects under the user's prefix (roster PDFs, etc.).
      try {
        await admin.storage().bucket().deleteFiles({ prefix: `users/${userId}/` });
      } catch (e) {
        functions.logger.warn(`Storage cleanup for ${userId} failed: ${e}`);
      }

      await snap.ref.update({ status: "data_deleted", dataDeletedAt: FieldValue.serverTimestamp() });

      // ── Delete the Firebase Auth account LAST, after data is gone.
      await admin.auth().deleteUser(userId).catch((e) => {
        functions.logger.warn(`Auth deletion for ${userId}: ${e}`);
      });

      await snap.ref.update({ status: "completed", completedAt: FieldValue.serverTimestamp() });
      functions.logger.info(`Deletion complete for user ${userId}`);
    } catch (err) {
      functions.logger.error(`Deletion failed for ${userId}: ${err}`);
      await snap.ref.update({ status: "failed", error: String(err), failedAt: FieldValue.serverTimestamp() });
      throw err; // allow the Functions retry policy to re-run; deletion is idempotent
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// Payments: stripeWebhook removed (0.3) — legacy Stripe is not in the roadmap.
// See plans/legacy-payments-analysis.md. Future billing = Apple IAP + Google
// Play Billing, synced via RevenueCat, wired through userSubscriptions.
// ═══════════════════════════════════════════════════════════════════════════

// ─── Admin Management Functions ───────────────────────────────────────────────
export {
  initSuperAdmin,
  approveUser,
  rejectUser,
  suspendUser,
  unsuspendUser,
  createLimitedAdmin,
  revokeAdmin,
  updateAdminPrivileges,
  onUserCreated,
} from "./admin_setup";

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 2 — PDF Intelligence Engine
// ─────────────────────────────────────────────────────────────────────────────

/** Notify crew when PDF analysis completes */
export const onIntelligenceUploadComplete = functions.firestore
  .document("uploads/{uploadId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status === after.status) return;

    const userId = after.userId as string;
    const tokenDoc = await db.collection("fcmTokens")
      .where("userId", "==", userId)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (tokenDoc.empty) return;
    const token = tokenDoc.docs[0].data().token as string;

    if (after.status === "complete") {
      await messaging.send({
        token,
        notification: {
          title: "Schedule Analysis Ready 📊",
          body:  "Your PDF has been processed. Tap to view your intelligence report.",
        },
        data: { lineId: after.lineId ?? "", screen: "/intelligence/lines" },
      });
    }

    if (after.status === "failed") {
      await messaging.send({
        token,
        notification: {
          title: "Analysis Failed ⚠️",
          body:  "Could not process your schedule PDF. Please try again.",
        },
        data: { screen: "/intelligence/upload" },
      });
    }
  });

/** Update user stats when a monthly_line is created */
export const onMonthlyLineCreated = functions.firestore
  .document("monthly_lines/{lineId}")
  .onCreate(async (snap) => {
    const data   = snap.data();
    const userId = data.userId as string;
    if (!userId) return;
    await db.collection("users").doc(userId).update({
      totalMonthsAnalyzed: admin.firestore.FieldValue.increment(1),
      lastActiveAt:        admin.firestore.FieldValue.serverTimestamp(),
    });
  });


// ─────────────────────────────────────────────────────────────────────────────
// PHASE 3 — Layover Intelligence
// ─────────────────────────────────────────────────────────────────────────────

/** Notify submitter when their recommendation is approved */
export const onRecommendationApproved = functions.firestore
  .document("recommendations/{recId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.isApproved || !after.isApproved) return;

    const tokenDoc = await db.collection("fcmTokens")
      .where("userId", "==", after.submittedBy)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (tokenDoc.empty) return;

    await messaging.send({
      token: tokenDoc.docs[0].data().token as string,
      notification: {
        title: "Recommendation Approved ✅",
        body:  `"${after.name}" is now live in the Layover hub.`,
      },
      data: { screen: `/layover/${after.cityId}` },
    });
  });


// ─────────────────────────────────────────────────────────────────────────────
// TRADE RECOMMENDATION ENGINE
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Weekly profile rebuild — triggered every Monday 03:00 AST.
 * Calls the Python service to rebuild all active crew preference profiles.
 */
export const weeklyProfileRebuild = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub
  .schedule("every monday 03:00")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    // P2/T2: page through ALL approved users (the old .limit(500) silently
    // skipped everyone past the first 500) and rebuild with bounded
    // concurrency so we don't overwhelm the Python service. For very large
    // user bases this should fan out to Cloud Tasks to stay under the timeout.
    const PAGE = 300;        // Firestore page size
    const CONCURRENCY = 10;  // parallel rebuild calls per chunk
    let rebuilt = 0, scanned = 0;
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      let q = db.collection("users")
        .where("accountStatus", "==", "approved")
        .select()
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(PAGE);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      scanned += page.size;

      for (let i = 0; i < page.docs.length; i += CONCURRENCY) {
        const chunk = page.docs.slice(i, i + CONCURRENCY);
        const results = await Promise.allSettled(
          chunk.map((doc) => callPythonService(`/v1/trade/profile/${doc.id}/rebuild`, {}))
        );
        results.forEach((r, idx) => {
          if (r.status === "fulfilled") rebuilt++;
          else functions.logger.warn(`Rebuild ${chunk[idx].id}: ${r.reason}`);
        });
      }

      last = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
    functions.logger.info(`Weekly rebuild: ${rebuilt}/${scanned} profiles`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// OPERATIONAL KNOWLEDGE MANAGEMENT SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

/** Notify admins when a document version finishes processing */
export const onDocumentVersionProcessed = functions.firestore
  .document("documentVersions/{versionId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.status === after.status) return;
    if (after.status !== "ACTIVE" && after.status !== "FAILED") return;

    const tokenSnap = await db.collection("fcmTokens")
      .where("userId", "==", after.uploadedBy)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (tokenSnap.empty) return;

    const docSnap = await db.collection("knowledgeDocuments")
      .doc(after.documentId).get();
    const docName = docSnap.exists ? docSnap.data()?.name : "Document";

    if (after.status === "ACTIVE") {
      await messaging.send({
        token: tokenSnap.docs[0].data().token as string,
        notification: {
          title: "Document Indexed ✅",
          body: `"${docName}" Rev ${after.versionNumber} is now live in the knowledge base.`,
        },
        data: { screen: `/admin/knowledge/${after.documentId}` },
      });
    } else {
      await messaging.send({
        token: tokenSnap.docs[0].data().token as string,
        notification: {
          title: "Document Processing Failed ⚠️",
          body: `"${docName}" Rev ${after.versionNumber} failed to process: ${after.processingError ?? "Unknown error"}`,
        },
        data: { screen: `/admin/knowledge/${after.documentId}` },
      });
    }
  });

/** Notify admins with a privilege when a change summary flags legality/fatigue impact */
export const onChangeSummaryGenerated = functions.firestore
  .document("documentChangeSummaries/{summaryId}")
  .onCreate(async (snap) => {
    const summary = snap.data();
    const items = summary.items ?? [];
    const hasImpact = items.some((i: any) =>
      i.category === "legality_change" || i.category === "fatigue_change");
    if (!hasImpact) return;

    const adminsSnap = await db.collection("adminUsers")
      .where("privileges", "array-contains", "manage_knowledge_base")
      .get();

    // P2/T2: parallelize the per-admin token lookups (was N sequential
    // round-trips). Also avoids shadowing the `admin` SDK import.
    const tokens: string[] = [];
    const tokenSnaps = await Promise.all(
      adminsSnap.docs.map((a) =>
        db.collection("fcmTokens")
          .where("userId", "==", a.id)
          .orderBy("updatedAt", "desc")
          .limit(1)
          .get()
      )
    );
    for (const t of tokenSnaps) {
      if (!t.empty) tokens.push(t.docs[0].data().token as string);
    }

    if (tokens.length > 0) {
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "Legality/Fatigue Rule Change Detected ⚖️",
          body: summary.overallSummary ?? "Review the change summary in Knowledge Center.",
        },
        data: { screen: `/admin/knowledge/${summary.documentId}` },
      });
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// SUBSCRIPTION SYSTEM
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Dispatches push notifications for subscription-related events
 * (trial ending soon, subscription expiring soon, referral rewards,
 * bonus days granted, promo activated). The Python notification_triggers
 * module writes the notification document; this function delivers it.
 */
export const onSubscriptionNotificationCreated = functions.firestore
  .document("notifications/{notifId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const subscriptionTypes = [
      "TRIAL_ENDING_SOON",
      "SUBSCRIPTION_EXPIRING_SOON",
      "REFERRAL_REWARD_GRANTED",
      "BONUS_DAYS_GRANTED",
      "PROMO_ACTIVATED",
    ];
    if (!subscriptionTypes.includes(data.type)) return;

    const tokenSnap = await db.collection("fcmTokens")
      .where("userId", "==", data.userId)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (tokenSnap.empty) return;

    await messaging.send({
      token: tokenSnap.docs[0].data().token as string,
      notification: {
        title: data.title,
        body: data.body,
      },
      data: {
        screen: "/subscription/account-history",
        notificationType: data.type,
      },
    });

    await snap.ref.update({ dispatchedAt: admin.firestore.FieldValue.serverTimestamp() });
  });

/**
 * Daily check for trials/subscriptions ending soon.
 * Calls the Python subscription_engine notification_triggers module,
 * which writes notification docs that onSubscriptionNotificationCreated
 * then delivers as push.
 */
export const dailySubscriptionExpiryCheck = functions.pubsub
  .schedule("every day 09:00")
  .timeZone("Asia/Riyadh")
  .onRun(async () => {
    try {
      const result = await callPythonService("/v1/subscription/admin/run-expiry-checks", {});
      functions.logger.info("Subscription expiry check complete", result);
    } catch (e: any) {
      functions.logger.error("Subscription expiry check failed:", e.message);
    }
  });

/** Notify a user immediately when an admin grants bonus Pro days */
export const onBonusDaysGranted = functions.firestore
  .document("subscriptionEvents/{eventId}")
  .onCreate(async (snap) => {
    const event = snap.data();
    if (event.eventType !== "ADMIN_GRANTED_DAYS" &&
        event.eventType !== "REFERRAL_REWARD_GRANTED" &&
        event.eventType !== "PROMO_ACTIVATED") {
      return;
    }

    const tokenSnap = await db.collection("fcmTokens")
      .where("userId", "==", event.userId)
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();
    if (tokenSnap.empty) return;

    const title = event.eventType === "REFERRAL_REWARD_GRANTED"
      ? "Referral Reward Earned 🎉"
      : event.eventType === "PROMO_ACTIVATED"
        ? "Promotional Access Activated 🎁"
        : "Bonus Pro Days Granted ✨";

    await messaging.send({
      token: tokenSnap.docs[0].data().token as string,
      notification: { title, body: event.description as string },
      data: { screen: "/subscription/account-history" },
    });
  });
