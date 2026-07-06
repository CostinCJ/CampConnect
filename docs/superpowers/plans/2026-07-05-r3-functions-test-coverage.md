# R3 — Cloud Functions Test Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `functions/index.js` (the most security/data-integrity-critical file in the app —
`registerGuide`, `claimCampCode`, `deleteMyAccount`, `cleanupExpiredCamps`) real automated test
coverage, closing the two QA-CRITICAL findings (zero coverage; `claimCampCode` atomicity unproven)
and the QA-HIGH cascade-deletion gap.

**Architecture:** Extract each callable's business logic out of the `onCall`/`onSchedule` wiring
into a plain, dependency-injected function in `functions/lib/`. This makes the logic directly unit-
testable against the Firestore/Auth emulators without fighting App Check enforcement or the HTTPS
callable transport layer — `functions/index.js` becomes a thin wiring layer that just supplies the
real `getFirestore()`/`getAuth()` and forwards `request.auth`/`request.data`.

**Tech Stack:** Node 20, Jest, `@firebase/rules-unit-testing` (already a dependency via
`firestore-tests/` — added locally to `functions/` too), Firebase emulators (Firestore + Auth).

**Branch:** `remediation/r3-functions-test-coverage`.

**Depends on:** R2 (this plan tests the App-Check-and-rate-limit-hardened versions of
`registerGuide`/`claimCampCode` — the extraction in Task 1 assumes R2's `{ enforceAppCheck: true }`
wiring and rate-limiter calls already exist in `functions/index.js`).

---

### Task 1: Extract callable business logic into testable modules

**Files:**
- Create: `functions/lib/claimCampCode.js`
- Create: `functions/lib/registerGuide.js`
- Create: `functions/lib/deleteMyAccount.js`
- Create: `functions/lib/cleanupExpiredCamps.js`
- Modify: `functions/index.js` (all four export definitions become thin wrappers)

This is a mechanical, behavior-preserving refactor — the goal is to move existing logic verbatim,
not rewrite it. Do this one function at a time, verifying after each move that nothing broke,
rather than moving all four and debugging at the end.

- [ ] **Step 1: Read the current `claimCampCode` implementation in full**

Open `functions/index.js` and read the entire `exports.claimCampCode = onCall(...)` block
(including the rate-limiter call added in R2 Task 4) end to end before touching anything.

- [ ] **Step 2: Move it to `functions/lib/claimCampCode.js`, changing only the signature**

Create `functions/lib/claimCampCode.js` containing the exact existing handler body, with these
mechanical substitutions only:
- Function signature becomes `async function claimCampCodeHandler(db, auth, data) { ... }`
- Every `request.auth` reference in the body becomes `auth`
- Every `request.data` reference in the body becomes `data`
- Every in-body call to `getFirestore()` is removed; use the injected `db` parameter instead
- The R2 rate-limiter call (`checkRateLimit(getFirestore(), ...)`) becomes
  `checkRateLimit(db, ...)`, and its `require("./rateLimiter")` import moves to the top of this
  new file
- Add `const { HttpsError } = require("firebase-functions/v2/https");` and
  `const { FieldValue } = require("firebase-admin/firestore");` at the top (whichever of these the
  original body actually used — check the body for `FieldValue.serverTimestamp()` and similar)
- End the file with `module.exports = { claimCampCodeHandler };`

- [ ] **Step 3: Replace the export in `functions/index.js` with a thin wrapper**

```javascript
const { claimCampCodeHandler } = require("./lib/claimCampCode");

exports.claimCampCode = onCall({ enforceAppCheck: true }, (request) =>
  claimCampCodeHandler(getFirestore(), request.auth, request.data)
);
```

- [ ] **Step 4: Verify nothing broke**

Run:
```bash
cd /d/CampConnect/functions && node -c index.js && node -c lib/claimCampCode.js
cd /d/CampConnect && firebase emulators:start --only functions,firestore,auth
```
Manually exercise `claimCampCode` once against the emulator (same manual smoke test the original
Phase 2 plan used) and confirm it still returns `{ campId, team, displayName }` for a valid code.

- [ ] **Step 5: Repeat Steps 1-4 for `registerGuide`**

Same pattern → `functions/lib/registerGuide.js`, exporting
`async function registerGuideHandler(db, authAdmin, data) { ... }` (this one also needs the Auth
Admin SDK for `getAuth().createUser(...)` / custom-claims calls, so inject that too, e.g.
`registerGuideHandler(getFirestore(), getAuth(), request.data)` from the wrapper).

