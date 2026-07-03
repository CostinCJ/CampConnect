# Phase 5 — Multi-Organiser Refactor Implementation Plan (rev. 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn CampConnect from one shared camp space into isolated **organisations**, so independent organisers each run their own camps, guides, locations, and codes without seeing or touching each other's data. Also fixes the O(N) kid-login scan, moves session cleanup server-side, and replaces per-request rule `get()`s with **custom claims**.

**Architecture:**
- New `organizations/{orgId}` `{ name, ownerUid, inviteCode }` + `members/{uid}` (role: owner|guide).
- **All org writes happen server-side** inside the (Phase-2) `registerGuide` callable, extended to create-or-join an org and to set custom claims `{ role: 'guide', orgId }` before the client ever signs in — so the first ID token already carries the claims. Rules deny ALL client writes to `organizations`. (This is deliberate: client-side org creation would contradict the rules.)
- Every `camp` gets `orgId`; all camp queries filter by it. Master `locations` move under the org.
- New top-level `codes/{code}` → `{ campId, orgId, team, displayName, used }`: kid login is one `get()`.
- `claimCampCode` reads `codes/{code}` directly. Session cleanup becomes a scheduled function with `recursiveDelete()`.
- A one-time **migration script** moves existing prod data into a default org (required before prod deploy).

**Tech Stack:** Flutter, Riverpod, Firestore, Cloud Functions (callable + scheduled), custom claims, `fake_cloud_firestore` + rules-unit-testing.

**Branch:** `phase5-multi-org`.

**Prerequisites:** Phases 1, 2, 4 merged. Requires the Blaze plan (already in use). **Highest-risk phase — do the dev-project split in Task 0 first and develop everything against `dev`.**

---

### Task 0: Branch + separate dev Firebase project + flavors

**Files:**
- Create: `lib/firebase_options_dev.dart` (generated)
- Modify: `lib/main.dart`
- Modify: `.firebaserc`

- [ ] **Step 1: Branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase5-multi-org
```

- [ ] **Step 2: Create a dev Firebase project**

In the Firebase console create `camp-connect-dev` (enable Auth [email/password + anonymous],
Firestore, Storage, Functions — Blaze). Then:
```bash
firebase use --add
```
Alias the new project `dev` and the existing one `prod`. Confirm `.firebaserc` lists both.

- [ ] **Step 3: Generate dev Firebase options**

Run (requires FlutterFire CLI):
```bash
flutterfire configure --project=camp-connect-dev --out=lib/firebase_options_dev.dart --platforms=android,ios --android-package-name=com.campconnect.camp_connect --ios-bundle-id=com.campconnect.camp_connect
```
Expected: `lib/firebase_options_dev.dart` created. Add it to `.gitignore` alongside
`firebase_options.dart` if that one is ignored (it is) — keep the template pattern consistent.

- [ ] **Step 4: Select flavor at startup**

In `main.dart`:
```dart
import 'firebase_options.dart' as prod;
import 'firebase_options_dev.dart' as dev;

const bool useDevBackend = bool.fromEnvironment('USE_DEV', defaultValue: false);

// in main():
  await Firebase.initializeApp(
    options: useDevBackend
        ? dev.DefaultFirebaseOptions.currentPlatform
        : prod.DefaultFirebaseOptions.currentPlatform,
  );
```
Dev runs: `flutter run --dart-define=USE_DEV=true`. **All Phase 5 testing happens on `dev`.**

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart .firebaserc .gitignore
git commit -m "chore: add dev Firebase project and flavor selection for safe refactor"
```
(Note: `firebase_options_dev.dart` stays untracked, like `firebase_options.dart`.)

---

### Task 1: Domain models — Organization + OrgMember; add orgId to camp and user

