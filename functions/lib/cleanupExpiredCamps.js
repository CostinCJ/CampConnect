const { deleteCampCascade } = require("./deleteCampCascade");
const { WINDOW_MS } = require("./rateLimiter");

// Process at most this many expired camps per scheduled run. With a 24-hour
// schedule, a backlog larger than this simply finishes over multiple days
// instead of risking exceeding the function's (now 540s) timeout. 540s is
// the hard ceiling for onSchedule (event-handling) triggers, not a tunable
// safety margin. Note this only bounds camp *count* per run, not Storage
// objects per camp — it assumes a small, bounded number of photos per camp;
// revisit if that assumption changes and a single iteration's deleteFiles
// call starts eating a disproportionate share of the shared timeout budget.
const BATCH_LIMIT = 50;

// Cap on stale rate-limit buckets purged per run (well under Firestore's
// 500-op batch ceiling). Every anonymous claim attempt creates a rateLimits
// doc that nothing else ever deletes; without this the collection grows
// without bound.
const RATE_LIMIT_PURGE_LIMIT = 400;

/**
 * Scheduled server-side cleanup: any camp whose endDate is more than 60 days
 * in the past is fully removed (subcollections via recursiveDelete, plus its
 * top-level codes). Replaces the Phase-1..4 client-side cleanupExpiredSessions.
 *
 * `bucket` is optional (a Storage bucket handle from getStorage().bucket()).
 * When provided, the camp's Storage photos (e.g. sessionLocations group
 * photos, which may contain images of children) are deleted alongside its
 * Firestore documents, closing the gap where recursiveDelete alone left
 * Storage objects behind forever. Existing callers that pass only `db` keep
 * working unchanged — the Storage step is simply skipped.
 */
async function cleanupExpiredCampsHandler(db, bucket) {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 60);
  const expired = await db.collection("camps")
    .where("endDate", "<", cutoff).limit(BATCH_LIMIT).get();
  for (const camp of expired.docs) {
    // Storage photos, subcollections, and top-level codes — see
    // deleteCampCascade for the Storage-first crash-safety reasoning.
    await deleteCampCascade(db, camp.ref, camp.id, bucket);
  }

  await purgeStaleRateLimits(db);
}

/**
 * Deletes rate-limit buckets whose window has fully expired (nothing reads a
 * bucket older than WINDOW_MS, so it's dead weight). Bounded per run to stay
 * under the batch limit; any remainder is cleared on subsequent daily runs.
 */
async function purgeStaleRateLimits(db) {
  const staleBefore = Date.now() - WINDOW_MS;
  const stale = await db.collection("rateLimits")
    .where("windowStart", "<", staleBefore)
    .limit(RATE_LIMIT_PURGE_LIMIT)
    .get();
  if (stale.empty) return;
  const batch = db.batch();
  stale.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

module.exports = { cleanupExpiredCampsHandler, BATCH_LIMIT };
