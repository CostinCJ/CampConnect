# Phase 2 — Security Hardening Implementation Plan (rev. 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the exploitable holes found in the sweep — (1) world-readable guide invite code, (2) world-readable/enumerable kid codes, (3) world-readable children's photos, (4) non-atomic code claiming, and (5) **role self-escalation** (any authenticated user writing `role: 'guide'` into their own user doc) — behind a tested rules-unit-test suite.

**Architecture:** Both privileged flows move entirely server-side into **callable Cloud Functions** using the Admin SDK (which bypasses rules): `registerGuide` validates the invite code AND creates the Auth user + user profile, so the client never writes a `role`; `claimCampCode` atomically claims a kid code. Firestore rules then deny all client `users` creation and restrict updates to `campId` only, closing escalation. A `@firebase/rules-unit-testing` Jest suite proves each rule.

Some rules here are **interim** and get tightened in Phase 5 (org scoping via custom claims) — flagged inline.

**Tech Stack:** Firebase Cloud Functions (Node 20, callable v2, `firebase-admin` auth+firestore), Firestore/Storage rules, `@firebase/rules-unit-testing` + Jest, Firebase Emulator Suite, Dart `cloud_functions`.

**Branch:** `phase2-security-hardening`.

**Prerequisites:** Firebase CLI logged in; project `camp-connect-4644c` is on the **Blaze plan** (it already runs Cloud Functions, so it is). Java 11+ for the emulator.

---

### Task 1: Branch + emulator + rules-test harness scaffolding

**Files:**
- Create: `firestore-tests/package.json`
- Create: `firestore-tests/firestore.test.js`
- Modify: `firebase.json` (emulator config)

- [ ] **Step 1: Create the branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase2-security-hardening
```
Expected: `Switched to a new branch`.

- [ ] **Step 2: Add emulator config to `firebase.json`**

Replace the contents of `firebase.json` with:
```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  },
  "firestore": {
    "rules": "firestore.rules"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "firestore": { "port": 8080 },
    "storage": { "port": 9199 },
    "auth": { "port": 9099 },
    "functions": { "port": 5001 },
    "ui": { "enabled": true }
  }
}
```

- [ ] **Step 3: Create the rules-test package**

Create `firestore-tests/package.json`:
```json
{
  "name": "campconnect-rules-tests",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "firebase emulators:exec --only firestore --project campconnect-rules-test \"jest --runInBand\""
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.4",
    "jest": "^29.7.0"
  }
}
```
> `firebase emulators:exec` finds `firebase.json` by walking up from the cwd, so running `npm test`
> from `firestore-tests/` works. If your firebase-tools version doesn't, run the same command from
> the repo root instead.

- [ ] **Step 4: Install test deps**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm install
```
Expected: installs without error.

- [ ] **Step 5: Create an initial smoke test that loads the current rules**

Create `firestore-tests/firestore.test.js`:
```javascript
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
```

- [ ] **Step 6: Run the smoke test against the current rules**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: emulator boots, Jest runs, `smoke` PASSES (current rules have a default-deny catch-all).

- [ ] **Step 7: Commit**

```bash
cd /d/CampConnect
git add firebase.json firestore-tests/package.json firestore-tests/package-lock.json firestore-tests/firestore.test.js
git commit -m "test: scaffold Firestore rules-unit-test harness with emulator"
```

---

### Task 2: Write FAILING rules tests that encode the target security model

**Files:**
- Modify: `firestore-tests/firestore.test.js`

Write the tests first (TDD). They assert the *desired* end state and will FAIL against today's wide-open rules — that failure is the proof the current rules are broken.

- [ ] **Step 1: Add the security-model test cases**

Append to `firestore.test.js`:
```javascript
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
```