**Files:**
- Create: `lib/features/organization/domain/organization.dart`
- Create: `lib/features/organization/domain/org_member.dart`
- Modify: `lib/features/auth/domain/camp_session.dart` (add `orgId`)
- Modify: `lib/features/auth/domain/app_user.dart` (add `orgId`)
- Test: `test/features/organization/organization_test.dart`

- [ ] **Step 1: Write the failing model test**

Create `test/features/organization/organization_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';

void main() {
  test('Organization round-trips', () async {
    final fs = FakeFirebaseFirestore();
    final ref = fs.collection('organizations').doc('o1');
    await ref.set(const Organization(
      id: 'o1', name: 'Tabăra X', ownerUid: 'g1', inviteCode: 'JOIN-1234',
    ).toFirestore());
    final org = Organization.fromFirestore(await ref.get());
    expect(org.name, 'Tabăra X');
    expect(org.ownerUid, 'g1');
    expect(org.inviteCode, 'JOIN-1234');
  });
}
```

- [ ] **Step 2: Run — expect FAIL (compile)**

Run:
```bash
flutter test test/features/organization/organization_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Create the models**

`lib/features/organization/domain/organization.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String ownerUid;
  final String inviteCode;

  const Organization({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.inviteCode,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ownerUid': ownerUid,
        'inviteCode': inviteCode,
      };
}
```
`lib/features/organization/domain/org_member.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrgMember {
  final String uid;
  final String role; // 'owner' | 'guide'
  final String displayName;

  const OrgMember({
    required this.uid,
    required this.role,
    required this.displayName,
  });

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgMember(
      uid: doc.id,
      role: data['role'] as String? ?? 'guide',
      displayName: data['displayName'] as String? ?? '',
    );
  }
}
```

- [ ] **Step 4: Add `orgId` to `CampSession` and `AppUser`**

In `camp_session.dart`: add `final String orgId;` (required), wire through constructor,
`fromFirestore` (`data['orgId'] as String? ?? ''`), `toFirestore` (`'orgId': orgId`), `copyWith`.
In `app_user.dart`: add `final String? orgId;` (nullable — kids get it set by `claimCampCode`),
wired the same way (`if (orgId != null) 'orgId': orgId` in `toFirestore`).

- [ ] **Step 5: Run — expect PASS**

Run:
```bash
flutter test test/features/organization/organization_test.dart
```
Expected: PASS. (Other files won't compile until Task 3 threads `orgId` — expected mid-refactor.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/organization lib/features/auth/domain test/features/organization
git commit -m "feat: Organization + OrgMember models; add orgId to camp and user"
```

---

### Task 2: Server-side org create/join — extend `registerGuide`; read-only client repo

**Files:**
- Modify: `functions/index.js` (extend `registerGuide`)
- Create: `lib/features/organization/data/organization_repository.dart` (reads only)
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/presentation/guide_login_screen.dart`
- Modify: `lib/shared/providers/providers.dart`

**Design note:** org creation/joining is **server-side only** (Admin SDK), because the rules
(Task 4) deny all client writes to `organizations`. Claims are set before the client signs in, so
the first ID token already contains `{ role: 'guide', orgId }` — no token-refresh dance needed.

- [ ] **Step 1: Extend the `registerGuide` callable**

In `functions/index.js`, replace the Phase-2 `registerGuide` with:
```javascript
/**
 * Registers a guide server-side and attaches them to an organisation:
 *  - newOrgName set  -> creates a new org (caller becomes owner) with a fresh invite code
 *  - joinOrgCode set -> joins the org whose inviteCode matches
 * Creates the Auth user, the users/{uid} profile, the org membership, and sets
 * custom claims { role: 'guide', orgId } BEFORE returning, so the client's
 * first sign-in token already carries them.
 */
const ORG_CODE_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function generateOrgInviteCode() {
  let s = "";
  for (let i = 0; i < 4; i++) {
    s += ORG_CODE_CHARSET[Math.floor(Math.random() * ORG_CODE_CHARSET.length)];
  }
  return `JOIN-${s}`;
}

