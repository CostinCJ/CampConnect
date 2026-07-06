# R2 — Auth Abuse Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the most severe finding from the verify-team security review — a brute-forceable,
unthrottled path (weak org invite-code entropy + zero rate limiting on any callable) to full
guide-level access to a real organisation's data — plus the related storage-upload and
password-strength gaps found alongside it.

**Architecture:** Extract invite-code generation into its own testable module using a CSPRNG
(`crypto.randomInt`) with wider entropy. Add Firebase App Check as the primary abuse-resistance
layer on all three callables, backed by a Firestore-based rate limiter as defense-in-depth. Add
server-side content-type/size checks to `storage.rules` so the client's JPEG re-encoding is a real
control, not just a courtesy.

**Tech Stack:** Node 20 Cloud Functions (`firebase-functions` v2, `firebase-admin`), Jest, Firebase
App Check (Play Integrity / App Attest), Firestore security rules, Flutter/Dart.

**Branch:** `remediation/r2-auth-abuse-hardening`.

**Prerequisites:** Firebase CLI logged in; project on Blaze plan (already true). Node 20 for
functions. `firebase-tools` for emulator testing (already used by `firestore-tests/`).

---

### Task 1: Set up a Jest test harness inside `functions/`

**Files:**
- Modify: `functions/package.json`

- [ ] **Step 1: Add Jest as a dev dependency and a test script**

Run:
```bash
cd /d/CampConnect/functions && npm install --save-dev jest
```

Edit `functions/package.json` to add:
```json
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log",
    "test": "jest"
  },
```

- [ ] **Step 2: Verify Jest runs (even with zero tests yet)**

Run:
```bash
cd /d/CampConnect/functions && npx jest --passWithNoTests
```
Expected: `No tests found, exiting with code 0` (with `--passWithNoTests`).

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add functions/package.json functions/package-lock.json
git commit -m "test: add Jest harness to functions/"
```

---

### Task 2: Cryptographically strong, higher-entropy org invite codes

**Files:**
- Create: `functions/lib/inviteCode.js`
- Create: `functions/test/inviteCode.test.js`
- Modify: `functions/index.js` — remove the inline `ORG_CODE_CHARSET`/generator (currently around
  lines 322-330), replace with an import from `functions/lib/inviteCode.js`

- [ ] **Step 1: Write the failing test**

Create `functions/test/inviteCode.test.js`:
```javascript
const { generateOrgInviteCode, CHARSET, CODE_LENGTH } = require("../lib/inviteCode");

test("generates a code of the expected length using only charset characters", () => {
  const code = generateOrgInviteCode();
  expect(code.length).toBe(CODE_LENGTH);
  for (const ch of code) {
    expect(CHARSET.includes(ch)).toBe(true);
  }
});

test("code length gives at least 10^12 combinations (vs. the old ~10^6)", () => {
  const combinations = Math.pow(CHARSET.length, CODE_LENGTH);
  expect(combinations).toBeGreaterThan(1e12);
});

test("1000 generated codes are all unique (sanity check, not a formal randomness proof)", () => {
  const codes = new Set(Array.from({ length: 1000 }, () => generateOrgInviteCode()));
  expect(codes.size).toBe(1000);
});
```

- [ ] **Step 2: Run it and confirm it fails (module doesn't exist yet)**

Run:
```bash
cd /d/CampConnect/functions && npx jest test/inviteCode.test.js
```
Expected: FAIL with `Cannot find module '../lib/inviteCode'`.

- [ ] **Step 3: Implement `functions/lib/inviteCode.js`**

```javascript
const crypto = require("crypto");

// Excludes visually-ambiguous characters (0/O, 1/I) since a human guide types
// this code once during onboarding.
const CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 10; // 33^10 ≈ 1.8 x 10^15 combinations

function generateOrgInviteCode() {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[crypto.randomInt(CHARSET.length)];
  }
  return code;
}

