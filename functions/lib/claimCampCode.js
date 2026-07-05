const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { checkRateLimit } = require("./rateLimiter");

/**
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp not ended. Creates the kid profile
 * server-side. Returns { campId, team, displayName }.
 *
 * Codes live in a top-level `codes/{code}` collection (Phase 5), so this is a
 * single get() instead of a collection-group scan.
 */
async function claimCampCodeHandler(db, auth, data) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const allowed = await checkRateLimit(db, `claimCampCode:${uid}`);
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "too-many-attempts");
  }

  const code = ((data && data.code) || "").trim().toUpperCase();
  if (!/^CAMP-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const codeRef = db.doc(`codes/${code}`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists) throw new HttpsError("not-found", "invalid-code");
    const d = snap.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    const campSnap = await tx.get(db.doc(`camps/${d.campId}`));
    if (campSnap.exists) {
      const end = campSnap.data().endDate;
      if (end && end.toDate && end.toDate() < new Date()) {
        throw new HttpsError("failed-precondition", "session-expired");
      }
    }

    tx.update(codeRef, { used: true, usedBy: uid });
    tx.set(db.doc(`users/${uid}`), {
      role: "kid",
      displayName: d.displayName || "Campist",
      campId: d.campId,
      orgId: d.orgId,
      team: d.team,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      campId: d.campId,
      team: d.team,
      displayName: d.displayName || "Campist",
    };
  });
}

module.exports = { claimCampCodeHandler };
