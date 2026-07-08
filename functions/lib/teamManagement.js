const { HttpsError } = require("firebase-functions/v2/https");

/**
 * Shared guard: verifies the caller is a guide of the camp's own org.
 * Returns the camp snapshot (already confirmed to exist and to belong to the
 * caller's org).
 */
async function requireCampGuide(db, auth, campId) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  if (!auth.token || auth.token.role !== "guide") {
    throw new HttpsError("permission-denied", "guides-only");
  }
  if (!campId || typeof campId !== "string") {
    throw new HttpsError("invalid-argument", "missing-campId");
  }

  const campSnap = await db.doc(`camps/${campId}`).get();
  if (!campSnap.exists) {
    throw new HttpsError("not-found", "camp-not-found");
  }
  if (campSnap.data().orgId !== auth.token.orgId) {
    throw new HttpsError("permission-denied", "wrong-org");
  }
  return campSnap;
}

/**
 * deleteTeamHandler(db, auth, data)
 *
 * Deletes a team from a camp. Firestore rules only let a client read its OWN
 * users/{uid} doc, so "does any kid still belong to this team" — a
 * cross-user query — can never succeed from the client; it has to run here,
 * on the Admin SDK, which is why the old client-side
 * TeamsRepository.deleteTeam always failed with permission-denied before
 * ever reaching the actual delete.
 *
 * data: { campId, teamId, reassignToTeamId? }
 *  - reassignToTeamId absent, team has kids  -> throws failed-precondition
 *    ("team-in-use") with details { kidCount }, so the client can offer a
 *    reassignment dialog.
 *  - reassignToTeamId present, team has kids -> moves every kid on teamId to
 *    reassignToTeamId, then deletes teamId.
 *  - team has no kids                        -> deletes it directly.
 *
 * Throws HttpsError:
 *   unauthenticated / permission-denied ("guides-only" / "wrong-org")
 *   invalid-argument ("missing-campId" / "missing-teamId")
 *   not-found ("camp-not-found")
 *   failed-precondition ("team-in-use", details: { kidCount })
 *   invalid-argument ("cannot-reassign-to-self")
 *   invalid-argument ("reassign-target-not-found") — reassignToTeamId isn't
 *     a real team in this camp
 *
 * Deleting a team that's already gone (or was never there) is an idempotent
 * no-op success, matching deleteCamp's convention.
 */
async function deleteTeamHandler(db, auth, data) {
  const { campId, teamId, reassignToTeamId } = data || {};
  await requireCampGuide(db, auth, campId);

  if (!teamId || typeof teamId !== "string") {
    throw new HttpsError("invalid-argument", "missing-teamId");
  }

  const teamRef = db.doc(`camps/${campId}/teams/${teamId}`);
  const teamSnap = await teamRef.get();
  if (!teamSnap.exists) {
    return { deleted: true }; // idempotent
  }

  const kidsSnap = await db
    .collection("users")
    .where("campId", "==", campId)
    .where("team", "==", teamId)
    .get();

  if (kidsSnap.empty) {
    await teamRef.delete();
    return { deleted: true };
  }

  if (!reassignToTeamId || typeof reassignToTeamId !== "string") {
    throw new HttpsError("failed-precondition", "team-in-use", {
      kidCount: kidsSnap.size,
    });
  }
  if (reassignToTeamId === teamId) {
    throw new HttpsError("invalid-argument", "cannot-reassign-to-self");
  }
  const targetSnap = await db
    .doc(`camps/${campId}/teams/${reassignToTeamId}`)
    .get();
  if (!targetSnap.exists) {
    throw new HttpsError("invalid-argument", "reassign-target-not-found");
  }

  const docs = kidsSnap.docs;
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    const end = Math.min(i + 400, docs.length);
    for (let j = i; j < end; j++) {
      batch.update(docs[j].ref, { team: reassignToTeamId });
    }
    await batch.commit();
  }

  await teamRef.delete();
  return { deleted: true, reassigned: docs.length };
}

module.exports = { deleteTeamHandler };