module.exports = { generateOrgInviteCode, CHARSET, CODE_LENGTH };
```

- [ ] **Step 4: Run the test again and confirm it passes**

Run:
```bash
cd /d/CampConnect/functions && npx jest test/inviteCode.test.js
```
Expected: PASS, 3/3 tests.

- [ ] **Step 5: Wire `functions/index.js` to use the new module**

Open `functions/index.js`. Find the existing inline invite-code charset/generator (near the
`registerGuide` export, referenced as `ORG_CODE_CHARSET` in the review). Delete that inline
definition and add near the top of the file, alongside the other requires:
```javascript
const { generateOrgInviteCode } = require("./lib/inviteCode");
```
Every call site that previously called the inline generator now calls `generateOrgInviteCode()`
unchanged (same function name, same zero-argument signature — no call-site changes needed beyond
the import).

- [ ] **Step 6: Verify no leftover references to the old inline charset**

Run:
```bash
grep -n "ORG_CODE_CHARSET" functions/index.js
```
Expected: no output.

- [ ] **Step 7: Run the full functions test suite + lint**

Run:
```bash
cd /d/CampConnect/functions && npx jest && npx eslint index.js lib/
```
Expected: all Jest tests pass; no new lint errors.

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add functions/lib/inviteCode.js functions/test/inviteCode.test.js functions/index.js
git commit -m "fix(security): generate org invite codes with a CSPRNG at 10-char entropy"
```

---

### Task 3: Firebase App Check on all three callables

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `functions/index.js` (`registerGuide`, `claimCampCode`, `deleteMyAccount` definitions)

- [ ] **Step 1: Add the App Check package**

Run:
```bash
flutter pub add firebase_app_check
```
(This resolves the correct version compatible with the project's current `firebase_core: ^3.12.1` —
do not hand-pick a version number.)

- [ ] **Step 2: Register App Check apps in the Firebase Console**

Manual, Console-side (needed before enforcement will work end-to-end):
Firebase Console → Project Settings → App Check → register the Android app with **Play Integrity**
and the iOS app with **App Attest** (App Attest requires the Apple Developer enrollment tracked as
a pending manual step in the original Phase 7 plan — if that enrollment hasn't happened yet, iOS
enforcement stays in "unenforced/monitoring" mode until it does; Android can be enforced
independently in the meantime).

- [ ] **Step 3: Activate App Check in `lib/main.dart`**

Open `lib/main.dart`. Immediately after the existing `await Firebase.initializeApp(...)` call (and
before the existing `useEmulators` block), add:
```dart
import 'package:firebase_app_check/firebase_app_check.dart';
```
at the top with the other imports, and in `main()`:
```dart
  await FirebaseAppCheck.instance.activate(
    androidProvider: useEmulators ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: useEmulators ? AppleProvider.debug : AppleProvider.appAttest,
  );
```
placed right after `Firebase.initializeApp(...)` and before the existing emulator-wiring block, so
App Check debug mode and the Firestore/Auth/Functions emulator wiring share the same `useEmulators`
flag consistently.

- [ ] **Step 4: Enforce App Check on the three sensitive callables**

Open `functions/index.js`. Change each of the three callable definitions from the positional
`onCall(async (request) => {...})` form to the options-object form:
```javascript
exports.registerGuide = onCall({ enforceAppCheck: true }, async (request) => {
```
```javascript
exports.claimCampCode = onCall({ enforceAppCheck: true }, async (request) => {
```
```javascript
exports.deleteMyAccount = onCall({ enforceAppCheck: true }, async (request) => {
```
Leave the three FCM-trigger functions (`onAnnouncementCreated`, `onEmergencyAlertCreated`,
`onPointsChanged`) and `cleanupExpiredCamps` unchanged — they aren't client-callable, so App Check
doesn't apply.

- [ ] **Step 5: Verify the change compiles**

Run:
```bash
cd /d/CampConnect/functions && node -c index.js
```
Expected: no output (syntax OK).

- [ ] **Step 6: Manual verification against the emulator**

Run:
```bash
cd /d/CampConnect && firebase emulators:start --only functions,firestore,auth
```
With `useEmulators=true` and App Check's debug provider active, confirm `registerGuide` and
`claimCampCode` still succeed end-to-end from the app (App Check emulator/debug tokens satisfy
`enforceAppCheck` locally). Record pass/fail.

