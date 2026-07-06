# R5 — DevOps / Infra Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the operational safety net that's currently missing around an otherwise solid
application layer: a dev/staging Firebase project, a CI pipeline that actually runs the test
suites R2-R4 added, Cloud Functions reliability/monitoring config, versioned Firestore indexes, a
documented rollback procedure, backups, billing visibility, and closing the Storage-orphan gap that
also violates the privacy policy's own retention promise.

**Architecture:** No containers/Kubernetes — this stays 100% within the existing Firebase-managed +
GitHub Actions stack. Most tasks are either a GCP/Firebase Console configuration change (documented
step-by-step since there's no CLI/Terraform layer for this project) or a small, testable code change
in `functions/`.

**Tech Stack:** Firebase CLI, GitHub Actions, Google Cloud Console (Firestore, Billing, Monitoring),
`firebase-functions/logger`.

**Branch:** `remediation/r5-devops-infra`.

**Depends on:** R2 + R3 (this phase's CI workflow runs the test suites those phases added — writing
the CI job before those suites exist would just mean editing it again).

---

### Task 1: Create a second Firebase project for development

**Files:**
- Modify: `.firebaserc`
- Modify: `README.md` (document the topology)

- [ ] **Step 1: Create the project — STOP AND CONFIRM WITH THE USER FIRST (creates billable cloud infra)**

```bash
firebase projects:create campconnect-dev --display-name "CampConnect Dev"
```
(Spark/free plan is fine for development-scale usage; upgrade to Blaze only if Cloud Functions
testing against this project is needed — the existing `firestore-tests`/`functions` emulator-based
tests don't need a live project at all, so this is specifically for manual app-against-real-backend
testing, not for the automated test suites.)

- [ ] **Step 2: Add it as a `.firebaserc` alias**

```bash
firebase use --add
```
When prompted, select `campconnect-dev` and name the alias `dev`. This appends a `dev` entry
alongside the existing `default` alias in `.firebaserc`.

- [ ] **Step 3: Generate a second Firebase config for the Flutter app**

```bash
flutterfire configure --project=campconnect-dev
```
Follow the prompts to write a dev-specific `lib/firebase_options.dart` variant — since this file is
gitignored (confirmed by the security review), coordinate how you switch between dev/prod configs
locally (e.g., keep both `firebase_options_dev.dart` and `firebase_options_prod.dart` untracked
locally, or use Flutter build flavors — pick whichever the user prefers to maintain going forward;
document the choice in Step 5).

- [ ] **Step 4: Document the topology in README**

Add a short paragraph to `README.md`'s "Configuration" section:
```markdown
### Firebase project topology

Two Firebase projects exist: `camp-connect-4644c` (production, alias `default`) and
`campconnect-dev` (development, alias `dev`). Day-to-day development and manual testing should
target `dev` (`firebase use dev`); only deploy to `default` deliberately, with the user's explicit
go-ahead. The automated test suites (`flutter test`, `functions/`'s Jest suites, `firestore-tests/`)
all run against the local emulators and don't depend on either live project.
```

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add .firebaserc README.md
git commit -m "chore: add a dev Firebase project alongside production"
```

---

### Task 2: GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - run: flutter pub get
      - run: flutter gen-l10n
      - run: flutter analyze
      - run: flutter test

  functions-and-rules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - run: npm install -g firebase-tools
      - name: Cloud Functions tests
        working-directory: functions
        run: |
          npm ci
          npm test
      - name: Firestore/Storage rules tests
        working-directory: firestore-tests
        run: |
          npm ci
          npm test
```

- [ ] **Step 2: Push to a branch and confirm both jobs run and pass**

Run:
```bash
git checkout -b remediation/r5-devops-infra
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow running flutter + functions + rules test suites"
git push -u origin remediation/r5-devops-infra
```
Then open a PR (or push directly if the user has already asked for that) and confirm both jobs
show green in the Actions tab before merging. If either job fails, fix the underlying issue — do
not weaken the workflow to make it pass.

- [ ] **Step 3: Enable required-status-check branch protection on `main` — manual, Console-side**

GitHub repo Settings → Branches → branch protection rule for `main` → require the `flutter` and
`functions-and-rules` status checks to pass before merging. (Optional but recommended given this is
the one thing that turns "CI runs" into "CI actually blocks a bad merge.")

---

### Task 3: Cloud Functions timeout/retry configuration

**Files:**
- Modify: `functions/index.js` (the `cleanupExpiredCamps` wrapper, written in R3 Task 1 Step 7)

- [ ] **Step 1: Add explicit options to the scheduled function**

Change:
```javascript
exports.cleanupExpiredCamps = onSchedule("every 24 hours", () =>
  cleanupExpiredCampsHandler(getFirestore())
);
```
to:
```javascript
exports.cleanupExpiredCamps = onSchedule(
  { schedule: "every 24 hours", timeoutSeconds: 540, retryCount: 3 },
  () => cleanupExpiredCampsHandler(getFirestore())
);
```

- [ ] **Step 2: Paginate the expired-camps query so a large backlog can't blow the (now 540s) timeout**

Open `functions/lib/cleanupExpiredCamps.js` (from R3). If the query that finds expired camps doesn't
already limit its batch size, add a cap:
```javascript
const BATCH_LIMIT = 50; // process at most 50 expired camps per scheduled run

async function cleanupExpiredCampsHandler(db) {
  const cutoff = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
  const expiredSnap = await db
    .collection("camps")
    .where("endDate", "<", cutoff)
    .limit(BATCH_LIMIT)
    .get();
  for (const doc of expiredSnap.docs) {
    await db.recursiveDelete(doc.ref);
  }
}

module.exports = { cleanupExpiredCampsHandler, BATCH_LIMIT };
```
(Keep whatever the real existing query/delete logic is — this shows the *shape* of the change,
apply the `.limit(BATCH_LIMIT)` addition to the real query in the file, don't replace working logic
wholesale.) With a 24-hour schedule and a 50-per-run cap, a backlog larger than 50 simply finishes
over multiple days rather than risking a timeout — acceptable for this app's actual scale.

- [ ] **Step 3: Add a test for the batch-limit behavior**

In `functions/test/cleanupExpiredCamps.test.js` (from R3 Task 5), add:
```javascript
test("processes at most BATCH_LIMIT camps in a single run", async () => {
  const { BATCH_LIMIT } = require("../lib/cleanupExpiredCamps");
  for (let i = 0; i < BATCH_LIMIT + 5; i++) {
    await db.doc(`camps/expired-${i}`).set({ orgId: "org-1", endDate: daysAgo(90) });
  }

  await cleanupExpiredCampsHandler(db);

  const remaining = await db.collection("camps").where("endDate", "<", daysAgo(60)).get();
  expect(remaining.size).toBe(5); // BATCH_LIMIT deleted, 5 left for the next run
});
```

- [ ] **Step 4: Run and confirm**

Run:
```bash
cd /d/CampConnect/functions && npm run test:cleanup
```

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add functions/index.js functions/lib/cleanupExpiredCamps.js functions/test/cleanupExpiredCamps.test.js
git commit -m "fix(reliability): add timeout/retry config and batch-limit cleanupExpiredCamps"
```

---

### Task 4: Alerting for Cloud Functions errors — manual, Console-side

**Files:** none (GCP Console configuration only)

- [ ] **Step 1: Create a log-based alerting policy**

Google Cloud Console → Monitoring → Alerting → Create Policy. Condition: Cloud Functions execution
count where `status != "ok"`, threshold: any occurrence, for any function in this project.
Notification channel: the developer's email.

- [ ] **Step 2: Verify it fires**

Trigger a deliberate failure against the `dev` project (e.g. call `claimCampCode` with a malformed
code, which throws `invalid-argument` — note: routine client-side validation errors will be noisy
if the alert isn't scoped carefully; consider scoping the condition to 5xx/`internal`/`unknown`
Cloud Functions execution statuses specifically, not every thrown `HttpsError`, so this doesn't
alert-fatigue on ordinary user-input mistakes).

- [ ] **Step 3: Document it**

Add one paragraph to `README.md`'s Configuration section noting the alert exists, what it watches,
and where notifications go, so a returning solo developer doesn't wonder whether this was ever set
up.

---

### Task 5: Export and version `firestore.indexes.json`

**Files:**
- Create: `firestore.indexes.json`
- Modify: `firebase.json`

- [ ] **Step 1: Export the current indexes from the live project**

```bash
firebase use default
firebase firestore:indexes > firestore.indexes.json
```

- [ ] **Step 2: Wire it into `firebase.json`**

In `firebase.json`, change:
```json
  "firestore": {
    "rules": "firestore.rules"
  },
```
to:
```json
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
```

- [ ] **Step 3: Validate**

```bash
firebase deploy --only firestore:indexes --dry-run
```
Expected: validates cleanly (dry run only — do not actually deploy without the user's go-ahead).

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add firestore.indexes.json firebase.json
git commit -m "chore: version Firestore composite indexes as code"
```

---

### Task 6: Document a deploy rollback procedure

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add an "Incident: rollback" section**

Add to `README.md`:
```markdown
## Incident: rolling back a bad deploy

**Firestore rules:** Firebase Console → Firestore Database → Rules → History tab → select the
last-known-good version → Publish.

**Storage rules:** Firebase Console → Storage → Rules → History tab → same process.

**Cloud Functions:** redeploy from the last-known-good commit:
```bash
git checkout <last-good-sha> -- functions/ firestore.rules storage.rules
firebase deploy --only functions,firestore:rules,storage
```
Then revert the working tree back with `git checkout main -- functions/ firestore.rules
storage.rules` once the emergency is over and the real fix is ready to deploy properly.

**Remember:** rules and functions changed together in most deploys (see the "Coordinated deploys"
note below) — roll back both together, not just one, to avoid a version mismatch between the
client and backend.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add README.md
git commit -m "docs: document a rules/functions rollback procedure"
```

---

### Task 7: Enable Firestore PITR — manual, Console-side

**Files:** none

- [ ] **Step 1: Enable Point-in-Time Recovery**

Google Cloud Console → Firestore → Backups → enable Point-in-Time Recovery (7-day window) for the
production database. This is a per-database toggle with a small ongoing storage cost proportional
to write volume — reasonable at this app's scale.

- [ ] **Step 2: Document it**

Add one line to `README.md`'s Configuration section: "Firestore PITR is enabled (7-day recovery
window) on the production project."

