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

test("the legacy camp-scoped path is read-only-ish: even the camp's own org guide cannot write it", async () => {
  // New uploads go through the org-scoped sessionPhotos path (below); this
  // legacy path only exists so photos uploaded before that migration still
  // display and can be cleaned up (read + delete), per storage.rules' comment.
  const guide = orgGuide(guideOrgAUid, "org-A");
  await assertFails(
    guide.ref(campAPhoto).put(Buffer.from("new"), { contentType: "image/jpeg" })
  );
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
  await assertSucceeds(
    orgGuide(guideOrgAUid, "org-A")
      .ref(orgAMasterPhoto)
      .put(Buffer.from("x"), { contentType: "image/jpeg" })
  );
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgAMasterPhoto).putString("x"));
});

test("rejects an upload over 10MB to a location photo path", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  const oversized = Buffer.alloc(11 * 1024 * 1024, "a");
  await assertFails(
    guide
      .ref(orgAMasterPhoto)
      .put(oversized, { contentType: "image/jpeg" })
  );
});

test("rejects a non-image content type on a location photo path", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  const small = Buffer.from("not an image");
  await assertFails(
    guide
      .ref(orgAMasterPhoto)
      .put(small, { contentType: "text/html" })
  );
});

test("accepts a small, correctly-typed image upload to a location photo path", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  const small = Buffer.alloc(1024, "a");
  await assertSucceeds(
    guide
      .ref(orgAMasterPhoto)
      .put(small, { contentType: "image/jpeg" })
  );
});

// Deletes must be allowed for the owning org's guides even though the
// size/content-type conditions can't apply (request.resource is null on
// delete) — a combined `allow write` would deny these.
test("a guide of the org can delete a master location photo", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  await assertSucceeds(guide.ref(orgAMasterPhoto).delete());
});

test("a guide of ANOTHER org CANNOT delete a master location photo", async () => {
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgAMasterPhoto).delete());
});

test("a guide of the camp's org can delete its group photo", async () => {
  const guide = orgGuide(guideOrgAUid, "org-A");
  await assertSucceeds(guide.ref(campAPhoto).delete());
});

test("a guide of ANOTHER org CANNOT delete the camp's group photo", async () => {
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(campAPhoto).delete());
});

test("a kid cannot delete any photo", async () => {
  const kid = testEnv.authenticatedContext(kidCampAUid).storage();
  await assertFails(kid.ref(campAPhoto).delete());
  await assertFails(kid.ref(orgAMasterPhoto).delete());
});

// --- Org-scoped session photos + logo (current upload paths) ---

const orgASessionPhoto = "organizations/org-A/sessionPhotos/camp-A/loc-1/group_photo.jpg";
const orgALogo = "organizations/org-A/logo.jpg";

async function seedSecondCampInOrgA() {
  await seed(async (db) => {
    await db.doc("camps/camp-A2").set({ orgId: "org-A", name: "A2" });
    await db.doc("users/kid-campA2").set({ role: "kid", campId: "camp-A2", orgId: "org-A" });
  });
}

test("org session photo: a kid of that camp can read it", async () => {
  await seedFile(orgASessionPhoto);
  const kid = testEnv.authenticatedContext(kidCampAUid).storage();
  await assertSucceeds(kid.ref(orgASessionPhoto).getMetadata());
});

test("org session photo: a kid of ANOTHER camp in the same org CANNOT read it", async () => {
  await seedSecondCampInOrgA();
  await seedFile(orgASessionPhoto);
  const kid = testEnv.authenticatedContext("kid-campA2").storage();
  await assertFails(kid.ref(orgASessionPhoto).getMetadata());
});

test("org session photo: org guide reads and writes; other org's guide cannot", async () => {
  await seedFile(orgASessionPhoto);
  await assertSucceeds(orgGuide(guideOrgAUid, "org-A").ref(orgASessionPhoto).getMetadata());
  await assertSucceeds(orgGuide(guideOrgAUid, "org-A").ref(orgASessionPhoto)
    .putString("x", undefined, { contentType: "image/jpeg" }));
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgASessionPhoto).getMetadata());
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgASessionPhoto)
    .putString("x", undefined, { contentType: "image/jpeg" }));
});

test("org session photo: a kid cannot upload", async () => {
  const kid = testEnv.authenticatedContext(kidCampAUid).storage();
  await assertFails(kid.ref(orgASessionPhoto)
    .putString("x", undefined, { contentType: "image/jpeg" }));
});

test("org logo: any member of the org reads it; outsiders cannot", async () => {
  await seedFile(orgALogo);
  await assertSucceeds(testEnv.authenticatedContext(kidCampAUid).storage().ref(orgALogo).getMetadata());
  await assertSucceeds(orgGuide(guideOrgAUid, "org-A").ref(orgALogo).getMetadata());
  await assertFails(testEnv.authenticatedContext(kidCampBUid).storage().ref(orgALogo).getMetadata());
  await assertFails(orgGuide(guideOrgBUid, "org-B").ref(orgALogo).getMetadata());
});

test("org logo: only an org guide writes it, and only images", async () => {
  await assertSucceeds(orgGuide(guideOrgAUid, "org-A").ref(orgALogo)
    .putString("x", undefined, { contentType: "image/jpeg" }));
  await assertFails(orgGuide(guideOrgAUid, "org-A").ref(orgALogo)
    .putString("x", undefined, { contentType: "text/plain" }));
  await assertFails(testEnv.authenticatedContext(kidCampAUid).storage().ref(orgALogo)
    .putString("x", undefined, { contentType: "image/jpeg" }));
});
