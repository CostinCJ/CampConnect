const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { deleteCampCascade } = require("./deleteCampCascade");

/**
 * Lets a signed-in guide delete their own account and, if they own the
 * organisation, its entire org (camps, top-level codes, locations, members).
 * A non-owner guide is just removed from the org's membership. Required by
 * Apple (in-app account deletion) and 2026 consent-revocation rules.
 *
 * Guard: an owner may NOT delete their account while other guides are still
 * members of the org — doing so would silently destroy camps and data created
 * by those other guides and leave them holding custom claims that point at a
 * now-deleted org. They must be removed (or ownership transferred) first.
 *
 * `bucket` is optional (a Storage bucket handle from getStorage().bucket()).
 * When provided, the owner-cascade also deletes each camp's Storage photos
 * and the org's location photos, alongside the Firestore documents. Existing
 * callers that omit `bucket` keep working unchanged — the Storage steps are
 * simply skipped.
 *
 * Throws HttpsError with one of:
 *   unauthenticated     — no auth context
 *   failed-precondition ("org-has-members") — owner with other members remaining
 */
async function deleteMyAccountHandler(db, authAdmin, auth, bucket) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;

  // Resolve the user's org up front (if any) so the owner guard can run BEFORE
  // any mutation — we must not release codes or delete anything if the call is
  // going to be rejected.
  let org = null;
  const isGuideWithOrg = user && user.role === "guide" && user.orgId;
  if (isGuideWithOrg) {
    org = await db.doc(`organizations/${user.orgId}`).get();
    if (org.exists && org.data().ownerUid === uid) {
      const members = await org.ref.collection("members").get();
      if (members.docs.some((m) => m.id !== uid)) {
        throw new HttpsError("failed-precondition", "org-has-members");
      }
    }
  }

  // Free any camp code this user claimed so it can be re-issued. (Kids claim a
  // code via claimCampCode, which stamps used/usedBy; deleting the account must
  // release it.)
  const claimed = await db.collection("codes").where("usedBy", "==", uid).get();
  if (!claimed.empty) {
    const batch = db.batch();
    claimed.forEach((d) =>
      batch.update(d.ref, { used: false, usedBy: FieldValue.delete() }));
    await batch.commit();
  }

  if (isGuideWithOrg) {
    if (org.exists && org.data().ownerUid === uid) {
      // Sole owner (guard above guarantees no other members): delete the whole
      // org — camps (+ subcollections + Storage), their top-level codes, and
      // the org doc itself (locations, members).
      const camps = await db.collection("camps")
        .where("orgId", "==", user.orgId).get();
      for (const camp of camps.docs) {
        await deleteCampCascade(db, camp.ref, camp.id, bucket);
      }
      // Same crash-safety reasoning as deleteCampCascade: delete the org's
      // location photos before the org doc itself.
      if (bucket) {
        await bucket.deleteFiles({ prefix: `organizations/${user.orgId}/locations/` });
      }
      await db.recursiveDelete(org.ref);
    } else {
      // Non-owner guide: just remove membership.
      await db.doc(`organizations/${user.orgId}/members/${uid}`).delete().catch(() => {});
    }
  }

  await db.doc(`users/${uid}`).delete().catch(() => {});
  await authAdmin.deleteUser(uid);
  return { deleted: true };
}

module.exports = { deleteMyAccountHandler };
