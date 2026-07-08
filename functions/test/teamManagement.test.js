const { makeTestEnv, makeAdminDb, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { deleteTeamHandler } = require("../lib/teamManagement");

let testEnv, db;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-teammgmt-test"));
  db = makeAdminDb("campconnect-teammgmt-test");
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
  await db.doc("camps/camp-1/teams/red").set({ name: "Roșu", colorHex: "#E53935", points: 0 });
  await db.doc("camps/camp-1/teams/blue").set({ name: "Albastru", colorHex: "#1E88E5", points: 0 });
}

test("a guide deletes an empty team", async () => {
  await seedCamp();

  const result = await deleteTeamHandler(db, guide("org-1"), { campId: "camp-1", teamId: "red" });

  expect(result.deleted).toBe(true);
  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(false);
});

test("deleting a team with kids and no reassignment target throws team-in-use with the kid count", async () => {
  await seedCamp();
  await db.doc("users/kid-1").set({ role: "kid", campId: "camp-1", team: "red" });
  await db.doc("users/kid-2").set({ role: "kid", campId: "camp-1", team: "red" });
  // A kid on a different team must not be counted.
  await db.doc("users/kid-3").set({ role: "kid", campId: "camp-1", team: "blue" });

  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "camp-1", teamId: "red" })
  ).rejects.toMatchObject({ code: "failed-precondition", message: "team-in-use", details: { kidCount: 2 } });

  // Team must still exist — nothing was deleted.
  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(true);
});

test("deleting a team with kids and a reassignment target moves the kids then deletes the team", async () => {
  await seedCamp();
  await db.doc("users/kid-1").set({ role: "kid", campId: "camp-1", team: "red" });
  await db.doc("users/kid-2").set({ role: "kid", campId: "camp-1", team: "red" });

  const result = await deleteTeamHandler(db, guide("org-1"), {
    campId: "camp-1",
    teamId: "red",
    reassignToTeamId: "blue",
  });

  expect(result.deleted).toBe(true);
  expect(result.reassigned).toBe(2);
  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(false);
  expect((await db.doc("users/kid-1").get()).data().team).toBe("blue");
  expect((await db.doc("users/kid-2").get()).data().team).toBe("blue");
});

test("reassigning to the same team is rejected", async () => {
  await seedCamp();
  await db.doc("users/kid-1").set({ role: "kid", campId: "camp-1", team: "red" });

  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "camp-1", teamId: "red", reassignToTeamId: "red" })
  ).rejects.toMatchObject({ code: "invalid-argument" });

  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(true);
});

test("reassigning to a team that doesn't exist is rejected", async () => {
  await seedCamp();
  await db.doc("users/kid-1").set({ role: "kid", campId: "camp-1", team: "red" });

  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "camp-1", teamId: "red", reassignToTeamId: "ghost" })
  ).rejects.toMatchObject({ code: "invalid-argument" });

  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(true);
});

test("a guide of another org cannot delete the team", async () => {
  await seedCamp();

  await expect(
    deleteTeamHandler(db, guide("org-2"), { campId: "camp-1", teamId: "red" })
  ).rejects.toMatchObject({ code: "permission-denied" });

  expect((await db.doc("camps/camp-1/teams/red").get()).exists).toBe(true);
});

test("a non-guide caller is rejected", async () => {
  await seedCamp();
  await expect(
    deleteTeamHandler(db, { uid: "kid-1", token: { role: "kid" } }, { campId: "camp-1", teamId: "red" })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("an unauthenticated caller is rejected", async () => {
  await expect(
    deleteTeamHandler(db, null, { campId: "camp-1", teamId: "red" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});

test("a missing campId is rejected", async () => {
  await expect(
    deleteTeamHandler(db, guide("org-1"), { teamId: "red" })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("a missing teamId is rejected", async () => {
  await seedCamp();
  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "camp-1" })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("deleting an already-gone team resolves as an idempotent no-op", async () => {
  await seedCamp();
  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "camp-1", teamId: "does-not-exist" })
  ).resolves.toMatchObject({ deleted: true });
});

test("deleting a team in a camp that doesn't exist throws not-found", async () => {
  await expect(
    deleteTeamHandler(db, guide("org-1"), { campId: "does-not-exist", teamId: "red" })
  ).rejects.toMatchObject({ code: "not-found" });
});
