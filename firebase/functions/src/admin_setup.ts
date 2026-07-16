// firebase-functions v5 exports the 2nd-gen API at the package root; the
// 1st-gen builder used throughout this file (region().https.onCall, and
// the auth.user() trigger, which has no 2nd-gen equivalent) lives under
// the /v1 entrypoint. Importing the root here fails `tsc --noEmit` with
// ^5.0.0 (audit A1).
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const SUPER_ADMIN_EMAIL = "NajmAssistance@gmail.com";

// ─── Run once on deploy — sets super admin claim ──────────────────────────────
export const initSuperAdmin = functions
  .region("me-central1")
  .https.onRequest(async (req, res) => {
    // Only callable with internal token.
    // A5: fail CLOSED — if the env token is unset/empty, reject all requests
    // (previously `undefined !== undefined` was false, letting a header-less
    // request through when the deployment was misconfigured).
    const expected = process.env.ADMIN_SETUP_TOKEN;
    const token = req.headers["x-admin-setup-token"];
    if (!expected || token !== expected) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }

    try {
      const user = await admin.auth().getUserByEmail(SUPER_ADMIN_EMAIL);
      await admin.auth().setCustomUserClaims(user.uid, {
        superAdmin: true,
        admin: true,
        accountStatus: "approved",
        privileges: ["all"],
      });
      await admin.firestore().collection("adminUsers").doc(user.uid).set({
        email: SUPER_ADMIN_EMAIL,
        isSuperAdmin: true,
        privileges: ["all"],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.json({ success: true, message: `Super admin set for ${SUPER_ADMIN_EMAIL}` });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  });

// ─── Approve a user ───────────────────────────────────────────────────────────
export const approveUser = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin && !context.auth?.token?.privileges?.includes("approve_users")) {
      throw new functions.https.HttpsError("permission-denied", "Insufficient privileges");
    }

    const { userId, rankCode } = data;
    if (!userId) throw new functions.https.HttpsError("invalid-argument", "userId required");

    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) throw new functions.https.HttpsError("not-found", "User not found");

    const userData = userDoc.data()!;
    const rank = rankCode || userData.rankCode || "YCA";

    // F13: merge with existing claims — re-approving an admin (or a user who
    // was granted privileges/rankScope) must not wipe admin/superAdmin/
    // privileges. Mirrors the A3 pattern used in rejectUser/suspendUser.
    const approvedUser = await admin.auth().getUser(userId);
    await admin.auth().setCustomUserClaims(userId, {
      ...(approvedUser.customClaims || {}),
      accountStatus: "approved",
      rank: rank,
      tier: userData.subscriptionTier || "free",
    });

    // Update Firestore
    await db.collection("users").doc(userId).update({
      accountStatus: "approved",
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: context.auth?.uid,
    });

    // Remove from pending approvals
    const pending = await db.collection("pendingApprovals")
      .where("userId", "==", userId).get();
    pending.docs.forEach(d => d.ref.delete());

    // Notify user
    const notifData = {
      userId,
      type: "account_approved",
      title: "Account Approved ✅",
      titleAr: "تمت الموافقة على الحساب ✅",
      body: `Your ${rank} account has been approved. Welcome to Najm!`,
      bodyAr: `تمت الموافقة على حساب ${rank}. مرحباً بك في نجم!`,
      deepLink: "/home",
      read: false,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection("notifications").add(notifData);

    // Send FCM
    const tokens = await db.collection("fcmTokens")
      .where("userId", "==", userId).get();
    if (!tokens.empty) {
      const tokenList = tokens.docs.map(d => d.data().token as string);
      await admin.messaging().sendEachForMulticast({
        tokens: tokenList,
        notification: { title: notifData.title, body: notifData.body },
        data: { type: "account_approved", deepLink: "/home" },
      });
    }

    return { success: true, userId, rank };
  });

// ─── Reject a user ────────────────────────────────────────────────────────────
export const rejectUser = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin && !context.auth?.token?.privileges?.includes("approve_users")) {
      throw new functions.https.HttpsError("permission-denied", "Insufficient privileges");
    }

    const { userId, reason } = data;
    if (!userId) throw new functions.https.HttpsError("invalid-argument", "userId required");
    const db = admin.firestore();

    // A3: preserve existing claims; P1-1: revoke sessions immediately.
    const rejected = await admin.auth().getUser(userId);
    await admin.auth().setCustomUserClaims(userId, {
      ...(rejected.customClaims || {}),
      accountStatus: "rejected",
    });
    await admin.auth().revokeRefreshTokens(userId);

    await db.collection("users").doc(userId).update({
      accountStatus: "rejected",
      rejectionReason: reason || "Crew ID could not be verified",
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: context.auth?.uid,
    });

    await db.collection("notifications").add({
      userId,
      type: "account_rejected",
      title: "Account Not Approved",
      titleAr: "لم تتم الموافقة على الحساب",   // A6: real Arabic copy
      body: reason || "Your crew ID could not be verified. Contact support@cip.app",
      bodyAr: reason || "تعذّر التحقق من هوية الطاقم. يرجى التواصل مع الدعم support@cip.app",
      deepLink: "/disclaimer",
      read: false,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });

