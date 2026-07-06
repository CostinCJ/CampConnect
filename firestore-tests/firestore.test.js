const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "campconnect-rules-test",
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test("smoke: rules file loads and default-deny works", async () => {
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(anon.collection("random").doc("x").get());
});

// Helper to seed docs bypassing rules.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// Guides now carry custom claims { role: 'guide', orgId } set at registration
// (server-side, via registerGuide) — rules check claims, not a `role` field
// on the user doc.
const orgGuide = (uid, orgId) =>
  testEnv.authenticatedContext(uid, { role: "guide", orgId }).firestore();

const guideUid = "guide-1";
const otherGuideUid = "guide-2";
const kidUid = "kid-1";
const orgId = "org-1";
const otherOrgId = "org-2";

test("config/app is NOT readable by anyone (invite code is secret)", async () => {
  await seed(async (db) => {
    await db.doc("config/app").set({ guideInviteCode: "SECRET" });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertFails(anon.doc("config/app").get());
  await assertFails(kid.doc("config/app").get());
});

test("users cannot create their own profile doc (server-only)", async () => {
  const someone = testEnv.authenticatedContext("attacker-1").firestore();
  await assertFails(
    someone.doc("users/attacker-1").set({ role: "guide" })
  );
});

test("users cannot change their own role (only campId is updatable, guides only)", async () => {
  await seed(async (db) => {
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("users/" + guideUid).set({ role: "guide", orgId });
    // The camp a guide is allowed to switch to must be in their own org.
    await db.doc("camps/camp-9").set({ orgId, createdBy: guideUid, name: "Nine" });
  });
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  const guide = orgGuide(guideUid, orgId);
  // Escalation attempt: denied.
  await assertFails(kid.doc("users/" + kidUid).update({ role: "guide" }));
  // Legit: a guide switching active camp updates ONLY campId, to an own-org camp.
  await assertSucceeds(guide.doc("users/" + guideUid).update({ campId: "camp-9" }));
});

test("camp-hopping: a kid CANNOT change their own campId (server-set, immutable)", async () => {
  await seed(async (db) => {
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1", orgId });
    await db.doc("camps/camp-2").set({ orgId: otherOrgId, createdBy: otherGuideUid, name: "B" });
  });
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  // Previously allowed (any campId) — now denied: kids have no guide claim.
  await assertFails(kid.doc("users/" + kidUid).update({ campId: "camp-2" }));
});

test("camp-hopping: a guide CANNOT point campId at another org's camp", async () => {
  await seed(async (db) => {
    await db.doc("users/" + guideUid).set({ role: "guide", orgId, campId: "camp-1" });
    await db.doc("camps/camp-2").set({ orgId: otherOrgId, createdBy: otherGuideUid, name: "B" });
  });
  const guide = orgGuide(guideUid, orgId);
  await assertFails(guide.doc("users/" + guideUid).update({ campId: "camp-2" }));
});

test("codes list: the guide's own-org query (where orgId==) is allowed", async () => {
  await seed(async (db) => {
    await db.doc("codes/CAMP-AAAA").set({ orgId, campId: "camp-1", used: false, team: "t" });
    await db.doc("codes/CAMP-BBBB").set({ orgId: otherOrgId, campId: "camp-9", used: false, team: "t" });
  });
  const guide = orgGuide(guideUid, orgId);
  // This is the exact query CampRepository now runs (orgId + campId filter).
  await assertSucceeds(
    guide.collection("codes").where("orgId", "==", orgId).where("campId", "==", "camp-1").get());
  // An unconstrained/other-org query is still denied.
  await assertFails(guide.collection("codes").where("campId", "==", "camp-1").get());
});

test("codes get: a guide may collision-check a non-existent code of their org", async () => {
  const guide = orgGuide(guideUid, orgId);
  // resource == null (doc doesn't exist) must not error to a deny.
  await assertSucceeds(guide.doc("codes/CAMP-ZZZZ").get());
});

test("a user can read their own doc but not another user's", async () => {
  await seed(async (db) => {
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("users/" + guideUid).set({ role: "guide" });
  });
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertSucceeds(kid.doc("users/" + kidUid).get());
  await assertFails(kid.doc("users/" + guideUid).get());
});

test("any guide of the camp's org can modify it; a guide of another org cannot", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ createdBy: guideUid, name: "C", orgId });
  });
  const owner = orgGuide(guideUid, orgId);
  // A different guide in the SAME org can read AND write — camps are managed
  // by the whole org, not creator-gated (that was a Phase-2 interim rule).
  const sameOrgGuide = orgGuide(otherGuideUid, orgId);
  // A guide of a DIFFERENT org can't even read (org isolation).
  const outsideGuide = orgGuide(otherGuideUid, otherOrgId);
  await assertSucceeds(owner.doc("camps/camp-1").get());
  await assertSucceeds(sameOrgGuide.doc("camps/camp-1").update({ name: "ok" }));
  await assertFails(outsideGuide.doc("camps/camp-1").get());
});