- [ ] **Step 2: Run — expect FAILURES**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: smoke passes; the new tests **FAIL** (today's rules are world-readable and allow self-created guide profiles). This confirms the tests capture the vulnerabilities — including the escalation hole.

- [ ] **Step 3: Commit the failing tests**

```bash
cd /d/CampConnect
git add firestore-tests/firestore.test.js
git commit -m "test: add failing rules tests encoding target security model incl. role escalation"
```

---

### Task 3: Rewrite firestore.rules to pass the tests

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Replace `firestore.rules` with the hardened interim rules**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function userData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    function hasProfile() {
      return isSignedIn()
        && exists(/databases/$(database)/documents/users/$(request.auth.uid));
    }

    function isGuide() {
      return hasProfile() && userData().role == 'guide';
    }

    // True if the signed-in user's stored campId matches this camp.
    function isCampMember(campId) {
      return hasProfile() && userData().campId == campId;
    }

    // Config holds the guide invite code. NOT client-readable — validation
    // happens inside the registerGuide callable function (Admin SDK).
    match /config/{document=**} {
      allow read, write: if false;
    }

    // Profiles are created ONLY server-side (registerGuide / claimCampCode).
    // A user may read their own doc, and update ONLY campId (guides switching
    // their active camp). Role can never be self-assigned. Closes escalation.
    match /users/{userId} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow create, delete: if false;
      allow update: if isSignedIn() && request.auth.uid == userId
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['campId']);
    }

    // Master locations. INTERIM: any guide may write; any signed-in user may
    // read (kids need them for the map). Phase 5 scopes both to the org.
    match /locations/{document=**} {
      allow read: if isSignedIn();
      allow write: if isGuide();
    }

    match /camps/{campId} {
      // INTERIM: readable by members and by any guide (guides pick a camp to
      // activate; Phase 5 restricts to org guides).
      allow read: if isGuide() || isCampMember(campId);
      allow create: if isGuide()
        && request.resource.data.createdBy == request.auth.uid;
      allow update, delete: if isGuide()
        && resource.data.createdBy == request.auth.uid;

      // Guides manage codes (generate + list). Kids NEVER read codes — the
      // claim happens in the claimCampCode function (Admin SDK bypasses rules).
      match /codes/{code} {
        allow read, write: if isGuide();
      }

      match /teams/{teamId} {
        allow read: if isGuide() || isCampMember(campId);
        allow write: if isGuide();
      }
      match /pointsHistory/{entryId} {
        allow read: if isGuide() || isCampMember(campId);
        allow write: if isGuide();
      }
      match /announcements/{annId} {
        allow read: if isGuide() || isCampMember(campId);
        allow write: if isGuide();
      }
      match /emergencyAlerts/{alertId} {
        allow read: if isGuide() || isCampMember(campId);
        allow write: if isGuide();
      }
      match /sessionLocations/{slId} {
        allow read: if isGuide() || isCampMember(campId);
        allow write: if isGuide();
      }
    }

    // Default deny.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 2: Run the rules tests — expect PASS**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: **all tests PASS**, including the escalation and codes tests.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add firestore.rules
git commit -m "fix(security): lock down Firestore rules — server-only profiles, secret config, guide-only codes"
```

---

### Task 4: `registerGuide` + `claimCampCode` callable Cloud Functions

**Files:**
- Modify: `functions/index.js`
- Modify: `functions/package.json` (only if deps outdated)

- [ ] **Step 1: Confirm functions deps**

Run:
```bash
grep -n "firebase-functions\|firebase-admin" functions/package.json
```
Expected: both present. If `firebase-functions` is <4.x or `firebase-admin` <12.x, run
`cd functions && npm install firebase-functions@latest firebase-admin@latest`.

- [ ] **Step 2: Add imports**

At the top of `functions/index.js`, alongside the existing requires, add:
```javascript
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue } = require("firebase-admin/firestore");
```
(`getFirestore` and `getMessaging` are already imported.)

- [ ] **Step 3: Add `registerGuide`**

Append to `functions/index.js`:
```javascript
/**
 * Registers a guide entirely server-side: validates the invite code (which is
 * never exposed to clients), creates the Auth user, and writes the profile doc
 * with role 'guide'. Clients can NEVER write a role themselves (rules deny it),
 * which closes the self-escalation hole.
 */
