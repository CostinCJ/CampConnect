process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv, makeAdminDb, makeAuthAdmin, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { removeMemberHandler, rotateInviteCodeHandler, joinOrganizationHandler } = require("../lib/orgManagement");
const { CHARSET, CODE_LENGTH } = require("../lib/inviteCode");

let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-orgmgmt-test"));
  db = makeAdminDb("campconnect-orgmgmt-test");
  authAdmin = makeAuthAdmin("campconnect-orgmgmt-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Seeds an org with an owner and one plain guide. The guide also gets a real
// Auth user because removeMemberHandler clears their custom claims.
async function seedOrg({ ownerUid = "owner-1", memberUid = "member-1" } = {}) {
  await db.doc("organizations/org-1").set({
    name: "Camp Falcon", ownerUid, inviteCode: "AAAAAAAAAA",
  });
  await db.doc(`organizations/org-1/members/${ownerUid}`).set({
    role: "owner", displayName: "Owner",
  });
  await db.doc(`organizations/org-1/members/${memberUid}`).set({
    role: "guide", displayName: "Member",
  });
  await db.doc(`users/${ownerUid}`).set({ role: "guide", orgId: "org-1" });
  await db.doc(`users/${memberUid}`).set({
    role: "guide", orgId: "org-1", campId: "camp-1",
  });
  try {
    await authAdmin.createUser({ uid: memberUid, email: `${memberUid}@example.com`, password: "correcthorsebattery" });
  } catch (e) {
    if (e.code !== "auth/uid-already-exists") throw e;
  }
  await authAdmin.setCustomUserClaims(memberUid, { role: "guide", orgId: "org-1" });
}

// --- removeMember ---

test("owner removes a guide: membership deleted, profile org cleared, claims cleared", async () => {
  await seedOrg();
  const result = await removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "member-1" });
  expect(result.ok).toBe(true);

  const member = await db.doc("organizations/org-1/members/member-1").get();
  expect(member.exists).toBe(false);

  const profile = await db.doc("users/member-1").get();
  expect(profile.data().orgId).toBeUndefined();
  expect(profile.data().campId).toBeUndefined();

  const user = await authAdmin.getUser("member-1");
  expect(user.customClaims.orgId).toBeUndefined();
  expect(user.customClaims.role).toBe("guide");
});

test("non-owner guide cannot remove a member", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "member-1" }, { memberUid: "owner-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });

  expect((await db.doc("organizations/org-1/members/owner-1").get()).exists).toBe(true);
});

test("owner cannot remove themself", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "owner-1" })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("unauthenticated removeMember is rejected", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, null, { memberUid: "member-1" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});

test("removing a non-member throws not-found", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "ghost" })
  ).rejects.toMatchObject({ code: "not-found" });
});

test("missing memberUid throws invalid-argument", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, {})
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("removing a member whose Auth user is already gone still succeeds", async () => {
  await seedOrg();
  // Membership + profile exist, but no Auth user: simulates an out-of-band
  // Auth deletion. The claims-strip step must not fail the removal.
  await db.doc("organizations/org-1/members/ghost-2").set({
    role: "guide", displayName: "Ghost",
  });
  await db.doc("users/ghost-2").set({ role: "guide", orgId: "org-1" });

  const result = await removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "ghost-2" });
  expect(result.ok).toBe(true);

  const member = await db.doc("organizations/org-1/members/ghost-2").get();
  expect(member.exists).toBe(false);

  const profile = await db.doc("users/ghost-2").get();
  expect(profile.data().orgId).toBeUndefined();
});

// --- rotateInviteCode ---

test("owner rotates the invite code: new well-formed code stored and returned", async () => {
  await seedOrg();
  const result = await rotateInviteCodeHandler(db, { uid: "owner-1" });
  expect(result.ok).toBe(true);
  expect(result.inviteCode).toHaveLength(CODE_LENGTH);
  expect(result.inviteCode).not.toBe("AAAAAAAAAA");
  for (const ch of result.inviteCode) {
    expect(CHARSET).toContain(ch);
  }

  const org = await db.doc("organizations/org-1").get();
  expect(org.data().inviteCode).toBe(result.inviteCode);
});

test("non-owner cannot rotate the invite code", async () => {
  await seedOrg();
  await expect(
    rotateInviteCodeHandler(db, { uid: "member-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });

  const org = await db.doc("organizations/org-1").get();
  expect(org.data().inviteCode).toBe("AAAAAAAAAA");
});

test("unauthenticated rotateInviteCode is rejected", async () => {
  await expect(
    rotateInviteCodeHandler(db, null)
  ).rejects.toMatchObject({ code: "unauthenticated" });
});

// --- joinOrganization ---

// Seeds a signed-in guide with NO org (the removeMember aftermath shape).
async function seedOrglessGuide(uid = "loner-1") {
  await db.doc(`users/${uid}`).set({ role: "guide", displayName: "Loner" });
  return uid;
}

test("org-less guide joins by invite code: membership, profile orgId, claims", async () => {
  await seedOrg();
  const uid = await seedOrglessGuide();
  try {
    await authAdmin.createUser({ uid, email: `${uid}@example.com`, password: "correcthorsebattery" });
  } catch (e) {
    if (e.code !== "auth/uid-already-exists") throw e;
  }

  const result = await joinOrganizationHandler(db, authAdmin, { uid }, { inviteCode: "AAAAAAAAAA" });
  expect(result.ok).toBe(true);
  expect(result.orgId).toBe("org-1");

  const member = await db.doc(`organizations/org-1/members/${uid}`).get();
  expect(member.exists).toBe(true);
  expect(member.data().role).toBe("guide");
  expect(member.data().joinedAt).toBeTruthy();

  const profile = await db.doc(`users/${uid}`).get();
  expect(profile.data().orgId).toBe("org-1");

  const user = await authAdmin.getUser(uid);
  expect(user.customClaims.orgId).toBe("org-1");
});

test("joining with an invalid code throws permission-denied", async () => {
  await seedOrg();
  const uid = await seedOrglessGuide();
  await expect(
    joinOrganizationHandler(db, authAdmin, { uid }, { inviteCode: "NOPE" })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("a guide already in an org cannot join another", async () => {
  await seedOrg();
  await expect(
    joinOrganizationHandler(db, authAdmin, { uid: "member-1" }, { inviteCode: "AAAAAAAAAA" })
  ).rejects.toMatchObject({ code: "failed-precondition" });
});

test("unauthenticated joinOrganization is rejected", async () => {
  await expect(
    joinOrganizationHandler(db, authAdmin, null, { inviteCode: "AAAAAAAAAA" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});
