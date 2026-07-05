const { Timestamp } = require("firebase-admin/firestore");
const { makeTestEnv, makeAdminDb } = require("./helpers/emulatorEnv");
const { claimCampCodeHandler } = require("../lib/claimCampCode");

let testEnv, db;

beforeAll(async () => {
  // testEnv is only used here for clearFirestore() housekeeping (an
  // SDK-agnostic REST call against the emulator, so this is safe to mix
  // with an admin-SDK db). The handler itself is always exercised through
  // the admin SDK below, matching production (index.js injects
  // getFirestore() from firebase-admin/firestore) -- see the NOTE in
  // helpers/emulatorEnv.js on why the client SDK can't be used here: it
  // can't write the admin SDK's FieldValue.serverTimestamp() sentinel that
  // claimCampCodeHandler's transaction commits on every successful claim.
  ({ testEnv } = await makeTestEnv("campconnect-claimcode-test"));
  db = makeAdminDb("campconnect-claimcode-test");
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Seeds a `codes/{code}` doc plus its parent `camps/{campId}` doc. Field
// names match the real claimCampCodeHandler (functions/lib/claimCampCode.js):
// it reads d.campId, d.team, d.displayName, d.used, d.orgId off the code doc,
// and camp.createdBy / camp.endDate off the camp doc, calling `.toDate()` on
// endDate.
async function seedCode(code, overrides = {}) {
  const { camp: campOverrides, ...codeOverrides } = overrides;
  await db.doc(`codes/${code}`).set({
    campId: "camp-1",
    orgId: "org-1",
    team: "red",
    displayName: "Campist #1",
    used: false,
    ...codeOverrides,
  });
  await db.doc("camps/camp-1").set({
    createdBy: "guide-1",
    endDate: Timestamp.fromDate(new Date(Date.now() + 86400000)), // tomorrow
    ...campOverrides,
  });
}

test("two concurrent claims of the same code — exactly one succeeds", async () => {
  await seedCode("CAMP-TEST");

  const [r1, r2] = await Promise.allSettled([
    claimCampCodeHandler(db, { uid: "kid-a" }, { code: "CAMP-TEST" }),
    claimCampCodeHandler(db, { uid: "kid-b" }, { code: "CAMP-TEST" }),
  ]);

  const fulfilled = [r1, r2].filter((r) => r.status === "fulfilled");
  const rejected = [r1, r2].filter((r) => r.status === "rejected");
  expect(fulfilled.length).toBe(1);
  expect(rejected.length).toBe(1);
  expect(rejected[0].reason.code).toBe("already-exists");

  const codeDoc = await db.doc("codes/CAMP-TEST").get();
  expect(codeDoc.data().used).toBe(true);
}, 15000); // two full (rate-limiter + claim) transactions run concurrently against
// the emulator; under contention/retry plus emulator cold-start variance this
// occasionally exceeds jest's 5000ms default, so it gets a longer budget.

test("claiming an already-used code throws already-exists", async () => {
  await seedCode("CAMP-USED", { used: true, usedBy: "kid-a" });
  await expect(
    claimCampCodeHandler(db, { uid: "kid-b" }, { code: "CAMP-USED" })
  ).rejects.toMatchObject({ code: "already-exists" });
});

test("claiming a code for an ended camp throws failed-precondition", async () => {
  await db.doc("codes/CAMP-OLDX").set({
    campId: "camp-old", team: "red", displayName: "X", used: false,
  });
  await db.doc("camps/camp-old").set({
    createdBy: "guide-1",
    endDate: Timestamp.fromDate(new Date(Date.now() - 86400000)), // yesterday
  });
  await expect(
    claimCampCodeHandler(db, { uid: "kid-a" }, { code: "CAMP-OLDX" })
  ).rejects.toMatchObject({ code: "failed-precondition" });
});

test("a malformed code (not CAMP-XXXX) throws invalid-argument", async () => {
  await expect(
    claimCampCodeHandler(db, { uid: "kid-a" }, { code: "not-a-code" })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("a well-formed but nonexistent code throws not-found", async () => {
  await expect(
    claimCampCodeHandler(db, { uid: "kid-a" }, { code: "CAMP-ZZZZ" })
  ).rejects.toMatchObject({ code: "not-found" });
});

test("an unauthenticated caller throws unauthenticated", async () => {
  await expect(
    claimCampCodeHandler(db, null, { code: "CAMP-TEST" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});