- [ ] **Step 7: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock lib/main.dart functions/index.js
git commit -m "feat(security): enforce Firebase App Check on registerGuide, claimCampCode, deleteMyAccount"
```

---

### Task 4: Firestore-backed rate limiting as defense-in-depth

**Files:**
- Create: `functions/lib/rateLimiter.js`
- Create: `functions/test/rateLimiter.test.js`
- Modify: `functions/index.js` (`registerGuide`, `claimCampCode`)

App Check blocks non-genuine clients; this adds a second, independent layer that also limits a
compromised-but-genuine client (e.g. a rooted device replaying real App Check tokens).

- [ ] **Step 1: Write the failing test**

Create `functions/test/rateLimiter.test.js` (uses the Firestore emulator — same pattern as
`firestore-tests/`, but scoped to `functions/` since it's testing function-internal logic, not
security rules):
```javascript
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;
let db;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "campconnect-ratelimiter-test",
    firestore: { host: "127.0.0.1", port: 8080 },
  });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    db = ctx.firestore();
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const { checkRateLimit, MAX_ATTEMPTS } = require("../lib/rateLimiter");

test("allows the first MAX_ATTEMPTS calls within the window", async () => {
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    expect(await checkRateLimit(db, "test-key-1")).toBe(true);
  }
});

test("rejects the call after MAX_ATTEMPTS within the window", async () => {
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    await checkRateLimit(db, "test-key-2");
  }
  expect(await checkRateLimit(db, "test-key-2")).toBe(false);
});

test("different keys have independent limits", async () => {
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    await checkRateLimit(db, "test-key-3a");
  }
  expect(await checkRateLimit(db, "test-key-3a")).toBe(false);
  expect(await checkRateLimit(db, "test-key-3b")).toBe(true);
});
```

- [ ] **Step 2: Add a package.json test script variant that boots the emulator for this suite**

Add to `functions/package.json` scripts:
```json
    "test:rules": "firebase emulators:exec --only firestore --project campconnect-ratelimiter-test \"jest test/rateLimiter.test.js --runInBand\""
```

- [ ] **Step 3: Run it and confirm it fails (module doesn't exist yet)**

Run:
```bash
cd /d/CampConnect/functions && npm run test:rules
```
Expected: FAIL with `Cannot find module '../lib/rateLimiter'`.

- [ ] **Step 4: Implement `functions/lib/rateLimiter.js`**

```javascript
const { FieldValue } = require("firebase-admin/firestore");

const WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_ATTEMPTS = 5;

/**
 * Returns true if the call for `key` is allowed under the rate limit, false
 * if the caller has exceeded MAX_ATTEMPTS within the current WINDOW_MS window.
 * `db` is an injected Firestore instance so this is testable against the
 * emulator without depending on getFirestore()'s default-app singleton.
 */
async function checkRateLimit(db, key) {
  const ref = db.doc(`rateLimits/${key}`);
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart = data && data.windowStart ? data.windowStart : now;
    const windowExpired = now - windowStart > WINDOW_MS;

    if (!data || windowExpired) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }
    if (data.count >= MAX_ATTEMPTS) {
      return false;
    }
    tx.update(ref, { count: FieldValue.increment(1) });
    return true;
  });
}

module.exports = { checkRateLimit, WINDOW_MS, MAX_ATTEMPTS };
```

- [ ] **Step 5: Run the test again and confirm it passes**

Run:
```bash
cd /d/CampConnect/functions && npm run test:rules
```
Expected: PASS, 3/3 tests.

- [ ] **Step 6: Wire the limiter into `claimCampCode` and `registerGuide`**

In `functions/index.js`, add near the top:
```javascript
const { checkRateLimit } = require("./lib/rateLimiter");
```
In `claimCampCode`, immediately after the existing `if (!request.auth) { throw ... }` check, add:
```javascript
  const allowed = await checkRateLimit(getFirestore(), `claimCampCode:${request.auth.uid}`);
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "too-many-attempts");
  }
```
In `registerGuide`, at the very top of the handler (before the invite-code/org-code validation,
since this endpoint is unauthenticated and must be keyed by request IP instead of a uid):
```javascript
  const callerIp = (request.rawRequest && request.rawRequest.ip) || "unknown";
  const allowed = await checkRateLimit(getFirestore(), `registerGuide:${callerIp}`);
  if (!allowed) {
    throw new HttpsError("resource-exhausted", "too-many-attempts");
  }
