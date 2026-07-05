const { makeTestEnv, makeAdminDb } = require("./helpers/emulatorEnv");
const { cleanupExpiredCampsHandler } = require("../lib/cleanupExpiredCamps");

// cleanupExpiredCampsHandler (functions/lib/cleanupExpiredCamps.js) calls
// db.recursiveDelete(camp.ref) to clear a camp's subcollections, which is an
// admin-SDK-only Firestore method (not available on the client-SDK handle
// that withDb hands back) -- see the NOTE in helpers/emulatorEnv.js on why
// handlers exercising admin-only Firestore surface need makeAdminDb rather
// than withDb. It doesn't touch FieldValue.serverTimestamp() or
// FieldValue.delete(), but recursiveDelete alone is enough to require the
// admin SDK here.
let testEnv, db;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-cleanup-test"));
  db = makeAdminDb("campconnect-cleanup-test");
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function daysAgo(n) {
  return new Date(Date.now() - n * 86400000);
}

test("deletes a camp whose endDate is more than 60 days in the past", async () => {
  await db.doc("camps/old-camp").set({ orgId: "org-1", endDate: daysAgo(61) });
  await db.doc("camps/old-camp/announcements/a1").set({ text: "old" });

  await cleanupExpiredCampsHandler(db);

  expect((await db.doc("camps/old-camp").get()).exists).toBe(false);
  expect((await db.doc("camps/old-camp/announcements/a1").get()).exists).toBe(false);
}, 15000); // recursiveDelete on the camp plus a codes query/batch delete run
// sequentially against the emulator; that many round-trips can occasionally
// exceed jest's 5000ms default (same rationale as the deleteMyAccount owner-
// deletion tests, which do the same recursiveDelete + query/batch cascade).

test("leaves a camp whose endDate is less than 60 days in the past untouched", async () => {
  await db.doc("camps/recent-camp").set({ orgId: "org-1", endDate: daysAgo(30) });

  await cleanupExpiredCampsHandler(db);

  expect((await db.doc("camps/recent-camp").get()).exists).toBe(true);
});

test("leaves a currently-active camp (future endDate) untouched", async () => {
  await db.doc("camps/active-camp").set({ orgId: "org-1", endDate: new Date(Date.now() + 86400000) });

  await cleanupExpiredCampsHandler(db);

  expect((await db.doc("camps/active-camp").get()).exists).toBe(true);
});

test("processes multiple expired camps in one run", async () => {
  await db.doc("camps/expired-1").set({ orgId: "org-1", endDate: daysAgo(90) });
  await db.doc("camps/expired-2").set({ orgId: "org-2", endDate: daysAgo(75) });

  await cleanupExpiredCampsHandler(db);

  expect((await db.doc("camps/expired-1").get()).exists).toBe(false);
  expect((await db.doc("camps/expired-2").get()).exists).toBe(false);
}, 15000); // two full recursiveDelete + codes query/batch cascades run
// sequentially (one per expired camp), so it gets the same longer budget as
// the single-camp deletion test above.

test("processes at most BATCH_LIMIT camps in a single run", async () => {
  const { BATCH_LIMIT } = require("../lib/cleanupExpiredCamps");
  for (let i = 0; i < BATCH_LIMIT + 5; i++) {
    await db.doc(`camps/expired-${i}`).set({ orgId: "org-1", endDate: daysAgo(90) });
  }

  await cleanupExpiredCampsHandler(db);

  const remaining = await db.collection("camps").where("endDate", "<", daysAgo(60)).get();
  expect(remaining.size).toBe(5); // BATCH_LIMIT deleted, 5 left for the next run
}, 60000); // seeds BATCH_LIMIT + 5 (55) docs, then runs a full recursiveDelete
// + codes query/batch cascade for each of the 50 deleted camps sequentially
// -- far more round-trips than the other cascade tests above, so it gets a
// proportionally longer budget rather than the shared 15000ms.