exports.registerGuide = onCall(async (request) => {
  const { email, password, displayName, inviteCode } = request.data || {};
  if (!email || !password || !displayName || !inviteCode) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const cfg = await getFirestore().doc("config/app").get();
  const expected = cfg.exists ? cfg.data().guideInviteCode : null;
  if (!expected || expected !== inviteCode) {
    throw new HttpsError("permission-denied", "invalid-invite-code");
  }

  let userRecord;
  try {
    userRecord = await getAuth().createUser({ email, password, displayName });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "email-already-in-use");
    }
    if (e.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "weak-password");
    }
    throw new HttpsError("internal", "auth-create-failed");
  }

  await getFirestore().doc(`users/${userRecord.uid}`).set({
    role: "guide",
    email: email,
    displayName: displayName,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true };
});
```

- [ ] **Step 4: Add `claimCampCode`**

Append to `functions/index.js`:
```javascript
/**
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp not ended. Creates the kid profile
 * server-side. Returns { campId, team, displayName }.
 *
 * INTERIM (Phase 2): the code is located by scanning the 'codes' collection
 * group, O(total codes). Phase 5 replaces this with a single get() on a
 * top-level codes/{code} document. Do not optimize here.
 */
exports.claimCampCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const code = ((request.data && request.data.code) || "").trim().toUpperCase();
  if (!/^CAMP-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const db = getFirestore();

  // Locate the code doc across all camps (doc id == the code string).
  let codeRef = null;
  let campId = null;
  const cg = await db.collectionGroup("codes").get();
  cg.forEach((doc) => {
    if (doc.id === code) {
      codeRef = doc.ref;
      campId = doc.ref.parent.parent.id;
    }
  });
  if (!codeRef) {
    throw new HttpsError("not-found", "invalid-code");
  }

  const campSnap = await db.doc(`camps/${campId}`).get();
  if (campSnap.exists) {
    const endDate = campSnap.data().endDate;
    if (endDate && endDate.toDate && endDate.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "session-expired");
    }
  }

  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(codeRef);
    if (!fresh.exists) throw new HttpsError("not-found", "invalid-code");
    const d = fresh.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    tx.update(codeRef, { used: true, usedBy: uid });
    tx.set(db.doc(`users/${uid}`), {
      role: "kid",
      displayName: d.displayName || "Campist",
      campId: campId,
      team: d.team,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { campId: campId, team: d.team, displayName: d.displayName || "Campist" };
  });
});
```

- [ ] **Step 5: Lint**

Run:
```bash
cd /d/CampConnect/functions && npx eslint index.js || true
```
Expected: no fatal errors (warnings acceptable). Function-level behavior is verified against the
emulator in Task 7 — do not add a placeholder unit-test file.

- [ ] **Step 6: Commit**

```bash
cd /d/CampConnect
git add functions/index.js functions/package.json functions/package-lock.json
git commit -m "feat(security): server-side registerGuide and atomic claimCampCode callables"
```

---

### Task 5: Wire the Dart client to the callable functions

**Files:**
- Modify: `pubspec.yaml` (add `cloud_functions`)
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/data/camp_repository.dart`
- Modify: `lib/features/auth/presentation/kid_login_screen.dart`

- [ ] **Step 1: Add the cloud_functions dependency**

In `pubspec.yaml` under Firebase deps:
```yaml
  cloud_functions: ^5.1.3
```
Run:
```bash
flutter pub get
```
Expected: resolves.

- [ ] **Step 2: Add FirebaseFunctions to the repository**

In `auth_repository.dart`, add the import:
```dart
import 'package:cloud_functions/cloud_functions.dart';
```
Add a field and update the constructor:
```dart
  final FirebaseFunctions _functions;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;
```

- [ ] **Step 3: Rename the custom exception to `AuthFailure`**