---

### Task 8: GCP Billing budget alert — manual, Console-side

**Files:** none

- [ ] **Step 1: Set a budget alert**

Google Cloud Console → Billing → Budgets & Alerts → create a budget for the production project at a
small threshold (e.g. $10, $25, $50 tiers) with email notification to the developer.

- [ ] **Step 2: Document it**

Add one line to `README.md`'s Configuration section noting the threshold and where alerts go.

---

### Task 9: Extend `cleanupExpiredCamps` to also delete Storage photos

**Files:**
- Modify: `functions/lib/cleanupExpiredCamps.js`
- Modify: `functions/test/cleanupExpiredCamps.test.js`

This closes the gap where `recursiveDelete` only removes Firestore documents — Storage objects
(including photos of children, per `storage.rules`'s own comments) currently persist forever after
a camp is "deleted," directly contradicting the privacy policy's "everything deleted 60 days after
camp end" claim (Compliance-HIGH cross-reference — R6 fixes the policy wording only if this task
makes the underlying behavior true first; do this task before or alongside R6's retention-wording
task).

- [ ] **Step 1: Write the failing test**

Add to `functions/test/cleanupExpiredCamps.test.js`:
```javascript
const { getStorage } = require("firebase-admin/storage");

test("deletes the camp's Storage photos along with its Firestore documents", async () => {
  const bucket = getStorage().bucket();
  await db.doc("camps/photo-camp").set({ orgId: "org-1", endDate: daysAgo(90) });
  const file = bucket.file("camps/photo-camp/sessionLocations/loc-1/group_photo.jpg");
  await file.save(Buffer.from("fake image bytes"), { contentType: "image/jpeg" });

  await cleanupExpiredCampsHandler(db, bucket);

  const [exists] = await file.exists();
  expect(exists).toBe(false);
  expect((await db.doc("camps/photo-camp").get()).exists).toBe(false);
});
```
(This test needs the Storage emulator running alongside Firestore — add `storage` to the
`--only` flag in this suite's `test:cleanup` script in `functions/package.json`:
`"test:cleanup": "firebase emulators:exec --only firestore,storage --project campconnect-cleanup-test \"jest test/cleanupExpiredCamps.test.js --runInBand\""`.)