```

- [ ] **Step 7: Add rules to deny client access to the new `rateLimits` collection**

Open `firestore.rules`. Add, alongside the existing `config/{document=**}` deny block:
```
    match /rateLimits/{document=**} {
      allow read, write: if false;
    }
```
This collection is written only by the Admin SDK inside Cloud Functions (which bypasses rules), so
this is a pure default-deny — no legitimate client read/write path exists.

- [ ] **Step 8: Add a rules test proving clients can't read/write `rateLimits`**

Append to `firestore-tests/firestore.test.js`:
```javascript
test("rateLimits collection is not client-readable or writable", async () => {
  const guide = testEnv.authenticatedContext(guideUid).firestore();
  await assertFails(guide.doc("rateLimits/claimCampCode:someuid").get());
  await assertFails(guide.doc("rateLimits/claimCampCode:someuid").set({ count: 0 }));
});
```

- [ ] **Step 9: Run both test suites**

Run:
```bash
cd /d/CampConnect/functions && npm run test:rules
cd /d/CampConnect/firestore-tests && npm test
```
Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
cd /d/CampConnect
git add functions/lib/rateLimiter.js functions/test/rateLimiter.test.js functions/index.js functions/package.json firestore.rules firestore-tests/firestore.test.js
git commit -m "feat(security): add Firestore-backed rate limiting to registerGuide and claimCampCode"
```

---

### Task 5: Server-side content-type/size validation on Storage uploads

**Files:**
- Modify: `storage.rules`
- Modify: `firestore-tests/storage.test.js`

- [ ] **Step 1: Write the failing tests**

