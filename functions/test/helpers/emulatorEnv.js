const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

/**
 * NOTE on withSecurityRulesDisabled: R2 Task 4's rateLimiter.test.js discovered
 * (and this suite's implementer independently reproduced) that the
 * RulesTestContext handed to withSecurityRulesDisabled's callback is torn down
 * the instant that callback resolves. Stashing `ctx.firestore()` in an outer
 * variable and reusing it in a *later*, separate withSecurityRulesDisabled
 * call (or after the callback that created it has returned) throws
 * "FirebaseError: The client has already been terminated" on every operation
 * -- even the very first one attempted afterward.
 *
 * The fix: never let a caller stash `db` for later, independent use. Instead,
 * hand back a `withDb(fn)` helper that opens a *fresh* rules-disabled context
 * per invocation and runs `fn(db)` inside it, so the Firestore handle is only
 * ever touched while its owning context is alive. Multiple operations that
 * must share one live `db` (e.g. two concurrent handler calls racing for the
 * same document, or a handler that internally does more than one Firestore
 * call) simply need to happen inside the *same* withDb(...) invocation.
 *
 * NOTE on withDb's db being a CLIENT SDK handle: `ctx.firestore()` (from
 * `@firebase/rules-unit-testing`) always returns a client-SDK Firestore
 * instance, never the admin SDK. That's fine for handlers that only read/
 * write plain data, but `functions/lib/claimCampCode.js` (like the other
 * extracted handlers) is production code that imports
 * `FieldValue` from `firebase-admin/firestore` and writes
 * `FieldValue.serverTimestamp()` in its transaction. The admin SDK's
 * serverTimestamp sentinel (`ServerTimestampTransform`) and the client SDK's
 * (`ServerTimestampFieldValueImpl`) are different classes; a client-SDK
 * transaction commit rejects the admin one with "Unsupported field value: a
 * custom ServerTimestampTransform object". This is exactly what production
 * passes these handlers (index.js calls them with `getFirestore()` from
 * `firebase-admin/firestore`), so testing them through the client SDK doesn't
 * match reality and deterministically fails on any code path that reaches
 * that write (see makeAdminDb below for the fix).
 */
async function makeTestEnv(projectId) {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8080 },
  });

  function withDb(fn) {
    return testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
  }

  return { testEnv, withDb };
}

/**
 * Returns an admin-SDK Firestore instance pointed at the same Firestore
 * emulator, for testing handlers extracted from functions/index.js exactly
 * as production calls them (production always injects `getFirestore()` from
 * `firebase-admin/firestore`, never a client-SDK instance -- see index.js).
 * This sidesteps the ServerTimestampTransform incompatibility described
 * above: since both the handler and this test db are the same SDK, the
 * transform sentinel round-trips correctly.
 *
 * Security rules don't apply to the admin SDK at all (by design -- it's a
 * trusted server context), so there is no "rules disabled" concept here;
 * unlike withDb, the returned db is safe to reuse across calls/tests as long
 * as `testEnv.clearFirestore()` is used between tests to reset state.
 */
function makeAdminDb(projectId) {
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  // eslint-disable-next-line global-require
  const admin = require("firebase-admin");
  const app = admin.initializeApp(
    { projectId },
    `admin-test-${projectId}-${Date.now()}`
  );
  // eslint-disable-next-line global-require
  const { getFirestore } = require("firebase-admin/firestore");
  return getFirestore(app);
}

/**
 * Returns an Auth Admin SDK instance (`admin.auth()`) backed by the
 * `[DEFAULT]` Firebase app, initializing that app if it doesn't exist yet.
 *
 * This exists because `makeAdminDb` above initializes its own *uniquely
 * named* admin app (e.g. `admin-test-<projectId>-<timestamp>`) for Firestore
 * access, which means `admin.apps` is already non-empty by the time a test
 * needs Auth access too. A naive `if (!admin.apps.length) admin.initializeApp(...)`
 * guard is therefore a no-op in that case -- the `[DEFAULT]` app never gets
 * created, and a later no-arg `admin.auth()` call throws "The default
 * Firebase app does not exist." The fix is to explicitly look for an app
 * named `[DEFAULT]` (not just check `apps.length`) and only create it if
 * that specific one is missing.
 */
function makeAuthAdmin(projectId) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
  // eslint-disable-next-line global-require
  const admin = require("firebase-admin");
  const defaultApp = admin.apps.find((a) => a.name === "[DEFAULT]") ||
    admin.initializeApp({ projectId });
  return admin.auth(defaultApp);
}

/**
 * Deletes every Firebase Admin app this process has initialized (the
 * `[DEFAULT]` app from makeAuthAdmin, plus any uniquely-named apps from
 * makeAdminDb), so their emulator connections don't keep the process alive
 * -- without this, jest reports "did not exit one second after the test run
 * has completed".
 */
async function cleanupAdminApps() {
  // eslint-disable-next-line global-require
  const admin = require("firebase-admin");
  await Promise.all(admin.apps.map((app) => app.delete()));
}

module.exports = { makeTestEnv, makeAdminDb, makeAuthAdmin, cleanupAdminApps };