exports.registerGuide = onCall(async (request) => {
  const { email, password, displayName, newOrgName, joinOrgCode } =
    request.data || {};
  if (!email || !password || !displayName || (!newOrgName && !joinOrgCode)) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const db = getFirestore();

  // Resolve or create the organisation FIRST (fail before creating the user).
  let orgId;
  if (newOrgName) {
    // Unique invite code.
    let code;
    let clash;
    do {
      code = generateOrgInviteCode();
      clash = await db.collection("organizations")
        .where("inviteCode", "==", code).limit(1).get();
    } while (!clash.empty);
    const orgRef = db.collection("organizations").doc();
    orgId = orgRef.id;
    // Org + owner membership are written after the user exists (below).
    var pendingOrg = { orgRef, name: newOrgName.trim(), inviteCode: code };
  } else {
    const match = await db.collection("organizations")
      .where("inviteCode", "==", joinOrgCode.trim().toUpperCase())
      .limit(1).get();
    if (match.empty) {
      throw new HttpsError("permission-denied", "invalid-invite-code");
    }
    orgId = match.docs[0].id;
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
  const uid = userRecord.uid;

  const batch = db.batch();
  if (typeof pendingOrg !== "undefined") {
    batch.set(pendingOrg.orgRef, {
      name: pendingOrg.name,
      ownerUid: uid,
      inviteCode: pendingOrg.inviteCode,
    });
    batch.set(pendingOrg.orgRef.collection("members").doc(uid), {
      role: "owner",
      displayName: displayName,
    });
  } else {
    batch.set(
      db.doc(`organizations/${orgId}/members/${uid}`),
      { role: "guide", displayName: displayName });
  }
  batch.set(db.doc(`users/${uid}`), {
    role: "guide",
    email: email,
    displayName: displayName,
    orgId: orgId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  // Claims BEFORE the client signs in -> first token already carries them.
  await getAuth().setCustomUserClaims(uid, { role: "guide", orgId: orgId });

  return { ok: true, orgId: orgId };
});
```
> The Phase-2 global `config/app.guideInviteCode` is now retired — org invite codes replace it.

- [ ] **Step 2: Read-only client repository**

Create `lib/features/organization/data/organization_repository.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/organization.dart';
import '../domain/org_member.dart';

/// Read-only: all organisation WRITES happen server-side in registerGuide.
class OrganizationRepository {
  final FirebaseFirestore _firestore;

  OrganizationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Organization?> getOrganization(String orgId) async {
    final doc =
        await _firestore.collection('organizations').doc(orgId).get();
    return doc.exists ? Organization.fromFirestore(doc) : null;
  }

  Stream<List<OrgMember>> watchMembers(String orgId) {
    return _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map(OrgMember.fromFirestore).toList());
  }
}
```
Add the provider in `providers.dart`:
```dart
final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(firestore: ref.watch(firestoreProvider));
});
```

- [ ] **Step 3: Update the client `registerGuide`**

In `auth_repository.dart`, change `registerGuide`'s signature and payload:
```dart
  Future<AppUser> registerGuide({
    required String email,
    required String password,
    required String displayName,
    String? joinOrgCode,
    String? newOrgName,
  }) async {
    try {
      await _functions.httpsCallable('registerGuide').call({
        'email': email,
        'password': password,
        'displayName': displayName,
        if (joinOrgCode != null) 'joinOrgCode': joinOrgCode,
        if (newOrgName != null) 'newOrgName': newOrgName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AuthFailure(code: e.message ?? e.code, message: e.message ?? e.code);
    }

    final credential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return getAppUser(credential.user!.uid);
  }
```

- [ ] **Step 4: Update the guide signup UI**

In `guide_login_screen.dart` (registration mode), replace the single invite-code field with a
two-option segmented control — **Join organisation** (shows an org-code field → `joinOrgCode`)
/ **Create organisation** (shows an org-name field → `newOrgName`) — and pass the chosen value to
`registerGuide`. Add strings `joinOrganization`, `createOrganization`, `organizationName`,
`organizationCode` to all three locales in `app_localizations.dart` (RO/HU with diacritics).

- [ ] **Step 5: Show the org invite code to owners**

In `guide_settings_screen.dart`, add a `ListTile` that (for the signed-in guide's org, via
`organizationRepositoryProvider.getOrganization(user.orgId)`) shows the org name and — if
`ownerUid == user.uid` — the org invite code with a copy button, so owners can invite other guides.

- [ ] **Step 6: Analyze + commit**

Run:
```bash
flutter analyze lib/features/organization lib/features/auth
```
Expected: no errors in these folders (whole-app threading finishes in Task 3).
```bash
cd /d/CampConnect
git add functions/index.js lib/features/organization lib/features/auth lib/shared/providers/providers.dart lib/core/l10n/app_localizations.dart
git commit -m "feat: server-side org create/join in registerGuide with claims; read-only org repo"
```

---

### Task 3: Scope camps + locations by orgId; top-level codes collection

**Files:**
- Modify: `lib/features/auth/data/camp_repository.dart`
- Modify: `lib/features/map/data/location_repository.dart`
- Modify: `lib/shared/providers/providers.dart`
- Modify: callers (`camp_session_screen.dart`, `location_form_screen.dart`, `master_locations_screen.dart`, `add_session_location_screen.dart`, `knowledge_base_editor_screen.dart`, `code_management_screen.dart`)

- [ ] **Step 1: Filter camps by orgId**

In `camp_repository.dart`:
```dart
  Stream<List<CampSession>> getCampSessionsForOrg(String orgId) {
    return _campsRef.where('orgId', isEqualTo: orgId).snapshots().map((snap) {
      final sessions = snap.docs.map(CampSession.fromFirestore).toList();
      sessions.sort((a, b) => b.startDate.compareTo(a.startDate));
      return sessions;
    });
  }
```
Delete `getAllCampSessions`. Add `required String orgId,` to `createCampSession`, store it on the
camp. Update `guideCampSessionsProvider`:
```dart
final guideCampSessionsProvider = StreamProvider<List<CampSession>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null || !user.isGuide || user.orgId == null) {
    return Stream.value([]);
  }
  return ref.watch(campRepositoryProvider).getCampSessionsForOrg(user.orgId!);
});
```
Update the create-session sheet to pass `orgId: user.orgId!`.

- [ ] **Step 2: Move master locations under the org**

In `location_repository.dart`, change the collection to `organizations/{orgId}/locations` and add
an `orgId` parameter to every method:
```dart
  CollectionReference<Map<String, dynamic>> _locationsRef(String orgId) =>
      _firestore.collection('organizations').doc(orgId).collection('locations');
