// Process at most this many expired camps per scheduled run. With a 24-hour
// schedule, a backlog larger than this simply finishes over multiple days
// instead of risking exceeding the function's (now 540s) timeout. 540s is
// the hard ceiling for onSchedule (event-handling) triggers, not a tunable
// safety margin. Note this only bounds camp *count* per run, not Storage
// objects per camp — it assumes a small, bounded number of photos per camp;
// revisit if that assumption changes and a single iteration's deleteFiles
// call starts eating a disproportionate share of the shared timeout budget.
const BATCH_LIMIT = 50;

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
    // Storage first: if this process crashes here, the camp doc still
    // exists and will be retried next run (deleteFiles on an already-empty
    // prefix is a safe no-op) — the reverse order would silently orphan
    // photos forever once the Firestore doc (and the record of the camp
    // ever existing) is gone.
    if (bucket) {
      await bucket.deleteFiles({ prefix: `camps/${camp.id}/` });
    }
    // recursiveDelete clears all subcollections (teams, announcements, ...).
    await db.recursiveDelete(camp.ref);
    const codes = await db.collection("codes")
      .where("campId", "==", camp.id).get();
    const batch = db.batch();
    codes.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

module.exports = { cleanupExpiredCampsHandler, BATCH_LIMIT };
