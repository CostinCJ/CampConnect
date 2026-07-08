const { makeTestEnv, makeAdminDb, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { getOrganizationLogoUrlHandler } = require("../lib/getOrganizationLogoUrl");

let testEnv, db;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-orglogo-test"));
  db = makeAdminDb("campconnect-orglogo-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test("returns the caller org logo URL for a kid profile", async () => {
  await db.doc("users/kid-1").set({
    role: "kid",
    orgId: "org-1",
    campId: "camp-1",
  });
  await db.doc("organizations/org-1").set({
    name: "Camp Falcon",
    ownerUid: "owner-1",
    inviteCode: "SECRETGUIDE",
    logoUrl: "https://example.test/logo.jpg",
  });

  await expect(
    getOrganizationLogoUrlHandler(db, { uid: "kid-1" })
  ).resolves.toEqual({ logoUrl: "https://example.test/logo.jpg" });
});

test("returns an empty URL when the org has no logo", async () => {
  await db.doc("users/guide-1").set({ role: "guide", orgId: "org-1" });
  await db.doc("organizations/org-1").set({
    name: "Camp Falcon",
    ownerUid: "owner-1",
    inviteCode: "SECRETGUIDE",
  });

  await expect(
    getOrganizationLogoUrlHandler(db, { uid: "guide-1" })
  ).resolves.toEqual({ logoUrl: "" });
});

test("returns an empty URL when the caller has no org profile", async () => {
  await db.doc("users/guide-1").set({ role: "guide" });

  await expect(
    getOrganizationLogoUrlHandler(db, { uid: "guide-1" })
  ).resolves.toEqual({ logoUrl: "" });
});

test("unauthenticated callers are rejected", async () => {
  await expect(
    getOrganizationLogoUrlHandler(db, null)
  ).rejects.toMatchObject({ code: "unauthenticated" });
});
