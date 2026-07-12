process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv, makeAdminDb, makeAuthAdmin, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { registerGuideHandler } = require("../lib/registerGuide");

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
  authAdmin = makeAuthAdmin("campconnect-registerguide-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Org creation is gated by config/registration.orgCreationCode (see the
  // "org creation code gate" describe block below). The pre-existing tests
  // above create orgs and predate that gate, so they need a matching code
  // seeded here to keep passing under the new fail-closed behavior.
  await db.doc("config/registration").set({ orgCreationCode: "TESTCODE" });
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
    orgCreationCode: "TESTCODE",
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
  expect(memberDoc.data().joinedAt).toBeTruthy();
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
    orgCreationCode: "TESTCODE",
  }, "test-ip-3a");
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "dupe@example.com",
      password: "correcthorsebattery",
      displayName: "Second",
      newOrgName: "Camp Two",
      orgCreationCode: "TESTCODE",
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
      orgCreationCode: "TESTCODE",
    }, "test-ip-4")
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

describe("org creation code gate", () => {
  beforeEach(async () => {
    await db.doc("config/registration").set({ orgCreationCode: "LETMEIN2" });
  });

  test("creates the org when the code matches (case/space insensitive)", async () => {
    const res = await registerGuideHandler(db, authAdmin, {
      email: "owner@x.com",
      password: "secret123",
      displayName: "Owner",
      newOrgName: "Camp X",
      orgCreationCode: " letmein2 ",
    }, "1.2.3.4");
    expect(res.ok).toBe(true);
  });

  test("rejects a wrong code", async () => {
    await expect(registerGuideHandler(db, authAdmin, {
      email: "o2@x.com",
      password: "secret123",
      displayName: "O",
      newOrgName: "Camp Y",
      orgCreationCode: "WRONG",
    }, "1.2.3.5")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("rejects a missing code", async () => {
    await expect(registerGuideHandler(db, authAdmin, {
      email: "o3@x.com",
      password: "secret123",
      displayName: "O",
      newOrgName: "Camp Z",
    }, "1.2.3.6")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("rejects when no config doc exists (fail closed)", async () => {
    await db.doc("config/registration").delete();
    await expect(registerGuideHandler(db, authAdmin, {
      email: "o4@x.com",
      password: "secret123",
      displayName: "O",
      newOrgName: "Camp W",
      orgCreationCode: "LETMEIN2",
    }, "1.2.3.7")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("joining with an invite code does not need the creation code", async () => {
    const seedResult = await registerGuideHandler(db, authAdmin, {
      email: "seed-owner@example.com",
      password: "secret123",
      displayName: "Seed Owner",
      newOrgName: "Seed Camp",
      orgCreationCode: "LETMEIN2",
    }, "1.2.3.9");
    const orgDoc = await db.doc(`organizations/${seedResult.orgId}`).get();
    const seededInviteCode = orgDoc.data().inviteCode;

    const res = await registerGuideHandler(db, authAdmin, {
      email: "joiner@x.com",
      password: "secret123",
      displayName: "J",
      joinOrgCode: seededInviteCode,
    }, "1.2.3.8");
    expect(res.ok).toBe(true);
  });
});