Rename the `FirebaseAuthException` class at the bottom of `auth_repository.dart` to `AuthFailure`
(it currently shadows the real `firebase_auth` type). Update every `throw FirebaseAuthException(`
in this file to `throw AuthFailure(`. Then run:
```bash
grep -rn "FirebaseAuthException" lib
```
Expected: remaining matches only in catch-clauses meant for the *real* firebase_auth exception
(none construct the custom class).

- [ ] **Step 4: Replace `registerGuide` with a callable-backed flow**

Replace the entire `registerGuide` method (and DELETE the now-unused `validateInviteCode`
method) with:
```dart
  Future<AppUser> registerGuide({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
  }) async {
    // Registration is fully server-side (invite validation + Auth user +
    // profile with role). The client never writes a role.
    try {
      await _functions.httpsCallable('registerGuide').call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'inviteCode': inviteCode,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(code: e.message ?? e.code, message: e.message ?? e.code);
    }

    // Now sign in with the freshly created credentials.
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getAppUser(credential.user!.uid);
  }
```
> `e.message` carries the machine string set server-side (`invalid-invite-code`,
> `email-already-in-use`, `weak-password`) — the login screen's `_friendlyError` string-matching
> continues to work unchanged.

- [ ] **Step 5: Replace `signInWithCode` to call `claimCampCode`**

Replace the entire `signInWithCode` method body with:
```dart
  Future<AppUser> signInWithCode({
    required String code,
    required String campId, // retained for signature compatibility; unused now
  }) async {
    // Sign in anonymously first so the callable has an auth context.
    UserCredential credential;
    try {
      credential = await _auth.signInAnonymously();
    } catch (_) {
      throw AuthFailure(
        code: 'auth-error',
        message: 'Unable to sign in. Please try again.',
      );
    }
    final uid = credential.user!.uid;

    try {
      final result =
          await _functions.httpsCallable('claimCampCode').call({'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return AppUser(
        uid: uid,
        role: AppConstants.roleKid,
        displayName: data['displayName'] as String? ?? 'Campist',
        campId: data['campId'] as String?,
        team: data['team'] as String?,
        createdAt: DateTime.now(),
      );
    } on FirebaseFunctionsException catch (e) {
      // Clean up the anonymous user on any claim failure.
      await _auth.currentUser?.delete();
      await _auth.signOut();
      throw AuthFailure(code: e.message ?? e.code, message: e.message ?? e.code);
    }
  }
```

- [ ] **Step 6: Simplify kid login — no more client-side camp scan**

In `kid_login_screen.dart` `_submit()`, replace the lookup block:
```dart
      // Look up the camp by code
      final campRepository = ref.read(campRepositoryProvider);
      final campId = await campRepository.findCampIdByCode(code);

      if (campId == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidCode),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Sign in anonymously with the camp code
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signInWithCode(code: code, campId: campId);
```
With:
```dart
      // Claim the code server-side (validates + resolves camp atomically).
      final authRepository = ref.read(authRepositoryProvider);
      final claimedUser =
          await authRepository.signInWithCode(code: code, campId: '');
      final campId = claimedUser.campId!;
```
(The Phase 3 team-race fix reworks the FCM-subscribe lines below this; both changes are compatible —
if Phase 3 already landed, keep its `ref.invalidate` + `claimedUser.team` version.)

- [ ] **Step 7: Delete the dead `findCampIdByCode`**

In `camp_repository.dart`, delete the entire `findCampIdByCode` method. Verify:
```bash
grep -rn "findCampIdByCode\|validateInviteCode" lib
```
Expected: no matches.

- [ ] **Step 8: Analyze**

Run:
```bash
flutter analyze
```
Expected: no new errors.

- [ ] **Step 9: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock lib/features/auth
git commit -m "feat(security): route guide registration and code claiming through callables; AuthFailure rename"
```

---

### Task 6: Lock down Storage rules for children's photos

**Files:**
- Modify: `storage.rules`

- [ ] **Step 1: Require auth for reads of location + session photos**

Replace `storage.rules` with (the `models/` block was removed in Phase 1):
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Master location photos — signed-in users only. Phase 5 scopes writes to org guides.
    match /locations/{locationId}/photo.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Session location group photos (may contain images of children).
    match /camps/{campId}/sessionLocations/{sessionLocId}/group_photo.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // Default deny.
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```
Photos render via `CachedNetworkImage` with tokenized download URLs; signed-in users (kids are
anonymous-auth) are unaffected — only unauthenticated direct access is blocked.

