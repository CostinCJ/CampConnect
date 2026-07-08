const { makeTestEnv, makeAdminDb, makeAdminBucket, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { deleteCampHandler } = require("../lib/deleteCamp");

// deleteCampHandler (functions/lib/deleteCamp.js) delegates to
// deleteCampCascade, which calls db.recursiveDelete plus a codes query/batch
// delete and (optionally) bucket.deleteFiles — all admin-SDK surface, so it
// needs makeAdminDb rather than withDb's client handle (see the NOTE in
// helpers/emulatorEnv.js).
let testEnv, db;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-deletecamp-test"));
  db = makeAdminDb("campconnect-deletecamp-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const guide = (orgId) => ({ uid: "guide-1", token: { role: "guide", orgId } });

async function seedCamp() {
  await db.doc("camps/camp-1").set({ orgId: "org-1", name: "Camp A" });
  await db.doc("camps/camp-1/announcements/a1").set({ title: "x" });
  await db.doc("camps/camp-1/teams/red").set({ points: 0 });
  await db.doc("codes/CAMP-AAAA").set({ campId: "camp-1", orgId: "org-1", used: false });
  await db.doc("codes/CAMP-BBBB").set({ campId: "camp-2", orgId: "org-1", used: false });
}

test("a guide of the camp's org deletes the camp, its subcollections, and its codes", async () => {
  await seedCamp();

  await deleteCampHandler(db, guide("org-1"), { campId: "camp-1" });

  expect((await db.doc("camps/camp-1").get()).exists).toBe(false);
  expect((await db.doc("camps/camp-1/announcements/a1").get()).exists).toBe(false);
  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(false);
  // Its top-level code is gone...
  expect((await db.doc("codes/CAMP-AAAA").get()).exists).toBe(false);
  // ...but a different camp's code is untouched.
  expect((await db.doc("codes/CAMP-BBBB").get()).exists).toBe(true);
}, 15000);

test("a guide of another org cannot delete the camp", async () => {
  await seedCamp();

  await expect(
    deleteCampHandler(db, guide("org-2"), { campId: "camp-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });

  expect((await db.doc("camps/camp-1").get()).exists).toBe(true);
});

test("a non-guide caller is rejected", async () => {
  await expect(
    deleteCampHandler(db, { uid: "kid-1", token: { role: "kid" } }, { campId: "camp-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("an unauthenticated caller is rejected", async () => {
  await expect(
    deleteCampHandler(db, null, { campId: "camp-1" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});

test("a missing campId is rejected", async () => {
  await expect(
    deleteCampHandler(db, guide("org-1"), {})
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("deleting an already-gone camp resolves as an idempotent no-op", async () => {
  await expect(
    deleteCampHandler(db, guide("org-1"), { campId: "does-not-exist" })
  ).resolves.toMatchObject({ deleted: true });
});

test("deletes kid profiles pointing at the camp, leaving other camps' kids untouched", async () => {
  await seedCamp();
  await db.doc("camps/camp-2").set({ orgId: "org-1", name: "Camp B" });
  await db.doc("users/kid-1").set({ role: "kid", campId: "camp-1", orgId: "org-1" });
  await db.doc("users/kid-2").set({ role: "kid", campId: "camp-2", orgId: "org-1" });

  await deleteCampHandler(db, guide("org-1"), { campId: "camp-1" });

  expect((await db.doc("users/kid-1").get()).exists).toBe(false);
  expect((await db.doc("users/kid-2").get()).exists).toBe(true);
});

test("deletes the camp's Storage photos alongside its Firestore documents", async () => {
  const bucket = makeAdminBucket("campconnect-deletecamp-test");
  await db.doc("camps/camp-1").set({ orgId: "org-1", name: "Camp A" });
  const file = bucket.file("camps/camp-1/sessionLocations/loc-1/group_photo.jpg");
  await file.save(Buffer.from("fake image bytes"), { contentType: "image/jpeg" });

  await deleteCampHandler(db, guide("org-1"), { campId: "camp-1" }, bucket);

  expect((await file.exists())[0]).toBe(false);
  expect((await db.doc("camps/camp-1").get()).exists).toBe(false);
}, 15000);