- [ ] **Step 6: Repeat Steps 1-4 for `deleteMyAccount`**

Same pattern → `functions/lib/deleteMyAccount.js`, exporting
`async function deleteMyAccountHandler(db, authAdmin, auth) { ... }` (no `data` needed — this
callable only uses `request.auth`).

- [ ] **Step 7: Repeat Steps 1-4 for `cleanupExpiredCamps`**

Same pattern → `functions/lib/cleanupExpiredCamps.js`, exporting
`async function cleanupExpiredCampsHandler(db) { ... }`. Update the wrapper:
```javascript
const { cleanupExpiredCampsHandler } = require("./lib/cleanupExpiredCamps");

exports.cleanupExpiredCamps = onSchedule("every 24 hours", () =>
  cleanupExpiredCampsHandler(getFirestore())
);
```

- [ ] **Step 8: Full regression check**

Run:
```bash
cd /d/CampConnect/functions && node -c index.js && npx eslint index.js lib/
cd /d/CampConnect/firestore-tests && npm test
```
Expected: no syntax/lint errors; the existing 24 rules tests still pass unchanged (this refactor
doesn't touch rules, only where the handler code lives).

- [ ] **Step 9: Commit**

```bash
cd /d/CampConnect
git add functions/lib/claimCampCode.js functions/lib/registerGuide.js functions/lib/deleteMyAccount.js functions/lib/cleanupExpiredCamps.js functions/index.js
git commit -m "refactor: extract callable business logic into functions/lib/ for testability"
```

---

### Task 2: `claimCampCode` — concurrency and edge-case tests

**Files:**
- Create: `functions/test/claimCampCode.test.js`
- Create: `functions/test/helpers/emulatorEnv.js`

- [ ] **Step 1: Create a shared emulator-environment helper**

Create `functions/test/helpers/emulatorEnv.js`:
```javascript
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

async function makeTestEnv(projectId) {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8080 },
  });
  let db;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    db = ctx.firestore();
  });
  return { testEnv, db };
}

module.exports = { makeTestEnv };
```
(Rules are disabled for these tests deliberately — this suite tests the Cloud Function's own
business-logic guarantees, e.g. transactional atomicity, independent of Firestore rules, which are
separately and thoroughly covered by `firestore-tests/`.)

- [ ] **Step 2: Write the failing concurrency test**

Create `functions/test/claimCampCode.test.js`:
```javascript
const { makeTestEnv } = require("./helpers/emulatorEnv");
const { claimCampCodeHandler } = require("../lib/claimCampCode");

let testEnv, db;

beforeAll(async () => {
  ({ testEnv, db } = await makeTestEnv("campconnect-claimcode-test"));
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

async function seedCode(code, overrides = {}) {
  await db.doc(`codes/${code}`).set({
    campId: "camp-1",
    team: "red",
    displayName: "Campist #1",
    used: false,
    ...overrides,
  });
  await db.doc("camps/camp-1").set({
    createdBy: "guide-1",
    endDate: { toDate: () => new Date(Date.now() + 86400000) }, // tomorrow
    ...overrides.camp,
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
});

test("claiming an already-used code throws already-exists", async () => {
  await seedCode("CAMP-USED", { used: true, usedBy: "kid-a" });
  await expect(
    claimCampCodeHandler(db, { uid: "kid-b" }, { code: "CAMP-USED" })
  ).rejects.toMatchObject({ code: "already-exists" });
});

test("claiming a code for an ended camp throws failed-precondition", async () => {
  await db.doc("codes/CAMP-OLD").set({
    campId: "camp-old", team: "red", displayName: "X", used: false,
  });
  await db.doc("camps/camp-old").set({
    createdBy: "guide-1",
    endDate: { toDate: () => new Date(Date.now() - 86400000) }, // yesterday
  });
  await expect(
    claimCampCodeHandler(db, { uid: "kid-a" }, { code: "CAMP-OLD" })
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
```

- [ ] **Step 3: Add the emulator-backed test script**

Add to `functions/package.json` scripts:
```json
    "test:functions": "firebase emulators:exec --only firestore --project campconnect-claimcode-test \"jest test/claimCampCode.test.js --runInBand\""
```

- [ ] **Step 4: Run and confirm current behavior**

Run:
```bash
cd /d/CampConnect/functions && npm run test:functions
```
Expected: all 6 tests PASS against the current (already-correct, per the security review)
transactional implementation. If the concurrency test is flaky (rare but possible under real
transaction contention), that flakiness is itself meaningful signal — investigate before assuming
it's a test bug.

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add functions/test/claimCampCode.test.js functions/test/helpers/emulatorEnv.js functions/package.json
git commit -m "test: add concurrency and edge-case coverage for claimCampCode"
```

---

### Task 3: `registerGuide` — invite-code and account-creation tests

**Files:**
- Create: `functions/test/registerGuide.test.js`

- [ ] **Step 1: Write the tests**

Create `functions/test/registerGuide.test.js` (uses the real Auth emulator via
`getAuth()`/`admin.auth()` pointed at `FIREBASE_AUTH_EMULATOR_HOST` — set that env var before
requiring `firebase-admin` at the top of this file, mirroring the pattern in
`functions/test/helpers/emulatorEnv.js`):
```javascript
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv } = require("./helpers/emulatorEnv");
const { registerGuideHandler } = require("../lib/registerGuide");
const admin = require("firebase-admin");