- [ ] **Step 2: Run and confirm it fails**

Run:
```bash
cd /d/CampConnect/functions && npm run test:cleanup
```
Expected: FAIL — `cleanupExpiredCampsHandler` doesn't accept a `bucket` parameter yet and doesn't
touch Storage.

- [ ] **Step 3: Implement, with `bucket` optional so R3's existing tests keep working unchanged**

In `functions/lib/cleanupExpiredCamps.js`, add a second, optional parameter and guard the Storage
call so every R3 Task 5 test (which calls `cleanupExpiredCampsHandler(db)` with one argument) keeps
passing unmodified — only the new test from Step 1 above exercises the Storage-deletion path:
```javascript
async function cleanupExpiredCampsHandler(db, bucket) {
  const cutoff = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
  const expiredSnap = await db
    .collection("camps")
    .where("endDate", "<", cutoff)
    .limit(BATCH_LIMIT)
    .get();
  for (const doc of expiredSnap.docs) {
    if (bucket) {
      await bucket.deleteFiles({ prefix: `camps/${doc.id}/` });
    }
    await db.recursiveDelete(doc.ref);
  }
}
```
(Production always passes a real `bucket` — see Step 4 — so this guard only matters for the R3
tests that don't care about Storage and were written before `bucket` existed.)

- [ ] **Step 4: Update the production wrapper in `functions/index.js`**

```javascript
const { getStorage } = require("firebase-admin/storage");

exports.cleanupExpiredCamps = onSchedule(
  { schedule: "every 24 hours", timeoutSeconds: 540, retryCount: 3 },
  () => cleanupExpiredCampsHandler(getFirestore(), getStorage().bucket())
);
```

- [ ] **Step 5: Apply the same optional-`bucket` pattern to `deleteMyAccount`'s org-owner cascade**

Open `functions/lib/deleteMyAccount.js` (from R3). In the owner-cascade branch (the loop that
`recursiveDelete`s each camp in the org), add the same guarded call before each camp's Firestore
delete:
```javascript
if (bucket) {
  await bucket.deleteFiles({ prefix: `camps/${campDoc.id}/` });
}
```
and, immediately before the org doc itself is deleted:
```javascript
if (bucket) {
  await bucket.deleteFiles({ prefix: `organizations/${orgId}/locations/` });
}
```
Change `deleteMyAccountHandler`'s signature from `(db, authAdmin, auth)` to
`(db, authAdmin, auth, bucket)` — as with `cleanupExpiredCampsHandler`, this is purely additive:
every R3 Task 4 test calling `deleteMyAccountHandler(db, authAdmin, { uid })` (3 arguments, no
`bucket`) keeps passing unchanged, since `bucket` is simply `undefined` there and both new guards
skip cleanly. Update the `functions/index.js` wrapper:
```javascript
exports.deleteMyAccount = onCall({ enforceAppCheck: true }, (request) =>
  deleteMyAccountHandler(getFirestore(), getAuth(), request.auth, getStorage().bucket())
);
```

- [ ] **Step 6: Add one new test proving the org-owner cascade also deletes Storage**

Append to `functions/test/deleteMyAccount.test.js`:
```javascript
const { getStorage } = require("firebase-admin/storage");

test("owner deletion also deletes each camp's Storage photos and the org's location photos", async () => {
  const bucket = getStorage().bucket();
  const owner = await authAdmin.createUser({ email: "owner4@example.com", password: "correcthorsebattery" });
  await seedOrgWithTwoCamps(owner.uid);
  const campFile = bucket.file("camps/camp-1/sessionLocations/loc-1/group_photo.jpg");
  await campFile.save(Buffer.from("fake"), { contentType: "image/jpeg" });
  const orgFile = bucket.file("organizations/org-1/locations/loc-1/photo.jpg");
  await orgFile.save(Buffer.from("fake"), { contentType: "image/jpeg" });

  await deleteMyAccountHandler(db, authAdmin, { uid: owner.uid }, bucket);

  expect((await campFile.exists())[0]).toBe(false);
  expect((await orgFile.exists())[0]).toBe(false);
});
```
Update this suite's `test:delete` script in `functions/package.json` to include the Storage
emulator: `"test:delete": "firebase emulators:exec --only firestore,auth,storage --project campconnect-deleteaccount-test \"jest test/deleteMyAccount.test.js --runInBand\""`.

- [ ] **Step 7: Run both affected test suites**

Run:
```bash
cd /d/CampConnect/functions && npm run test:cleanup && npm run test:delete
```
Expected: all PASS — the original R3 tests unchanged, plus the two new Storage-deletion tests
(Step 1 above and this step's addition).

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add functions/lib/cleanupExpiredCamps.js functions/lib/deleteMyAccount.js functions/index.js functions/test/cleanupExpiredCamps.test.js functions/test/deleteMyAccount.test.js functions/package.json
git commit -m "fix(compliance): delete Storage photos on camp/org cleanup, not just Firestore docs"
```

---

### Task 10: Document the caret-range dependency decision

**Files:**
- Create: `docs/superpowers/plans/r5-decision-log.md`

- [ ] **Step 1: Record the decision**

```markdown
# R5 Decision Log

## Unpinned caret ranges in functions/package.json

`firebase-admin: ^12.0.0` and `firebase-functions: ^5.0.0` allow automatic minor/patch drift on a
bare `npm install`. **Decision:** no change — `package-lock.json` is committed and both the R5 CI
workflow and local dev docs use `npm ci`, which respects the lockfile exactly regardless of the
caret range. Revisit only if a contributor is ever found running `npm install` instead of `npm ci`.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add docs/superpowers/plans/r5-decision-log.md
git commit -m "docs: record R5 decision on unpinned caret ranges (mitigated by lockfile + npm ci)"
```

---

### Task 11: Structured logging in Cloud Functions

**Files:**
- Modify: `functions/lib/claimCampCode.js`, `functions/lib/registerGuide.js`,
  `functions/lib/deleteMyAccount.js`, `functions/lib/cleanupExpiredCamps.js`, `functions/index.js`

- [ ] **Step 1: Replace `console.log`/`console.error` with the structured logger**

At the top of each file that currently calls `console.log`/`console.error`, add:
```javascript
const logger = require("firebase-functions/logger");
```
Replace each `console.log("some message", value)` with
`logger.info("some message", { value })` and each `console.error("some message", err)` with
`logger.error("some message", { error: err.message })` — same call sites, same information,
structured as JSON fields instead of a formatted string, so Cloud Logging queries can filter on
`jsonPayload.value`/`jsonPayload.error` instead of substring-matching log text.

- [ ] **Step 2: Verify no remaining raw console calls in production code paths**

Run:
```bash
grep -rn "console\.\(log\|error\)" functions/lib/ functions/index.js
```
Expected: no output (or only in files explicitly excluded, e.g. none expected here).

- [ ] **Step 3: Run the full functions test suite**

Run:
```bash
cd /d/CampConnect/functions && npm test
```

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add functions/lib/*.js functions/index.js
git commit -m "refactor: use firebase-functions/logger for structured logging"
```

---

## Post-phase verification

- [ ] `.github/workflows/ci.yml` runs green on a real push.
- [ ] `firebase deploy --only firestore:indexes --dry-run` validates.
- [ ] `cd functions && npm test` still passes after Tasks 3, 9, and 11's changes.
- [ ] README's Configuration section now documents: dev/prod project topology, the Cloud Functions
  error alert, PITR, and the billing alert — a returning solo developer can find all four without
  opening the GCP Console first.
- [ ] Update the master remediation checklist (`00-verify-team-remediation-roadmap.md`).