```
Update `masterLocationsProvider` (and `resolvedSessionLocationsProvider`'s dependency) to thread
the org: for **guides** use `user.orgId`; for **kids** use the `orgId` on their user doc (set by
`claimCampCode` — Step 3 of Task 4 writes it). So:
```dart
final masterLocationsProvider = StreamProvider<List<Location>>((ref) {
  final orgId = ref.watch(appUserProvider).valueOrNull?.orgId;
  if (orgId == null) return Stream.value([]);
  return ref.watch(locationRepositoryProvider).watchAllLocations(orgId);
});
```
Thread `orgId` through the four map screens' repo calls. Move the Storage path in
`location_form_screen.dart` to `organizations/$orgId/locations/$locationId/photo.jpg`.

- [ ] **Step 3: Top-level `codes` as the source of truth**

In `camp_repository.dart`, change code generation and listing:
- `generateBulkCodes`/`generateCode` gain `required String orgId` and write to
  `_firestore.collection('codes').doc(code)` with
  `{ 'campId': campId, 'orgId': orgId, 'team': team, 'displayName': ..., 'used': false, 'createdBy': ... }`.
  Drop the per-camp `codes` subcollection writes entirely.
- Collision check + numbering query top-level `codes` filtered by `campId`.
- `getCodesForCamp(campId)` becomes
  `_firestore.collection('codes').where('campId', isEqualTo: campId).snapshots()`.
Update `code_management_screen.dart` callers to pass `orgId` (from `appUserProvider`).
(Single-field indexes cover these queries automatically; no composite index needed.)

- [ ] **Step 4: Analyze until clean**

Run:
```bash
flutter analyze lib
```
Expected: thread `orgId` until zero errors. This is the widest-reaching step (~6 screens).

- [ ] **Step 5: Commit**

```bash
git add lib
git commit -m "refactor: scope camps and locations by orgId; top-level codes collection"
```

---

### Task 4: Rules tightening with custom claims + claimCampCode single-get

**Files:**
- Modify: `firestore.rules`
- Modify: `storage.rules`
- Modify: `functions/index.js` (claimCampCode)
- Modify: `firestore-tests/firestore.test.js`

- [ ] **Step 1: Update `claimCampCode` to a single get on top-level codes**

Replace the Phase-2 collection-group scan version with:
```javascript
exports.claimCampCode = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const code = ((request.data && request.data.code) || "").trim().toUpperCase();
  if (!/^CAMP-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const db = getFirestore();
  const codeRef = db.doc(`codes/${code}`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists) throw new HttpsError("not-found", "invalid-code");
    const d = snap.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    const campSnap = await tx.get(db.doc(`camps/${d.campId}`));
    if (campSnap.exists) {
      const end = campSnap.data().endDate;
      if (end && end.toDate && end.toDate() < new Date()) {
        throw new HttpsError("failed-precondition", "session-expired");
      }
    }

    tx.update(codeRef, { used: true, usedBy: uid });
    tx.set(db.doc(`users/${uid}`), {
      role: "kid",
      displayName: d.displayName || "Campist",
      campId: d.campId,
      orgId: d.orgId,
      team: d.team,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      campId: d.campId,
      team: d.team,
      displayName: d.displayName || "Campist",
    };
  });
});
```

- [ ] **Step 2: Tighten `firestore.rules`**

Replace the interim guide checks with claim-based org scoping. Full updated rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }

    // Guides carry custom claims { role: 'guide', orgId } set at registration.
    function isGuideOfOrg(orgId) {
      return isSignedIn()
        && request.auth.token.role == 'guide'
        && request.auth.token.orgId == orgId;
    }

    function isAnyGuide() {
      return isSignedIn() && request.auth.token.role == 'guide';
    }

    // Kids have no claims; membership comes from their server-written profile.
    function isCampMember(campId) {
      return isSignedIn()
        && exists(/databases/$(database)/documents/users/$(request.auth.uid))
        && get(/databases/$(database)/documents/users/$(request.auth.uid))
             .data.campId == campId;
    }

    function campOrg(campId) {
      return get(/databases/$(database)/documents/camps/$(campId)).data.orgId;
    }

    match /config/{document=**} { allow read, write: if false; }

    match /users/{userId} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow create, delete: if false;
      allow update: if isSignedIn() && request.auth.uid == userId
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['campId']);
    }

    match /organizations/{orgId} {
      // Guides of the org can read it (name, invite code for owners' UI).
      allow read: if isGuideOfOrg(orgId);
      allow write: if false; // server-only (registerGuide)

      match /members/{uid} {
        allow read: if isGuideOfOrg(orgId);
        allow write: if false;
      }

      match /locations/{document=**} {
        // Kids need map locations too; their org is on their profile.
        allow read: if isGuideOfOrg(orgId)
          || (isSignedIn()
              && exists(/databases/$(database)/documents/users/$(request.auth.uid))
              && get(/databases/$(database)/documents/users/$(request.auth.uid))
                   .data.orgId == orgId);
        allow write: if isGuideOfOrg(orgId);
      }
    }

    match /camps/{campId} {
      allow read: if isCampMember(campId)
        || (isSignedIn() && isGuideOfOrg(resource.data.orgId));
      allow create: if isGuideOfOrg(request.resource.data.orgId)
        && request.resource.data.createdBy == request.auth.uid;
      allow update, delete: if isGuideOfOrg(resource.data.orgId);

      match /{sub}/{doc=**} {
        allow read: if isCampMember(campId) || isGuideOfOrg(campOrg(campId));
        allow write: if isGuideOfOrg(campOrg(campId));
      }
    }

    // Top-level codes: org guides manage their own org's codes; kids never
    // read them (claim goes through the claimCampCode function).
    match /codes/{code} {
      allow read, delete: if isAnyGuide()
        && request.auth.token.orgId == resource.data.orgId;
      allow create: if isAnyGuide()
        && request.auth.token.orgId == request.resource.data.orgId;
      allow update: if isAnyGuide()
        && request.auth.token.orgId == resource.data.orgId;
    }

    match /{document=**} { allow read, write: if false; }
  }
}
```
Update `storage.rules` similarly:
```
    match /organizations/{orgId}/locations/{locationId}/photo.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'guide'
        && request.auth.token.orgId == orgId;
    }
```
(keep the camps group-photo rule; scope its write to
`request.auth.token.role == 'guide'`).