let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv, db } = await makeTestEnv("campconnect-registerguide-test"));
  if (!admin.apps.length) admin.initializeApp({ projectId: "campconnect-registerguide-test" });
  authAdmin = admin.auth();
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

test("creating a new org with a valid new-org request creates an Auth user with guide claims", async () => {
  const result = await registerGuideHandler(db, authAdmin, {
    email: "guide1@example.com",
    password: "correcthorsebattery",
    displayName: "Guide One",
    newOrgName: "Camp Falcon",
  });
  expect(result.ok).toBe(true);
  const user = await authAdmin.getUserByEmail("guide1@example.com");
  expect(user.customClaims.role).toBe("guide");
  expect(user.customClaims.orgId).toBeTruthy();
});

test("joining with an invalid org invite code throws permission-denied", async () => {
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "guide2@example.com",
      password: "correcthorsebattery",
      displayName: "Guide Two",
      joinOrgCode: "NOT-A-REAL-CODE",
    })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("registering with an already-used email throws already-exists and leaves no orphan org", async () => {
  await registerGuideHandler(db, authAdmin, {
    email: "dupe@example.com",
    password: "correcthorsebattery",
    displayName: "First",
    newOrgName: "Camp One",
  });
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "dupe@example.com",
      password: "correcthorsebattery",
      displayName: "Second",
      newOrgName: "Camp Two",
    })
  ).rejects.toMatchObject({ code: "already-exists" });

  const orgsSnap = await db.collection("organizations").where("name", "==", "Camp Two").get();
  expect(orgsSnap.empty).toBe(true);
});

