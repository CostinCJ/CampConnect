const { HttpsError } = require("firebase-functions/v2/https");
const { deleteCampCascade } = require("./deleteCampCascade");

/**
 * deleteCampHandler(db, auth, data, bucket)
 *
 * Deletes a single camp on demand for a guide of the camp's own organisation,
 * cascading to its Storage photos, all Firestore subcollections, and its
 * top-level codes (via the shared deleteCampCascade). Replaces the old
 * client-side CampRepository.deleteCampSession, which deleted only the legacy
 * per-camp `codes` subcollection (empty since codes moved top-level) and left
 * both the real top-level codes AND every Storage photo orphaned forever.
 *
 * data: { campId }
 *
 * Throws HttpsError with one of:
 *   unauthenticated     — no auth context
 *   permission-denied   ("guides-only")  — caller isn't a guide
 *   invalid-argument    ("missing-campId") — no campId supplied
 *   permission-denied   ("wrong-org")    — camp belongs to another org
 *
 * Deleting an already-gone camp is a no-op success (idempotent), so a retried
 * call after a partial failure still resolves cleanly.
 */
async function deleteCampHandler(db, auth, data, bucket) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!auth.token || auth.token.role !== "guide") {
    throw new HttpsError("permission-denied", "guides-only");
  }
  const campId = ((data && data.campId) || "").trim();
  if (!campId) throw new HttpsError("invalid-argument", "missing-campId");

  const campSnap = await db.doc(`camps/${campId}`).get();
  if (!campSnap.exists) return { deleted: true }; // idempotent

  if (campSnap.data().orgId !== auth.token.orgId) {
    throw new HttpsError("permission-denied", "wrong-org");
  }

  await deleteCampCascade(db, campSnap.ref, campId, bucket);
  return { deleted: true };
}

module.exports = { deleteCampHandler };
