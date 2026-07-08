const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { checkRateLimit } = require("./rateLimiter");

// Anonymous kids can mint fresh uids at will, so a per-uid limit alone is weak
// against code brute-forcing. A coarser per-IP cap (this many claim attempts
// per IP per window) bounds a single client regardless of how many anonymous
// accounts it churns through; the per-uid limit still protects one compromised
// session.
const CLAIM_IP_MAX_ATTEMPTS = 20;

/**
 * claimCampCodeHandler(db, auth, data, callerIp)
 *
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp exists, code's org matches its
 * camp's org, camp not ended. Creates the kid profile server-side. Returns
 * { campId, team, displayName }.
 *
 * Codes live in a top-level `codes/{code}` collection (Phase 5), so this is a
 * single get() instead of a collection-group scan.
 *
 * data: { code }  — must match /^[A-Z0-9]{2,8}-[A-Z0-9]{4}$/ (an org's custom
 *   code prefix, 2-8 chars, or the CAMP fallback; case-insensitive, trimmed
 *   and upper-cased before validation)
 * callerIp: caller's IP, used for the per-IP rate limit (falls back to
 *   "unknown"). Optional for older call sites/tests.
 *
 * Throws HttpsError with one of:
 *   unauthenticated     ("Sign in first.") — no auth context (caller must be
 *                        anonymously signed in first)
 *   resource-exhausted  ("too-many-attempts") — rate limit (per-uid OR per-IP)
 *   invalid-argument    ("invalid-code") — malformed code string
 *   not-found           ("invalid-code") — well-formed code doesn't exist
 *   already-exists      ("code-used") — code was already claimed
 *   failed-precondition ("session-expired") — the code's camp has ended OR no
 *                        longer exists (e.g. was deleted out from under the code)
 *   failed-precondition ("invalid-code") — the code's org doesn't match its
 *                        camp's org (defense-in-depth against forged campId)
 *
 * On success: inside a Firestore transaction, atomically marks the code used,
 * creates the kid's users/{uid} profile (role, displayName, campId, orgId,
 * team), and returns { campId, team, displayName }.
 */
async function claimCampCodeHandler(db, auth, data, callerIp) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;
  const ip = callerIp || "unknown";

  const allowedUid = await checkRateLimit(db, `claimCampCode:${uid}`);
  const allowedIp = await checkRateLimit(
    db, `claimCampCode:ip:${ip}`, CLAIM_IP_MAX_ATTEMPTS);
  if (!allowedUid || !allowedIp) {
    throw new HttpsError("resource-exhausted", "too-many-attempts");
  }

  const code = ((data && data.code) || "").trim().toUpperCase();
  if (!/^[A-Z0-9]{2,8}-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const codeRef = db.doc(`codes/${code}`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists) throw new HttpsError("not-found", "invalid-code");
    const d = snap.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    const campSnap = await tx.get(db.doc(`camps/${d.campId}`));
    if (!campSnap.exists) {
      // The code points at a camp that no longer exists (e.g. it was deleted).
      // Fail cleanly instead of creating a profile that references a missing
      // camp, which would leave the kid in a permanently broken state.
      throw new HttpsError("failed-precondition", "session-expired");
    }
    const camp = campSnap.data();
    if (camp.orgId && d.orgId && camp.orgId !== d.orgId) {
      // A code must belong to the same org as its camp. A mismatch means a
      // forged/cross-org campId; refuse rather than grant camp membership.
      throw new HttpsError("failed-precondition", "invalid-code");
    }
    const end = camp.endDate;
    if (end && end.toDate && end.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "session-expired");
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