Append to `firestore-tests/storage.test.js` (adjust the existing helper/context setup to match this
file's established pattern for creating an authenticated-guide storage context):
```javascript
test("rejects an upload over 10MB to a location photo path", async () => {
  const guide = /* existing helper for an authenticated-guide storage context */;
  const oversized = Buffer.alloc(11 * 1024 * 1024, "a");
  await assertFails(
    guide
      .ref("organizations/org-1/locations/loc-1/photo.jpg")
      .put(oversized, { contentType: "image/jpeg" })
  );
});

test("rejects a non-image content type on a location photo path", async () => {
  const guide = /* existing helper for an authenticated-guide storage context */;
  const small = Buffer.from("not an image");
  await assertFails(
    guide
      .ref("organizations/org-1/locations/loc-1/photo.jpg")
      .put(small, { contentType: "text/html" })
  );
});

test("accepts a small, correctly-typed image upload to a location photo path", async () => {
  const guide = /* existing helper for an authenticated-guide storage context */;
  const small = Buffer.alloc(1024, "a");
  await assertSucceeds(
    guide
      .ref("organizations/org-1/locations/loc-1/photo.jpg")
      .put(small, { contentType: "image/jpeg" })
  );
});
```

- [ ] **Step 2: Run and confirm the size/content-type tests fail**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: the 2 new `rejects` tests FAIL (current rules have no size/content-type check, so the
oversized/wrong-type uploads currently succeed against the authorization-only rule).

- [ ] **Step 3: Add the validation to `storage.rules`**

Open `storage.rules`. For each of the two `match` blocks (`organizations/{orgId}/locations/{locationId}/photo.jpg`
and `camps/{campId}/sessionLocations/{sessionLocId}/group_photo.jpg`), find the existing
`allow write: if <existing authorization condition>;` line and change it to AND in two new
conditions without removing the existing one, e.g.:
```
      allow write: if <existing authorization condition>
        && request.resource.size < 10 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
```
Apply the same pattern to both match blocks, keeping each block's own existing authorization
condition intact — only append the two new clauses.

- [ ] **Step 4: Run the tests again and confirm all pass**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: all PASS, including the 3 new tests.

- [ ] **Step 5: Commit**

```bash
cd /d/CampConnect
git add storage.rules firestore-tests/storage.test.js
git commit -m "fix(security): enforce content-type and size limits on Storage photo uploads"
```

---

### Task 6: Raise the guide password minimum

**Files:**
- Modify: `lib/core/l10n/localized_validators.dart`
- Test: `test/core/localized_validators_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/core/localized_validators_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';

void main() {
  group('password validator', () {
    test('rejects a 7-character password', () {
      final result = LocalizedValidators.password('abcdefg', /* l10n arg as used elsewhere in this file */);
      expect(result, isNotNull);
    });

    test('accepts an 8-character password', () {
      final result = LocalizedValidators.password('abcdefgh', /* l10n arg as used elsewhere in this file */);
      expect(result, isNull);
    });
  });
}
```
(Match the exact function signature already used by `password()` in
`lib/core/l10n/localized_validators.dart:26-34` — this file's existing usage elsewhere in the
codebase, e.g. in `guide_login_screen.dart`, shows the exact call shape to copy.)

- [ ] **Step 2: Run and confirm the 8-character-acceptance test currently passes but reflects the OLD (too-low) threshold**

Run:
```bash
flutter test test/core/localized_validators_test.dart
```
Expected: both tests currently PASS against the old `< 6` threshold (since 7 and 8 chars both clear
6) — this confirms the test doesn't yet prove anything about the *new* threshold. Proceed to Step 3
regardless; Step 4 will make the 7-character case meaningfully assert the new behavior.

- [ ] **Step 3: Change the threshold**

In `lib/core/l10n/localized_validators.dart`, change:
```dart
if (value.length < 6) return l10n.passwordTooShort;
```
to:
```dart
if (value.length < 8) return l10n.passwordTooShort;
```

- [ ] **Step 4: Run the tests again — now the 7-character case is the meaningful assertion**

Run:
```bash
flutter test test/core/localized_validators_test.dart
```
Expected: PASS — the 7-character test now fails against the *new* threshold before this step and
passes after, and the 8-character test continues to pass. (If `passwordTooShort`'s message text in
any of the three ARB files hardcodes the number "6", update it to "8" in `app_ro.arb`, `app_hu.arb`,
`app_en.arb` as part of this step — check with `grep -n "6" lib/l10n/app_en.arb` around the
`passwordTooShort` key.)

- [ ] **Step 5: Manually raise the server-side Firebase Auth password policy to match**

Firebase Console → Authentication → Settings → Password Policy → set minimum length to 8. This
closes the gap for any caller that bypasses the Flutter client's validator entirely.

- [ ] **Step 6: Commit**

```bash
cd /d/CampConnect
git add lib/core/l10n/localized_validators.dart lib/l10n/app_ro.arb lib/l10n/app_hu.arb lib/l10n/app_en.arb test/core/localized_validators_test.dart
git commit -m "fix(security): raise guide password minimum from 6 to 8 characters"
```

---

### Task 7: Document the accepted-risk decision on account enumeration

**Files:**
- Modify: `docs/superpowers/plans/r1-decision-log.md` → actually append to a new, correctly-scoped
  file since this is an R2 decision, not R1:
- Create: `docs/superpowers/plans/r2-decision-log.md`

- [ ] **Step 1: Record the decision**

Create `docs/superpowers/plans/r2-decision-log.md`:
```markdown
# R2 Decision Log

## Account enumeration via `registerGuide` error codes

`registerGuide` returns a distinct `already-exists`/`email-already-in-use` error, which lets a
caller confirm whether an email address already has a guide account. This is Firebase Auth's own
default `createUser` behavior, not something CampConnect added.

**Decision:** Accepted risk, no code change. Rationale: this app's user base is camp staff, not a
high-value enumeration target (e.g. not a dating app or financial service); the confirmed
information ("this email has an account somewhere") doesn't reveal which organisation, and doesn't
by itself enable any further attack given App Check + rate limiting (R2 Tasks 3-4) now gate the
account-creation endpoint itself. Revisit if this app's threat model changes.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add docs/superpowers/plans/r2-decision-log.md
git commit -m "docs: record R2 decision on account-enumeration risk acceptance"
```

---

## Post-phase verification

- [ ] Run the full test surface once more before moving to R3: `flutter test`,
  `cd functions && npm test && npm run test:rules`, `cd firestore-tests && npm test`,
  `flutter analyze`. All must pass with zero new failures.
- [ ] Do NOT run `firebase deploy` yet — deploying is outward-facing and requires the user's
  explicit go-ahead, same rule as the original roadmap. Update the master remediation checklist
  (`00-verify-team-remediation-roadmap.md`) marking R2's findings done once merged.
