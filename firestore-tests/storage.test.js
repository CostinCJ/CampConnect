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

const guideUid = "guide-1";
const kidCampAUid = "kid-campA";
const kidCampBUid = "kid-campB";

const campAPhoto = "camps/camp-A/sessionLocations/loc-1/group_photo.jpg";
const campBPhoto = "camps/camp-B/sessionLocations/loc-1/group_photo.jpg";

beforeEach(async () => {
  await seed(async (db) => {
    await db.doc("users/" + guideUid).set({ role: "guide", campId: "camp-A" });
    await db.doc("users/" + kidCampAUid).set({ role: "kid", campId: "camp-A" });
    await db.doc("users/" + kidCampBUid).set({ role: "kid", campId: "camp-B" });
  });
  await seedFile(campAPhoto);
  await seedFile(campBPhoto);
});

test("a kid from camp A can read camp A's group photo", async () => {
  const kid = testEnv.authenticatedContext(kidCampAUid).storage();
  await assertSucceeds(kid.ref(campAPhoto).getMetadata());
});

test("a kid from camp B CANNOT read camp A's group photo", async () => {
  const kid = testEnv.authenticatedContext(kidCampBUid).storage();
  await assertFails(kid.ref(campAPhoto).getMetadata());
});

test("a guide can read any camp's group photo", async () => {
  const guide = testEnv.authenticatedContext(guideUid).storage();
  await assertSucceeds(guide.ref(campAPhoto).getMetadata());
  await assertSucceeds(guide.ref(campBPhoto).getMetadata());
});

test("an unauthenticated user cannot read any group photo", async () => {
  const anon = testEnv.unauthenticatedContext().storage();
  await assertFails(anon.ref(campAPhoto).getMetadata());
  await assertFails(anon.ref(campBPhoto).getMetadata());
});