test("registering with a weak password throws invalid-argument", async () => {
  await expect(
    registerGuideHandler(db, authAdmin, {
      email: "weak@example.com",
      password: "123",
      displayName: "Weak",
      newOrgName: "Camp Weak",
    })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});
```

- [ ] **Step 2: Add the emulator-backed test script**

Add to `functions/package.json` scripts:
```json
    "test:register": "firebase emulators:exec --only firestore,auth --project campconnect-registerguide-test \"jest test/registerGuide.test.js --runInBand\""
```

- [ ] **Step 3: Run and reconcile against actual behavior**

Run:
```bash
cd /d/CampConnect/functions && npm run test:register
```
If any test fails because the actual `registerGuide` request shape differs from what's assumed here
(e.g. a different field name than `newOrgName`/`joinOrgCode`, or a different error code than
`invalid-argument` for a weak password), that's the extraction in Task 1 surfacing the *real*
current contract — adjust the test to match the real behavior you just extracted verbatim, do not
adjust the extracted handler to match a guessed test.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add functions/test/registerGuide.test.js functions/package.json
git commit -m "test: add invite-code and account-creation coverage for registerGuide"
```

---

### Task 4: `deleteMyAccount` — cascade-deletion tests

**Files:**
- Create: `functions/test/deleteMyAccount.test.js`

- [ ] **Step 1: Write the tests**

Create `functions/test/deleteMyAccount.test.js`:
```javascript
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv } = require("./helpers/emulatorEnv");
const { deleteMyAccountHandler } = require("../lib/deleteMyAccount");
const admin = require("firebase-admin");

let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv, db } = await makeTestEnv("campconnect-deleteaccount-test"));
  if (!admin.apps.length) admin.initializeApp({ projectId: "campconnect-deleteaccount-test" });
  authAdmin = admin.auth();
});

afterAll(async () => {
  await testEnv.cleanup();
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
});

test("owner deletion releases every code across every deleted camp", async () => {
  const owner = await authAdmin.createUser({ email: "owner2@example.com", password: "correcthorsebattery" });
  await seedOrgWithTwoCamps(owner.uid);

  await deleteMyAccountHandler(db, authAdmin, { uid: owner.uid });

  expect((await db.doc("codes/CAMP-AAAA").get()).exists).toBe(false);
  expect((await db.doc("codes/CAMP-BBBB").get()).exists).toBe(false);
});

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
```

- [ ] **Step 2: Add the emulator-backed test script**

Add to `functions/package.json` scripts:
```json
    "test:delete": "firebase emulators:exec --only firestore,auth --project campconnect-deleteaccount-test \"jest test/deleteMyAccount.test.js --runInBand\""
```

- [ ] **Step 3: Run and reconcile against actual behavior**

Run:
```bash
cd /d/CampConnect/functions && npm run test:delete
```
As in Task 3 Step 3: if the real field names differ (e.g. the org doc doesn't store `ownerUid`
under that exact key), fix the test to match the real extracted code, not the other way around.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add functions/test/deleteMyAccount.test.js functions/package.json
git commit -m "test: add org-cascade coverage for deleteMyAccount"
```

---

### Task 5: `cleanupExpiredCamps` — scheduled-cleanup tests

**Files:**
- Create: `functions/test/cleanupExpiredCamps.test.js`

- [ ] **Step 1: Write the tests**

Create `functions/test/cleanupExpiredCamps.test.js`:
```javascript
const { makeTestEnv } = require("./helpers/emulatorEnv");
const { cleanupExpiredCampsHandler } = require("../lib/cleanupExpiredCamps");

let testEnv, db;

beforeAll(async () => {
  ({ testEnv, db } = await makeTestEnv("campconnect-cleanup-test"));
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
});

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
});
```

- [ ] **Step 2: Add the emulator-backed test script**

Add to `functions/package.json` scripts:
```json
    "test:cleanup": "firebase emulators:exec --only firestore --project campconnect-cleanup-test \"jest test/cleanupExpiredCamps.test.js --runInBand\""
```

- [ ] **Step 3: Run and reconcile against actual behavior**

Run:
```bash
cd /d/CampConnect/functions && npm run test:cleanup
```
If the real retention window differs from 60 days, or `endDate` isn't stored as a plain
`Timestamp`-compatible value the way these tests assume, adjust the tests to match the real
extracted code.

- [ ] **Step 4: Consolidate all functions test scripts into one `npm test` entry point**

Edit `functions/package.json`'s `test` script (added in R2 Task 1) to run everything R2+R3 added in
one command, so R5's future CI workflow has a single entry point:
```json
    "test": "jest test/inviteCode.test.js && npm run test:rules && npm run test:functions && npm run test:register && npm run test:delete && npm run test:cleanup"
```

- [ ] **Step 5: Run the consolidated suite once, end to end**

Run:
```bash
cd /d/CampConnect/functions && npm test
```
Expected: every sub-suite passes.

- [ ] **Step 6: Commit**

```bash
cd /d/CampConnect
git add functions/test/cleanupExpiredCamps.test.js functions/package.json
git commit -m "test: add scheduled-cleanup coverage for cleanupExpiredCamps; consolidate npm test"
```

---

## Post-phase verification

- [ ] `cd functions && npm test` passes end to end (invite-code, rate-limiter, claimCampCode,
  registerGuide, deleteMyAccount, cleanupExpiredCamps — six suites, one command).
- [ ] `cd firestore-tests && npm test` still passes unchanged (proves the R3 refactor didn't
  regress rules behavior).
- [ ] Update `pubspec.yaml`'s unused `integration_test` dev dependency decision: either remove it
  (nothing in the repo uses it) or note in R4 that it'll be used there — do not leave it silently
  unused after this phase; R4 Task 3 uses `flutter_test`'s widget-testing APIs instead, so if R4
  also doesn't end up using `integration_test`, remove it as a one-line cleanup at the end of R4.
