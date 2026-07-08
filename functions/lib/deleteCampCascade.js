/**
 * Fully removes a single camp: its Storage photos (which may include group
 * photos of children), all Firestore subcollections (via recursiveDelete),
 * its top-level `codes`, and any kid `users/{uid}` profiles that reference it.
 * Shared by the scheduled cleanup, the account-deletion owner cascade, and the
 * on-demand deleteCamp callable so the three can never drift apart.
 *
 * Kid profiles are deleted here (rather than left to linger) because a kid
 * never deletes their own profile — without this, a camper's first name/team
 * would persist indefinitely after the camp itself is gone, contradicting the
 * privacy policy's stated retention and GDPR storage-limitation (Art. 5(1)(e)).
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
  const codesBatch = db.batch();
  codes.forEach((d) => codesBatch.delete(d.ref));
  await codesBatch.commit();

  const kids = await db.collection("users").where("campId", "==", campId).get();
  const kidsBatch = db.batch();
  kids.forEach((d) => kidsBatch.delete(d.ref));
  await kidsBatch.commit();
}

module.exports = { deleteCampCascade };