- [ ] **Step 3: Update the rules tests**

In `firestore-tests/firestore.test.js`, custom claims are injected as the second argument of
`authenticatedContext`. Update guide contexts and add isolation tests:
```javascript
const orgGuide = (uid, orgId) =>
  testEnv.authenticatedContext(uid, { role: "guide", orgId }).firestore();

test("org isolation: a guide cannot read another org's camp", async () => {
  await seed(async (db) => {
    await db.doc("camps/camp-1").set({ orgId: "o1", createdBy: "g1", name: "A" });
    await db.doc("camps/camp-2").set({ orgId: "o2", createdBy: "g2", name: "B" });
  });
  const g1 = orgGuide("g1", "o1");
  await assertSucceeds(g1.doc("camps/camp-1").get());
  await assertFails(g1.doc("camps/camp-2").get());
});

test("org isolation: codes are only visible to the owning org's guides", async () => {
  await seed(async (db) => {
    await db.doc("codes/CAMP-AAAA").set({ orgId: "o1", campId: "camp-1", used: false });
  });
  await assertSucceeds(orgGuide("g1", "o1").doc("codes/CAMP-AAAA").get());
  await assertFails(orgGuide("g2", "o2").doc("codes/CAMP-AAAA").get());
  await assertFails(testEnv.authenticatedContext("kid-1").firestore()
    .doc("codes/CAMP-AAAA").get());
});

test("org locations: org guide writes; member kid reads; outsider denied", async () => {
  await seed(async (db) => {
    await db.doc("organizations/o1/locations/l1").set({ name: "Cave" });
    await db.doc("users/kid-1").set({ role: "kid", campId: "c1", orgId: "o1" });
    await db.doc("users/kid-2").set({ role: "kid", campId: "c9", orgId: "o2" });
  });
  await assertSucceeds(orgGuide("g1", "o1").doc("organizations/o1/locations/l1").get());
  await assertSucceeds(testEnv.authenticatedContext("kid-1").firestore()
    .doc("organizations/o1/locations/l1").get());
  await assertFails(testEnv.authenticatedContext("kid-2").firestore()
    .doc("organizations/o1/locations/l1").get());
  await assertFails(orgGuide("g2", "o2").doc("organizations/o1/locations/l1").set({ name: "x" }));
});
```
Also update the Phase-2 tests that seeded `users/{uid}.role == 'guide'` for guide checks — guide
identity now comes from claims, so give those contexts `{ role: "guide", orgId: "o1" }` and give the
seeded camps `orgId: "o1"`. Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add functions/index.js firestore.rules storage.rules firestore-tests/firestore.test.js
git commit -m "feat(security): claim-based org scoping; single-get code claim; org-scoped storage"
```

---

### Task 5: Scheduled server-side session cleanup

**Files:**
- Modify: `functions/index.js`
- Modify: `lib/features/auth/presentation/splash_screen.dart`
- Modify: `lib/features/auth/data/camp_repository.dart`

- [ ] **Step 1: Add the scheduled cleanup function**

```javascript
const { onSchedule } = require("firebase-functions/v2/scheduler");

