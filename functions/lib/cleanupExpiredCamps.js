/**
 * Scheduled server-side cleanup: any camp whose endDate is more than 60 days
 * in the past is fully removed (subcollections via recursiveDelete, plus its
 * top-level codes). Replaces the Phase-1..4 client-side cleanupExpiredSessions.
 */
async function cleanupExpiredCampsHandler(db) {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 60);
  const expired = await db.collection("camps")
    .where("endDate", "<", cutoff).get();
  for (const camp of expired.docs) {
    // recursiveDelete clears all subcollections (teams, announcements, ...).
    await db.recursiveDelete(camp.ref);
    const codes = await db.collection("codes")
      .where("campId", "==", camp.id).get();
    const batch = db.batch();
    codes.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

module.exports = { cleanupExpiredCampsHandler };
