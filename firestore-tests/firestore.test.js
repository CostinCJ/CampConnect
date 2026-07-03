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
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test("smoke: rules file loads and default-deny works", async () => {
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(anon.collection("random").doc("x").get());
});

// Helper to seed docs bypassing rules.
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

const guideUid = "guide-1";
const otherGuideUid = "guide-2";
const kidUid = "kid-1";

test("config/app is NOT readable by anyone (invite code is secret)", async () => {
  await seed(async (db) => {
    await db.doc("config/app").set({ guideInviteCode: "SECRET" });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertFails(anon.doc("config/app").get());
  await assertFails(kid.doc("config/app").get());
});

test("users cannot create their own profile doc (server-only)", async () => {
  const someone = testEnv.authenticatedContext("attacker-1").firestore();
  await assertFails(
    someone.doc("users/attacker-1").set({ role: "guide" })
  );
});

test("users cannot change their own role (only campId is updatable)", async () => {
  await seed(async (db) => {
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("users/" + guideUid).set({ role: "guide" });
  });
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  const guide = testEnv.authenticatedContext(guideUid).firestore();
  // Escalation attempt: denied.
  await assertFails(kid.doc("users/" + kidUid).update({ role: "guide" }));
  // Legit: a guide switching active camp updates ONLY campId.
  await assertSucceeds(guide.doc("users/" + guideUid).update({ campId: "camp-9" }));
});

test("a user can read their own doc but not another user's", async () => {
  await seed(async (db) => {
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("users/" + guideUid).set({ role: "guide" });
  });
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertSucceeds(kid.doc("users/" + kidUid).get());
  await assertFails(kid.doc("users/" + guideUid).get());
});

test("only the creating guide can modify a camp", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ createdBy: guideUid, name: "C" });
    await db.doc("users/" + guideUid).set({ role: "guide" });
    await db.doc("users/" + otherGuideUid).set({ role: "guide" });
  });
  const owner = testEnv.authenticatedContext(guideUid).firestore();
  const other = testEnv.authenticatedContext(otherGuideUid).firestore();
  await assertSucceeds(owner.doc("camps/camp-1").get());
  await assertFails(other.doc("camps/camp-1").update({ name: "hacked" }));
  await assertSucceeds(owner.doc("camps/camp-1").update({ name: "ok" }));
});

test("codes: unreadable by kids/anon, manageable by guides", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1/codes/CAMP-ABCD").set({ team: "red", used: false });
    await db.doc("users/" + guideUid).set({ role: "guide" });
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  const guide = testEnv.authenticatedContext(guideUid).firestore();
  await assertFails(anon.doc("camps/camp-1/codes/CAMP-ABCD").get());
  await assertFails(kid.doc("camps/camp-1/codes/CAMP-ABCD").get());
  await assertSucceeds(guide.doc("camps/camp-1/codes/CAMP-ABCD").get());
});

test("teams: readable by a camp member, writable only by a guide", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ createdBy: guideUid, name: "C" });
    await db.doc("users/" + guideUid).set({ role: "guide", campId: "camp-1" });
    await db.doc("users/" + kidUid).set({ role: "kid", campId: "camp-1" });
    await db.doc("camps/camp-1/teams/red").set({ points: 0 });
  });
  const guide = testEnv.authenticatedContext(guideUid).firestore();
  const kid = testEnv.authenticatedContext(kidUid).firestore();
  await assertSucceeds(kid.doc("camps/camp-1/teams/red").get());
  await assertFails(kid.doc("camps/camp-1/teams/red").update({ points: 999 }));
  await assertSucceeds(guide.doc("camps/camp-1/teams/red").update({ points: 5 }));
});