exports.cleanupExpiredCamps = onSchedule("every 24 hours", async () => {
  const db = getFirestore();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 60);
  const expired = await db.collection("camps")
    .where("endDate", "<", cutoff).get();
  for (const camp of expired.docs) {
    // recursiveDelete clears all subcollections (teams, announcements, ...).
    await db.recursiveDelete(camp.ref);
    const codes = await db.collection("codes")
      .where("campId", "==", camp.id).get();
    const batch = db.batch();
    codes.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
});
```

- [ ] **Step 2: Remove the client-side cleanup**

Delete `cleanupExpiredSessions` from `camp_repository.dart` and its call in
`splash_screen.dart`. Verify:
```bash
grep -rn "cleanupExpiredSessions" lib
```
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add functions/index.js lib/features/auth
git commit -m "feat: scheduled server-side camp cleanup via recursiveDelete; drop client cleanup"
```

---

### Task 6: One-time prod migration script

**Files:**
- Create: `scripts/migrate_to_orgs.js`

The prod database has org-less data. **The new rules would lock existing users out**, so this script
must run against prod (with user authorization) BEFORE the prod deploy of Phase 5 rules/functions.

- [ ] **Step 1: Write the migration script**

Create `scripts/migrate_to_orgs.js` (same auth bootstrap pattern as `seed_firestore.js`):
```javascript
/* One-time migration to the multi-org model.
 * - Creates a default organization owned by DEFAULT_OWNER_UID.
 * - Backfills orgId on all camps and all guide user docs.
 * - Moves top-level locations/ -> organizations/{orgId}/locations/.
 * - Copies every camps/X/codes/Y into top-level codes/Y with campId+orgId.
 * - Sets custom claims { role, orgId } for every guide.
 * Usage: node migrate_to_orgs.js <projectId> <defaultOwnerUid> <orgName>
 */
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const [, , PROJECT_ID, DEFAULT_OWNER_UID, ...NAME_PARTS] = process.argv;
if (!PROJECT_ID || !DEFAULT_OWNER_UID || NAME_PARTS.length === 0) {
  console.error("Usage: node migrate_to_orgs.js <projectId> <ownerUid> <org name>");
  process.exit(1);
}
const ORG_NAME = NAME_PARTS.join(" ");

const SA = path.join(__dirname, "service-account.json");
admin.initializeApp(
  fs.existsSync(SA)
    ? { credential: admin.credential.cert(require(SA)), projectId: PROJECT_ID }
    : { projectId: PROJECT_ID }
);
const db = admin.firestore();

async function main() {
  // 1. Default org.
  const orgRef = db.collection("organizations").doc();
  await orgRef.set({
    name: ORG_NAME,
    ownerUid: DEFAULT_OWNER_UID,
    inviteCode: "JOIN-" + Math.random().toString(36).slice(2, 6).toUpperCase(),
  });
  console.log("Created org", orgRef.id);

  // 2. Guides -> members + orgId + claims.
  const guides = await db.collection("users").where("role", "==", "guide").get();
  for (const g of guides.docs) {
    await orgRef.collection("members").doc(g.id).set({
      role: g.id === DEFAULT_OWNER_UID ? "owner" : "guide",
      displayName: g.data().displayName || "",
    });
    await g.ref.update({ orgId: orgRef.id });
    await admin.auth().setCustomUserClaims(g.id, { role: "guide", orgId: orgRef.id });
    console.log("Migrated guide", g.id);
  }

  // 3. Camps -> orgId; codes -> top level; kids -> orgId.
  const camps = await db.collection("camps").get();
  for (const camp of camps.docs) {
    await camp.ref.update({ orgId: orgRef.id });
    const codes = await camp.ref.collection("codes").get();
    for (const c of codes.docs) {
      await db.doc(`codes/${c.id}`).set({
        ...c.data(),
        campId: camp.id,
        orgId: orgRef.id,
      });
    }
    console.log(`Migrated camp ${camp.id} (${codes.size} codes)`);
  }
  const kids = await db.collection("users").where("role", "==", "kid").get();
  for (const k of kids.docs) {
    await k.ref.update({ orgId: orgRef.id });
  }

  // 4. Locations -> under org.
  const locs = await db.collection("locations").get();
  for (const l of locs.docs) {
    await orgRef.collection("locations").doc(l.id).set(l.data());
    await l.ref.delete();
  }
  console.log(`Moved ${locs.size} locations. Done.`);
}

main().then(() => process.exit(0));
```

