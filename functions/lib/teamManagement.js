const { HttpsError } = require("firebase-functions/v2/https");
const { commitInChunks } = require("./deleteCampCascade");

/** A single Firestore path segment: non-empty, no slashes, not "." / "..". */
function isDocId(v) {
  return typeof v === "string" && v.length > 0 && v.length <= 128 &&
    !v.includes("/") && v !== "." && v !== "..";
}

/**
 * Shared guard: verifies the caller is a guide of the camp's own org.
 * Returns the camp snapshot (already confirmed to exist and to belong to the
 * caller's org).
 */
async function requireCampGuide(db, auth, campId) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  // An org-less guide (no orgId claim) must never pass the org comparison
  // below against a camp that also lacks an orgId (undefined === undefined).
  if (!auth.token || auth.token.role !== "guide" || !auth.token.orgId) {
    throw new HttpsError("permission-denied", "guides-only");
  }
  if (!isDocId(campId)) {
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
 * Unclaimed codes for the team move with the kids when reassignToTeamId is
 * given, and are deleted otherwise.
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

  if (!isDocId(teamId)) {
    throw new HttpsError("invalid-argument", "missing-teamId");
  }
  if (reassignToTeamId !== undefined && reassignToTeamId !== null &&
      !isDocId(reassignToTeamId)) {
    throw new HttpsError("invalid-argument", "reassign-target-not-found");
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

  // Unclaimed codes still pointing at this team would hand the next kid who
  // claims one a team that no longer exists.
  const unclaimedCodes = (await db.collection("codes")
    .where("campId", "==", campId)
    .where("team", "==", teamId)
    .get()).docs.filter((d) => d.data().used !== true);

  if (kidsSnap.empty && (unclaimedCodes.length === 0 || !reassignToTeamId)) {
    // Nothing to move: the leftover codes are useless, so delete them.
    await commitInChunks(db, unclaimedCodes, (batch, d) => batch.delete(d.ref));
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
  await commitInChunks(db, [...docs, ...unclaimedCodes],
    (batch, d) => batch.update(d.ref, { team: reassignToTeamId }));

  await teamRef.delete();
  return { deleted: true, reassigned: docs.length };
}

module.exports = { deleteTeamHandler };
