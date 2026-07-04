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
    storage: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../storage.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

// Helper to seed Firestore docs bypassing rules (storage rules read these
// via cross-service firestore.get()/exists()).
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// Helper to upload a dummy file bypassing rules, so read attempts below are
// checking rule evaluation on an existing object rather than a 404.
async function seedFile(storagePath) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(storagePath).putString("dummy");
  });
}

// Guides carry custom claims { role: 'guide', orgId }; kids have none.
const orgGuide = (uid, orgId) =>
  testEnv.authenticatedContext(uid, { role: "guide", orgId }).storage();

const guideOrgAUid = "guide-orgA";
const guideOrgBUid = "guide-orgB";
const kidCampAUid = "kid-campA";
const kidCampBUid = "kid-campB";

const campAPhoto = "camps/camp-A/sessionLocations/loc-1/group_photo.jpg";
const campBPhoto = "camps/camp-B/sessionLocations/loc-1/group_photo.jpg";
const orgAMasterPhoto = "organizations/org-A/locations/loc-1/photo.jpg";

beforeEach(async () => {
  await seed(async (db) => {
    // camp-A belongs to org-A, camp-B to org-B.
    await db.doc("camps/camp-A").set({ orgId: "org-A", name: "A" });
    await db.doc("camps/camp-B").set({ orgId: "org-B", name: "B" });
    await db.doc("users/" + kidCampAUid).set({ role: "kid", campId: "camp-A", orgId: "org-A" });
    await db.doc("users/" + kidCampBUid).set({ role: "kid", campId: "camp-B", orgId: "org-B" });
  });
  await seedFile(campAPhoto);
  await seedFile(campBPhoto);
  await seedFile(orgAMasterPhoto);
});

test("a kid from camp A can read camp A's group photo", async () => {
  const kid = testEnv.authenticatedContext(kidCampAUid).storage();
  await assertSucceeds(kid.ref(campAPhoto).getMetadata());
});

test("a kid from camp B CANNOT read camp A's group photo", async () => {
  const kid = testEnv.authenticatedContext(kidCampBUid).storage();
  await assertFails(kid.ref(campAPhoto).getMetadata());
});

test("a guide of the camp's org can read its group photo", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  await assertSucceeds(guide.ref(campAPhoto).getMetadata());
});

test("a guide of ANOTHER org CANNOT read the camp's group photo", async () => {
  const guide = orgGuide(guideOrgBUid, "org-B");
  await assertFails(guide.ref(campAPhoto).getMetadata());
});

test("a guide of the camp's org can write its group photo", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  await assertSucceeds(guide.ref(campAPhoto).putString("new"));
});

test("a guide of ANOTHER org CANNOT write the camp's group photo", async () => {
  const guide = orgGuide(guideOrgBUid, "org-B");
  await assertFails(guide.ref(campAPhoto).putString("hijack"));
});

test("an unauthenticated user cannot read any group photo", async () => {
  const anon = testEnv.unauthenticatedContext().storage();
  await assertFails(anon.ref(campAPhoto).getMetadata());
  await assertFails(anon.ref(campBPhoto).getMetadata());
});

test("master location photo: a kid of the org can read; a kid of another org cannot", async () => {
  const kidA = testEnv.authenticatedContext(kidCampAUid).storage();
  const kidB = testEnv.authenticatedContext(kidCampBUid).storage();
  await assertSucceeds(kidA.ref(orgAMasterPhoto).getMetadata());
  await assertFails(kidB.ref(orgAMasterPhoto).getMetadata());
});

test("master location photo: only a guide of the org may write", async () => {
  await assertSucceeds(orgGuide(guideOrgAUid, "org-A").ref(orgAMasterPhoto).putString("x"));
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgAMasterPhoto).putString("x"));
});
