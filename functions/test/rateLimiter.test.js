const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "campconnect-ratelimiter-test",
    firestore: { host: "127.0.0.1", port: 8080 },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const { checkRateLimit, MAX_ATTEMPTS } = require("../lib/rateLimiter");

// The real firestore.rules (loaded by the emulator for this repo) deny-all
// on `rateLimits/**`, since only the Cloud Function itself (running with
// admin privileges) is meant to touch that collection. Tests therefore run
// each check through `withSecurityRulesDisabled`, which is the supported way
// to get an admin-equivalent Firestore instance in these tests. Note: the
// context handed to the callback is torn down as soon as the callback
// resolves, so `checkRateLimit` must be awaited *inside* the callback rather
// than stashing `ctx.firestore()` in an outer variable for reuse afterward.
function withDb(fn) {
  return testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

test("allows the first MAX_ATTEMPTS calls within the window", async () => {
  await withDb(async (db) => {
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      expect(await checkRateLimit(db, "test-key-1")).toBe(true);
    }
  });
});

test("rejects the call after MAX_ATTEMPTS within the window", async () => {
  await withDb(async (db) => {
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await checkRateLimit(db, "test-key-2");
    }
    expect(await checkRateLimit(db, "test-key-2")).toBe(false);
  });
});

test("different keys have independent limits", async () => {
  await withDb(async (db) => {
    for (let i = 0; i < MAX_ATTEMPTS; i++) {
      await checkRateLimit(db, "test-key-3a");
    }
    expect(await checkRateLimit(db, "test-key-3a")).toBe(false);
    expect(await checkRateLimit(db, "test-key-3b")).toBe(true);
  });
});