// ─── Suspend a user ───────────────────────────────────────────────────────────
export const suspendUser = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin && !context.auth?.token?.privileges?.includes("suspend_users")) {
      throw new functions.https.HttpsError("permission-denied", "Insufficient privileges");
    }

    const { userId, reason } = data;
    if (!userId) throw new functions.https.HttpsError("invalid-argument", "userId required");
    const db = admin.firestore();

    // A3: merge onto existing claims so rank/tier/privileges are NOT wiped.
    const suspended = await admin.auth().getUser(userId);
    await admin.auth().setCustomUserClaims(userId, {
      ...(suspended.customClaims || {}),
      accountStatus: "suspended",
    });
    // P1-1: force session revocation so the user loses access immediately
    // rather than after the ID token's ~1h natural expiry.
    await admin.auth().revokeRefreshTokens(userId);

    await db.collection("users").doc(userId).update({
      accountStatus: "suspended",
      suspensionReason: reason || "Account suspended by admin",
      suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
      suspendedBy: context.auth?.uid,
    });

    return { success: true };
  });

// ─── Reinstate (un-suspend) a user ────────────────────────────────────────────
// A4: suspension previously had no reversal path. Restores account access while
// preserving rank/tier/admin claims.
export const unsuspendUser = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin && !context.auth?.token?.privileges?.includes("suspend_users")) {
      throw new functions.https.HttpsError("permission-denied", "Insufficient privileges");
    }

    const { userId } = data;
    if (!userId) throw new functions.https.HttpsError("invalid-argument", "userId required");
    const db = admin.firestore();

    const user = await admin.auth().getUser(userId);
    await admin.auth().setCustomUserClaims(userId, {
      ...(user.customClaims || {}),
      accountStatus: "approved",
    });

    await db.collection("users").doc(userId).update({
      accountStatus: "approved",
      suspensionReason: admin.firestore.FieldValue.delete(),
      reinstatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reinstatedBy: context.auth?.uid,
    });

    return { success: true };
  });

// ─── Create limited admin ─────────────────────────────────────────────────────
export const createLimitedAdmin = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    // ONLY super admin can create other admins
    if (!context.auth?.token?.superAdmin) {
      throw new functions.https.HttpsError("permission-denied",
        "Only the super admin can create other admins");
    }

    const { email, privileges, rankScope } = data;
    // privileges: array of privilege strings
    // rankScope: array of ranks this admin can manage, or ['all']

    try {
      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().setCustomUserClaims(user.uid, {
        admin: true,
        superAdmin: false,
        accountStatus: "approved",
        privileges: privileges || [],
        rankScope: rankScope || [],
      });

      await admin.firestore().collection("adminUsers").doc(user.uid).set({
        email,
        isSuperAdmin: false,
        privileges: privileges || [],
        rankScope: rankScope || [],
        createdBy: context.auth?.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, email, privileges };
    } catch (e: any) {
      throw new functions.https.HttpsError("internal", e.message);
    }
  });

// ─── Revoke admin ─────────────────────────────────────────────────────────────
export const revokeAdmin = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin) {
      throw new functions.https.HttpsError("permission-denied",
        "Only the super admin can revoke admin access");
    }

    const { userId } = data;
    const db = admin.firestore();

    // Get user's current claims to preserve accountStatus and rank
    const user = await admin.auth().getUser(userId);
    const currentClaims = user.customClaims || {};

    await admin.auth().setCustomUserClaims(userId, {
      accountStatus: currentClaims.accountStatus || "approved",
      rank: currentClaims.rank,
      tier: currentClaims.tier,
      admin: false,
      superAdmin: false,
      privileges: [],
    });

    await db.collection("adminUsers").doc(userId).delete();

    return { success: true };
  });

// ─── Update admin privileges ──────────────────────────────────────────────────
export const updateAdminPrivileges = functions
  .region("me-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth?.token?.superAdmin) {
      throw new functions.https.HttpsError("permission-denied",
        "Only the super admin can update admin privileges");
    }

    const { userId, privileges, rankScope } = data;
    const db = admin.firestore();

    const user = await admin.auth().getUser(userId);
    const currentClaims = user.customClaims || {};

    await admin.auth().setCustomUserClaims(userId, {
      ...currentClaims,
      privileges: privileges || [],
      rankScope: rankScope || [],
    });

    await db.collection("adminUsers").doc(userId).update({
      privileges: privileges || [],
      rankScope: rankScope || [],
      updatedBy: context.auth?.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });

// ─── On new user created — auto-add to pending approvals ─────────────────────
export const onUserCreated = functions
  .region("me-central1")
  .auth.user()
  .onCreate(async (user) => {
    const db = admin.firestore();
    await db.collection("pendingApprovals").add({
      userId: user.uid,
      email: user.email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "pending",
    });

    // F14: notification is best-effort. Before initSuperAdmin has run,
    // getUserByEmail throws and previously aborted the whole trigger —
    // the pendingApprovals write above must never be at risk from this.
    try {
      const superAdminUser = await admin.auth().getUserByEmail(SUPER_ADMIN_EMAIL);
      const tokens = await db.collection("fcmTokens")
        .where("userId", "==", superAdminUser.uid).get();

      if (!tokens.empty) {
        const tokenList = tokens.docs.map(d => d.data().token as string);
        await admin.messaging().sendEachForMulticast({
          tokens: tokenList,
          notification: {
            title: "New Signup Pending Approval",
            body: `${user.email} has signed up and needs verification`,
          },
          data: { type: "new_signup", deepLink: "/admin/approvals" },
        });
      }
    } catch (e: any) {
      functions.logger.warn(
        `onUserCreated: could not notify super admin (${e?.message ?? e}). ` +
        "Pending approval was still recorded.");
    }
  });
