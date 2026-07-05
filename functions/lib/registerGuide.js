const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { generateOrgInviteCode } = require("./inviteCode");
const { checkRateLimit } = require("./rateLimiter");

/**
 * Registers a guide server-side and attaches them to an organisation:
 *  - newOrgName set  -> creates a new org (caller becomes owner) with a fresh invite code
 *  - joinOrgCode set -> joins the org whose inviteCode matches
 * Creates the Auth user, the users/{uid} profile, the org membership, and sets
 * custom claims { role: 'guide', orgId } BEFORE returning, so the client's
 * first sign-in token already carries them.
 */
async function registerGuideHandler(db, authAdmin, data, callerIp) {
  // Unauthenticated endpoint (no request.auth yet) — key the rate limit by
  // caller IP instead of a uid. Defense-in-depth behind App Check: this also
  // limits a compromised-but-genuine client replaying a real App Check token.
  const ip = callerIp || "unknown";
  const allowed = await checkRateLimit(db, `registerGuide:${ip}`);
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "too-many-attempts");
  }

  const { email, password, displayName, newOrgName, joinOrgCode } =
    data || {};
  if (!email || !password || !displayName || (!newOrgName && !joinOrgCode)) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  // Resolve or create the organisation FIRST (fail before creating the user).
  let orgId;
  let pendingOrg;
  if (newOrgName) {
    // Unique invite code.
    let code;
    let clash;
    do {
      code = generateOrgInviteCode();
      clash = await db.collection("organizations")
        .where("inviteCode", "==", code).limit(1).get();
    } while (!clash.empty);
    const orgRef = db.collection("organizations").doc();
    orgId = orgRef.id;
    // Org + owner membership are written after the user exists (below).
    pendingOrg = { orgRef, name: newOrgName.trim(), inviteCode: code };
  } else {
    const match = await db.collection("organizations")
      .where("inviteCode", "==", joinOrgCode.trim().toUpperCase())
      .limit(1).get();
    if (match.empty) {
      throw new HttpsError("permission-denied", "invalid-invite-code");
    }
    orgId = match.docs[0].id;
  }

  let userRecord;
  try {
    userRecord = await authAdmin.createUser({ email, password, displayName });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "email-already-in-use");
    }
    if (e.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "weak-password");
    }
    throw new HttpsError("internal", "auth-create-failed");
  }
  const uid = userRecord.uid;

  const batch = db.batch();
  if (pendingOrg) {
    batch.set(pendingOrg.orgRef, {
      name: pendingOrg.name,
      ownerUid: uid,
      inviteCode: pendingOrg.inviteCode,
    });
    batch.set(pendingOrg.orgRef.collection("members").doc(uid), {
      role: "owner",
      displayName: displayName,
    });
  } else {
    batch.set(
      db.doc(`organizations/${orgId}/members/${uid}`),
      { role: "guide", displayName: displayName });
  }
  batch.set(db.doc(`users/${uid}`), {
    role: "guide",
    email: email,
    displayName: displayName,
    orgId: orgId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  // Claims BEFORE the client signs in -> first token already carries them.
  await authAdmin.setCustomUserClaims(uid, { role: "guide", orgId: orgId });

  return { ok: true, orgId: orgId };
}

module.exports = { registerGuideHandler };
