const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");

/**
 * Lets a signed-in guide delete their own account and, if they own the
 * organisation, its entire org (camps, top-level codes, locations, members).
 * A non-owner guide is just removed from the org's membership. Required by
 * Apple (in-app account deletion) and 2026 consent-revocation rules.
 */
async function deleteMyAccountHandler(db, authAdmin, auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;

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

  if (user && user.role === "guide" && user.orgId) {
    const org = await db.doc(`organizations/${user.orgId}`).get();
    if (org.exists && org.data().ownerUid === uid) {
      // Owner: delete the whole org — camps (+ subcollections), their
      // top-level codes, and the org doc itself (locations, members).
      const camps = await db.collection("camps")
        .where("orgId", "==", user.orgId).get();
      for (const camp of camps.docs) {
        await db.recursiveDelete(camp.ref);
        const codes = await db.collection("codes")
          .where("campId", "==", camp.id).get();
        const batch = db.batch();
        codes.forEach((d) => batch.delete(d.ref));
        await batch.commit();
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