- [ ] **Step 2: Rehearse on dev**

Seed the dev project with legacy-shaped data (run `scripts/seed_firestore.js` pointed at dev), then:
```bash
cd /d/CampConnect/scripts && node migrate_to_orgs.js camp-connect-dev <your-dev-uid> "Tabăra Apuseni"
```
Verify in the console: org exists, camps/users have `orgId`, `codes/` populated, locations moved.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add scripts/migrate_to_orgs.js
git commit -m "feat: one-time migration script to the multi-org model"
```

---

### Task 7: Full-phase verification (on the dev project)

**Files:** none

- [ ] **Step 1: Rules + unit tests, analyze, build**

Run:
```bash
cd /d/CampConnect/firestore-tests && npm test
cd /d/CampConnect && flutter test && flutter analyze && flutter build apk --debug
```
Expected: all pass, no errors, builds.

- [ ] **Step 2: Deploy to DEV and integration-test**

```bash
firebase use dev
firebase deploy --only functions,firestore:rules,storage
```
With `flutter run --dart-define=USE_DEV=true`:
1. Guide A registers with **Create organisation** → org created; A sees the org invite code in settings.
2. Guide B registers with **Join organisation** + A's code → sees A's camps.
3. Guide C creates a different org → sees NO camps/locations of A/B (isolation).
4. Kid logs in with a code → single-read claim; lands in the right camp/team; map shows org locations.
5. Crafted cross-org reads fail (verify a rules denial appears in the debug log when C's account
   queries A's camp id directly).

- [ ] **Step 3: Final commit**

```bash
git commit --allow-empty -m "test: phase 5 multi-org verified on dev (isolation, onboarding, claim)"
```

---

## Notes for the implementer

- **Develop and test entirely on `dev`.** The prod rollout is a coordinated, user-authorized sequence:
  1) run `migrate_to_orgs.js` against prod, 2) `firebase use prod && firebase deploy --only
  functions,firestore:rules,storage`, 3) release the new app build. Old app versions cannot register
  or claim codes once the new functions/rules are live — plan the release window accordingly.
- **Existing signed-in guides must sign out/in once** after migration to receive their claims token
  (claims are set server-side but only enter the token on refresh; sign-out/in forces it — or wait
  up to an hour for auto-refresh).
- Phase-2 interim debts now cleared: claim-based guide checks, single-read kid login, server cleanup,
  per-org invite codes. The remaining rule `get()`s (kid membership, camp→org lookup) are bounded and
  acceptable; denormalize `orgId` onto subcollection docs later if they get hot.
- The FCM topics decision (kept, bodies treated as public) is recorded in the roadmap.
