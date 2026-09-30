const { FieldValue } = require("firebase-admin/firestore");

// Firestore rejects a batch with more than 500 writes.
const MAX_BATCH_WRITES = 500;

/**
 * Applies `op(batch, doc)` to every doc in `docs`, committing in chunks of at
 * most MAX_BATCH_WRITES so a large camp can't exceed the batch ceiling.
 */
async function commitInChunks(db, docs, op) {
  for (let i = 0; i < docs.length; i += MAX_BATCH_WRITES) {
    const batch = db.batch();
    docs.slice(i, i + MAX_BATCH_WRITES).forEach((d) => op(batch, d));
    await batch.commit();
  }
}

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
 * Guides also store their *active* camp in `users/{uid}.campId`, so only
 * `role == "kid"` profiles are deleted; a guide just has the stale pointer
 * cleared. Deleting a guide's profile would lock them out of their account.
 *
 * Group photos live under the org-scoped
 * `organizations/{orgId}/sessionPhotos/{campId}/` prefix (current uploads) and
 * the legacy `camps/{campId}/` prefix (older uploads); both are deleted.
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
    const campSnap = await campRef.get();
    const orgId = campSnap.exists ? campSnap.data().orgId : null;
    if (orgId) {
      await bucket.deleteFiles({
        prefix: `organizations/${orgId}/sessionPhotos/${campId}/`,
      });
    }
    await bucket.deleteFiles({ prefix: `camps/${campId}/` });
  }
  // recursiveDelete clears all subcollections (teams, announcements, ...).
  await db.recursiveDelete(campRef);
  const codes = await db.collection("codes").where("campId", "==", campId).get();
  await commitInChunks(db, codes.docs, (batch, d) => batch.delete(d.ref));

  const users = await db.collection("users").where("campId", "==", campId).get();
  await commitInChunks(db, users.docs, (batch, d) => {
    if (d.data().role === "kid") {
      batch.delete(d.ref);
    } else {
      batch.update(d.ref, { campId: FieldValue.delete() });
    }
  });
}

module.exports = { deleteCampCascade, commitInChunks };
