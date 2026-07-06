/**
 * Fully removes a single camp: its Storage photos (which may include group
 * photos of children), all Firestore subcollections (via recursiveDelete), and
 * its top-level `codes`. Shared by the scheduled cleanup, the account-deletion
 * owner cascade, and the on-demand deleteCamp callable so the three can never
 * drift apart.
 *
 * Storage is deleted FIRST on purpose: if the process crashes mid-way, the camp
 * doc still exists and a later retry can pick it back up (deleteFiles on an
 * already-empty prefix is a safe no-op). The reverse order would silently
 * orphan photos forever once the camp doc — the only record the camp ever
 * existed — is gone.
 *
 * `bucket` is optional (a Storage bucket handle from getStorage().bucket());
 * when omitted the Storage step is skipped and only Firestore data is removed.
 */
async function deleteCampCascade(db, campRef, campId, bucket) {
  if (bucket) {
    await bucket.deleteFiles({ prefix: `camps/${campId}/` });
  }
  // recursiveDelete clears all subcollections (teams, announcements, ...).
  await db.recursiveDelete(campRef);
  const codes = await db.collection("codes").where("campId", "==", campId).get();
  const batch = db.batch();
  codes.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

module.exports = { deleteCampCascade };
