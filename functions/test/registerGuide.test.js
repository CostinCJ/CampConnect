process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv, makeAdminDb } = require("./helpers/emulatorEnv");
const { registerGuideHandler } = require("../lib/registerGuide");
const admin = require("firebase-admin");

// registerGuideHandler (functions/lib/registerGuide.js) writes
// FieldValue.serverTimestamp() inside a db.batch() commit, exactly like
// claimCampCodeHandler -- see the NOTE in helpers/emulatorEnv.js on why that
// requires the admin-SDK db from makeAdminDb rather than withDb's client-SDK
// handle (a client-SDK commit can't write the admin SDK's serverTimestamp
// sentinel and throws "Unsupported field value").
let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-registerguide-test"));
  db = makeAdminDb("campconnect-registerguide-test");
  // makeAdminDb() initializes its own *named* admin app (so admin.apps is
  // already non-empty by the time we get here) -- it does not create the
  // default app that a no-arg admin.auth() looks up. Initialize the default
  // app explicitly rather than relying on `admin.apps.length` as an "already
  // set up" check.
  const defaultApp = admin.apps.find((a) => a.name === "[DEFAULT]") ||
    admin.initializeApp({ projectId: "campconnect-registerguide-test" });
  authAdmin = admin.auth(defaultApp);
});

afterAll(async () => {
  await testEnv.cleanup();
  // Close every admin app this file initialized (the default one used for
  // authAdmin, plus makeAdminDb's uniquely-named one) so their emulator
  // connections don't keep the process alive -- without this, jest reports
  // "did not exit one second after the test run has completed".
  await Promise.all(admin.apps.map((app) => app.delete()));
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Each test passes its own distinct callerIp. registerGuideHandler keys its
// rate limit as `registerGuide:${callerIp}` (falling back to "unknown" if
// omitted) and allows only 5 attempts per key per hour (see
// functions/lib/rateLimiter.js MAX_ATTEMPTS). The "duplicate email" test below
// alone calls the handler twice; sharing one key across all tests in this
// file would put the suite right at that boundary and make it order-/
// count-dependent. Distinct keys keep each test's rate-limit bucket isolated
// from the others, which is a test-isolation concern, not real handler
// behavior under test.
test("creating a new org with a valid new-org request creates an Auth user with guide claims", async () => {
  const result = await registerGuideHandler(db, authAdmin, {
    email: "guide1@example.com",
    password: "correcthorsebattery",
    displayName: "Guide One",
    newOrgName: "Camp Falcon",
  }, "test-ip-1");
  expect(result.ok).toBe(true);
  expect(result.orgId).toBeTruthy();

  const user = await authAdmin.getUserByEmail("guide1@example.com");
  expect(user.customClaims.role).toBe("guide");
  expect(user.customClaims.orgId).toBe(result.orgId);

  const orgDoc = await db.doc(`organizations/${result.orgId}`).get();
  expect(orgDoc.data().name).toBe("Camp Falcon");
  expect(orgDoc.data().ownerUid).toBe(user.uid);

  const memberDoc = await db.doc(`organizations/${result.orgId}/members/${user.uid}`).get();
  expect(memberDoc.data().role).toBe("owner");
});

test("joining with an invalid org invite code throws permission-denied", async () => {
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "guide2@example.com",
      password: "correcthorsebattery",
      displayName: "Guide Two",
      joinOrgCode: "NOT-A-REAL-CODE",
    }, "test-ip-2")
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("registering with an already-used email throws already-exists and leaves no orphan org", async () => {
  await registerGuideHandler(db, authAdmin, {
    email: "dupe@example.com",
    password: "correcthorsebattery",
    displayName: "First",
    newOrgName: "Camp One",
  }, "test-ip-3a");
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "dupe@example.com",
      password: "correcthorsebattery",
      displayName: "Second",
      newOrgName: "Camp Two",
    }, "test-ip-3b")
  ).rejects.toMatchObject({ code: "already-exists" });

  const orgsSnap = await db.collection("organizations").where("name", "==", "Camp Two").get();
  expect(orgsSnap.empty).toBe(true);
});

test("registering with a weak password throws invalid-argument", async () => {
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "weak@example.com",
      password: "123",
      displayName: "Weak",
      newOrgName: "Camp Weak",
    }, "test-ip-4")
  ).rejects.toMatchObject({ code: "invalid-argument" });
});
