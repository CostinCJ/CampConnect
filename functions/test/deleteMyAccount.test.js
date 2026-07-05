const { makeTestEnv, makeAdminDb, makeAuthAdmin, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { deleteMyAccountHandler } = require("../lib/deleteMyAccount");

// deleteMyAccountHandler (functions/lib/deleteMyAccount.js) releases claimed
// codes with a db.batch() commit that writes FieldValue.delete() (an
// admin-SDK-only sentinel), exactly like claimCampCodeHandler and
// registerGuideHandler -- see the NOTE in helpers/emulatorEnv.js on why that
// requires the admin-SDK db from makeAdminDb rather than withDb's client-SDK
// handle.
let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-deleteaccount-test"));
  db = makeAdminDb("campconnect-deleteaccount-test");
  authAdmin = makeAuthAdmin("campconnect-deleteaccount-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

async function seedOrgWithTwoCamps(ownerUid) {
  await db.doc(`organizations/org-1`).set({ name: "Org", ownerUid });
  await db.doc(`users/${ownerUid}`).set({ role: "guide", orgId: "org-1" });
  await db.doc(`camps/camp-1`).set({ orgId: "org-1", name: "Camp A" });
  await db.doc(`camps/camp-2`).set({ orgId: "org-1", name: "Camp B" });
  await db.doc(`codes/CAMP-AAAA`).set({ campId: "camp-1", orgId: "org-1", used: false });
  await db.doc(`codes/CAMP-BBBB`).set({ campId: "camp-2", orgId: "org-1", used: true, usedBy: "kid-1" });
}

test("owner deletion cascades: both camps, both codes, and the org doc are gone", async () => {
  const owner = await authAdmin.createUser({ email: "owner@example.com", password: "correcthorsebattery" });
  await seedOrgWithTwoCamps(owner.uid);

  await deleteMyAccountHandler(db, authAdmin, { uid: owner.uid });

  expect((await db.doc("camps/camp-1").get()).exists).toBe(false);
  expect((await db.doc("camps/camp-2").get()).exists).toBe(false);
  expect((await db.doc("organizations/org-1").get()).exists).toBe(false);
  expect((await db.doc("users/" + owner.uid).get()).exists).toBe(false);
  await expect(authAdmin.getUser(owner.uid)).rejects.toThrow();
}, 15000); // owner deletion runs two recursiveDelete calls plus a code query/batch
// per camp and a final org recursiveDelete, all sequentially against the
// emulator; that many round-trips can occasionally exceed jest's 5000ms default.

test("owner deletion releases every code across every deleted camp", async () => {
  const owner = await authAdmin.createUser({ email: "owner2@example.com", password: "correcthorsebattery" });
  await seedOrgWithTwoCamps(owner.uid);

  await deleteMyAccountHandler(db, authAdmin, { uid: owner.uid });

  expect((await db.doc("codes/CAMP-AAAA").get()).exists).toBe(false);
  expect((await db.doc("codes/CAMP-BBBB").get()).exists).toBe(false);
}, 15000); // same sequential recursiveDelete/query/batch cascade as the test above,
// so it gets the same longer budget against the emulator.

test("non-owner guide deletion leaves the org and its camps fully intact", async () => {
  const owner = await authAdmin.createUser({ email: "owner3@example.com", password: "correcthorsebattery" });
  const member = await authAdmin.createUser({ email: "member@example.com", password: "correcthorsebattery" });
  await seedOrgWithTwoCamps(owner.uid);
  await db.doc(`users/${member.uid}`).set({ role: "guide", orgId: "org-1" });

  await deleteMyAccountHandler(db, authAdmin, { uid: member.uid });

  expect((await db.doc("organizations/org-1").get()).exists).toBe(true);
  expect((await db.doc("camps/camp-1").get()).exists).toBe(true);
  expect((await db.doc("users/" + member.uid).get()).exists).toBe(false);
  await expect(authAdmin.getUser(member.uid)).rejects.toThrow();
});

test("a kid deleting their account removes their profile and does not affect their claimed code's camp", async () => {
  await db.doc(`camps/camp-3`).set({ orgId: "org-2", name: "Camp C" });
  const kid = await authAdmin.createUser({});
  await db.doc(`users/${kid.uid}`).set({ role: "kid", campId: "camp-3", orgId: "org-2" });

  await deleteMyAccountHandler(db, authAdmin, { uid: kid.uid });

  expect((await db.doc("users/" + kid.uid).get()).exists).toBe(false);
  expect((await db.doc("camps/camp-3").get()).exists).toBe(true);
});