test("codes: unreadable by kids/anon, manageable by guides of the owning org", async () => {
  await seed(async (db) => {
    await db.doc("codes/CAMP-ABCD").set({ team: "red", used: false, campId: "camp-1", orgId });
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  const guide = orgGuide(guideUid, orgId);
  await assertFails(anon.doc("codes/CAMP-ABCD").get());
  await assertFails(kid.doc("codes/CAMP-ABCD").get());
  await assertSucceeds(guide.doc("codes/CAMP-ABCD").get());
});

test("teams: readable by a camp member, writable only by a guide of the camp's org", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ createdBy: guideUid, name: "C", orgId });
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("camps/camp-1/teams/red").set({ points: 0 });
  });
  const guide = orgGuide(guideUid, orgId);
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertSucceeds(kid.doc("camps/camp-1/teams/red").get());
  await assertFails(kid.doc("camps/camp-1/teams/red").update({ points: 999 }));
  await assertSucceeds(guide.doc("camps/camp-1/teams/red").update({ points: 5 }));
});

test("org isolation: a guide cannot read another org's camp", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ orgId: "o1", createdBy: "g1", name: "A" });
    await db.doc("camps/camp-2").set({ orgId: "o2", createdBy: "g2", name: "B" });
  });
  const g1 = orgGuide("g1", "o1");
  await assertSucceeds(g1.doc("camps/camp-1").get());
  await assertFails(g1.doc("camps/camp-2").get());
});

test("org isolation: codes are only visible to the owning org's guides", async () => {
  await seed(async (db) => {
    await db.doc("codes/CAMP-AAAA").set({ orgId: "o1", campId: "camp-1", used: false });
  });
  await assertSucceeds(orgGuide("g1", "o1").doc("codes/CAMP-AAAA").get());
  await assertFails(orgGuide("g2", "o2").doc("codes/CAMP-AAAA").get());
  await assertFails(testEnv.authenticatedContext("kid-1").firestore()
    .doc("codes/CAMP-AAAA").get());
});

test("rateLimits collection is not client-readable or writable", async () => {
  const guide = orgGuide(guideUid, orgId);
  await assertFails(guide.doc("rateLimits/claimCampCode:someuid").get());
  await assertFails(guide.doc("rateLimits/claimCampCode:someuid").set({ count: 0 }));
});

test("org locations: org guide writes; member kid reads; outsider denied", async () => {
  await seed(async (db) => {
    await db.doc("organizations/o1/locations/l1").set({ name: "Cave" });
    await db.doc("users/kid-1").set({ role: "kid", campId: "c1", orgId: "o1" });
    await db.doc("users/kid-2").set({ role: "kid", campId: "c9", orgId: "o2" });
  });
  await assertSucceeds(orgGuide("g1", "o1").doc("organizations/o1/locations/l1").get());
  await assertSucceeds(testEnv.authenticatedContext("kid-1").firestore()
    .doc("organizations/o1/locations/l1").get());
  await assertFails(testEnv.authenticatedContext("kid-2").firestore()
    .doc("organizations/o1/locations/l1").get());
  await assertFails(orgGuide("g2", "o2").doc("organizations/o1/locations/l1").set({ name: "x" }));
});
