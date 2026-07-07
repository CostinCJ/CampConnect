const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { generateOrgInviteCode } = require("./inviteCode");

/**
 * Shared guard for owner-only org management. Resolves the caller's org from
 * their users/{uid} profile and verifies they are its ownerUid.
 *
 * Returns { orgRef, orgId, uid }.
 * Throws:
 *   unauthenticated   — no auth context
 *   permission-denied ("not-org-owner") — caller isn't a guide with an org,
 *                       or isn't the owner of that org
 */
async function requireOwner(db, auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || user.role !== "guide" || !user.orgId) {
    throw new HttpsError("permission-denied", "not-org-owner");
  }

  const orgRef = db.doc(`organizations/${user.orgId}`);
  const org = await orgRef.get();
  if (!org.exists || org.data().ownerUid !== uid) {
    throw new HttpsError("permission-denied", "not-org-owner");
  }
  return { orgRef, orgId: user.orgId, uid };
}

/**
 * removeMemberHandler(db, authAdmin, auth, data)
 *
 * Owner-only: removes a guide from the caller's organisation. Deletes the
 * membership doc, clears orgId/campId on the ex-member's profile, and strips
 * the org from their custom claims so security-rule access ends on their next
 * token refresh. The removed guide keeps their account and can re-join any
 * org with a valid invite code.
 *
 * data: { memberUid }
 * Throws HttpsError:
 *   unauthenticated / permission-denied ("not-org-owner") — see requireOwner
 *   invalid-argument ("Missing memberUid.") — no target given
 *   invalid-argument ("cannot-remove-owner") — target is the owner themself
 *   not-found ("member-not-found") — target isn't a member of the caller's org
 */
async function removeMemberHandler(db, authAdmin, auth, data) {
  const { orgRef, uid } = await requireOwner(db, auth);

  const { memberUid } = data || {};
  if (!memberUid || typeof memberUid !== "string") {
    throw new HttpsError("invalid-argument", "Missing memberUid.");
  }
  if (memberUid === uid) {
    throw new HttpsError("invalid-argument", "cannot-remove-owner");
  }

  const memberRef = orgRef.collection("members").doc(memberUid);
  const member = await memberRef.get();
  if (!member.exists) {
    throw new HttpsError("not-found", "member-not-found");
  }

  await memberRef.delete();
  // Best-effort profile cleanup: the membership (authoritative) is already
  // gone; a missing users doc must not fail the call.
  await db.doc(`users/${memberUid}`).update({
    orgId: FieldValue.delete(),
    campId: FieldValue.delete(),
  }).catch(() => {});
  // Best-effort like the profile update: if the Auth user was deleted
  // out-of-band there are no claims left to strip and the removal has
  // effectively succeeded, so don't surface a spurious error to the owner.
  // Any other Auth failure still propagates.
  try {
    await authAdmin.setCustomUserClaims(memberUid, { role: "guide" });
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }

  return { ok: true };
}

/**
 * rotateInviteCodeHandler(db, auth)
 *
 * Owner-only: replaces the org's invite code with a fresh unique one. The old
 * code stops matching on registerGuide joins immediately; existing members
 * are unaffected.
 *
 * Throws HttpsError:
 *   unauthenticated / permission-denied ("not-org-owner") — see requireOwner
 */
async function rotateInviteCodeHandler(db, auth) {
  const { orgRef } = await requireOwner(db, auth);

  // Same uniqueness loop as registerGuide's org creation.
  let code;
  let clash;
  do {
    code = generateOrgInviteCode();
    clash = await db.collection("organizations")
      .where("inviteCode", "==", code).limit(1).get();
  } while (!clash.empty);

  await orgRef.update({ inviteCode: code });
  return { ok: true, inviteCode: code };
}

/**
 * joinOrganizationHandler(db, authAdmin, auth, data)
 *
 * Lets a signed-in guide who belongs to NO organisation (e.g. after being
 * removed via removeMember) join one with its invite code. Mirrors the
 * joinOrgCode branch of registerGuide, but for an existing account.
 *
 * data: { inviteCode }
 * Throws HttpsError:
 *   unauthenticated    — no auth context
 *   invalid-argument   ("Missing inviteCode.") — no/malformed code
 *   permission-denied  ("not-a-guide") — caller has no guide profile
 *   failed-precondition ("already-in-org") — caller already belongs to an org
 *   permission-denied  ("invalid-invite-code") — code matched no org
 */
async function joinOrganizationHandler(db, authAdmin, auth, data) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const { inviteCode } = data || {};
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new HttpsError("invalid-argument", "Missing inviteCode.");
  }

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || user.role !== "guide") {
    throw new HttpsError("permission-denied", "not-a-guide");
  }
  if (user.orgId) {
    throw new HttpsError("failed-precondition", "already-in-org");
  }

  const match = await db.collection("organizations")
    .where("inviteCode", "==", inviteCode.trim().toUpperCase())
    .limit(1).get();
  if (match.empty) {
    throw new HttpsError("permission-denied", "invalid-invite-code");
  }
  const orgId = match.docs[0].id;

  const batch = db.batch();
  batch.set(db.doc(`organizations/${orgId}/members/${uid}`), {
    role: "guide",
    displayName: user.displayName || "",
    joinedAt: FieldValue.serverTimestamp(),
  });
  batch.update(db.doc(`users/${uid}`), { orgId: orgId });
  await batch.commit();

  await authAdmin.setCustomUserClaims(uid, { role: "guide", orgId: orgId });
  return { ok: true, orgId: orgId };
}

module.exports = {
  removeMemberHandler,
  rotateInviteCodeHandler,
  joinOrganizationHandler,
};