- [ ] **Step 2: Commit**

```bash
git add storage.rules
git commit -m "fix(security): require auth to read children's location and group photos"
```

---

### Task 7: Deploy-dry-run + full emulator verification

**Files:** none (verification only)

- [ ] **Step 1: Full rules-test suite**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: all tests PASS.

- [ ] **Step 2: Validate rules compile for deploy (no real deploy)**

Run:
```bash
cd /d/CampConnect && firebase deploy --only firestore:rules,storage --dry-run
```
Expected: rules compile cleanly. **Do NOT deploy for real** — that is outward-facing; the user
authorizes it explicitly (see post-phase actions).

- [ ] **Step 3: Emulator integration test of the callables**

Run:
```bash
cd /d/CampConnect && firebase emulators:start --only functions,firestore,auth
```
Seed via the Emulator UI: `config/app` = `{guideInviteCode: "LETMEIN"}`;
`camps/c1` = `{createdBy: "g1", endDate: <future Timestamp>}`;
`camps/c1/codes/CAMP-TEST` = `{team: "red", displayName: "Campist #1", used: false}`.
Then exercise the callables (via the app pointed at the emulator — Step 4 — or a scratch client):
1. `registerGuide` with a wrong invite → error `permission-denied` / `invalid-invite-code`; **no Auth user is created** (check the Auth emulator tab).
2. `registerGuide` with `LETMEIN` → Auth user exists AND `users/{uid}` has `role: "guide"`.
3. `claimCampCode({code:"CAMP-TEST"})` as an anon user → returns `{campId:"c1", team:"red"}`; code flips `used:true`; `users/{uid}` has `role:"kid"`.
4. `claimCampCode` again with the same code → error `code-used`.
Record pass/fail per step.

- [ ] **Step 4: App smoke test against emulators**

Temporarily wire the app to the emulators in `main.dart` behind a debug flag:
```dart
const bool useEmulators = bool.fromEnvironment('USE_EMULATORS');
// after Firebase.initializeApp:
if (useEmulators) {
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('10.0.2.2', 5001);
}
```
(`10.0.2.2` = host loopback from the Android emulator; use `localhost` on a desktop target.) Run with
`--dart-define=USE_EMULATORS=true`, verify guide registration + kid code login end-to-end, then keep
the guarded block (it is inert without the define).

- [ ] **Step 5: Final commit**

```bash
cd /d/CampConnect
git add lib/main.dart
git commit -m "test: verify hardened rules + server-side auth flows in emulator"
```

---

## Post-phase actions (require explicit user authorization)

- **Deploying is outward-facing.** When the user gives the go-ahead:
  ```bash
  firebase deploy --only firestore:rules,storage,functions
  ```
  **Order matters:** deploy functions and rules together (or functions first) — the new rules break
  the OLD client's registration/claiming, and the old rules leave the holes open. Ship the updated
  app build promptly after. Until this deploy, the live backend remains exploitable.
- **Set the real invite code** in live `config/app.guideInviteCode` via the Firebase Console
  (client writes are now denied, which is correct).
- Update the roadmap checklist: Phase 2 done.

## Interim-rule debts handed to Phase 5 (do not forget)

1. `locations` and `camps` reads allow *any* guide — Phase 5 scopes to `orgId` via custom claims.
2. `isGuide()`/`isCampMember()` do a `get()` per rule evaluation — Phase 5 replaces guide checks
   with `request.auth.token` claims.
3. `claimCampCode`'s collection-group scan is O(total codes) — Phase 5's top-level `codes/{code}`
   makes it a single `get()`.
4. `registerGuide` still uses the single global invite code — Phase 5 replaces it with per-org
   invite codes inside the same callable.
