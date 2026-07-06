# R8 — Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the technical-writer findings: an undocumented (and buggy) Cloud Functions error
contract, an undocumented FCM topic schema, no Firestore/Storage schema reference, no changelog, no
architecture overview, and no discoverable index of the hard decisions already recorded in dated
planning docs.

**Architecture:** This phase is almost entirely new/updated documentation plus one small,
concrete bug fix (the missing error-code branches). Run this phase last, after R1-R7, since it
partly documents the end state those phases produce — writing it first would mean rewriting it.

**Tech Stack:** Markdown, Dart (for the one bug fix), ARB/`gen-l10n`.

**Branch:** `remediation/r8-documentation`.

**Depends on:** R1-R7 substantially landed (or at least their final shape decided), since this
phase's architecture/schema docs describe that end state.

---

### Task 1: Fix the `weak-password`/`auth-create-failed` silent-fallthrough bug and document the `HttpsError` contract

**Files:**
- Modify: `lib/features/auth/presentation/guide_login_screen.dart` (`_friendlyError`)
- Modify: `lib/l10n/app_ro.arb`, `app_hu.arb`, `app_en.arb`
- Modify: `functions/lib/registerGuide.js`, `functions/lib/claimCampCode.js` (from R3) — add doc
  comments
- Test: `test/features/auth/friendly_error_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/friendly_error_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
// import the function/class under test — check the real export shape of
// _friendlyError (it may need to be made non-private, or tested indirectly
// through a small public wrapper, since Dart's `_` prefix is library-private;
// if so, add a package-visible `friendlyAuthError(String code)` function
// alongside it and have `_friendlyError` delegate to it).

void main() {
  group('friendlyAuthError', () {
    test('maps weak-password to a specific, non-generic message', () {
      final result = friendlyAuthError('weak-password');
      expect(result, isNot(contains('Something went wrong')));
    });

    test('maps auth-create-failed to a message (not silently generic-only by accident)', () {
      final result = friendlyAuthError('auth-create-failed');
      expect(result, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run and confirm it fails**

Run:
```bash
flutter test test/features/auth/friendly_error_test.dart
```
Expected: FAIL — either a compile error (function not public/importable yet) or, once that's
fixed, the `weak-password` case currently falls through to the generic message.

- [ ] **Step 3: Add the missing ARB key**

Add to `lib/l10n/app_en.arb`:
```json
  "weakPassword": "Password is too weak — please choose at least 8 characters.",
```
Add to `lib/l10n/app_ro.arb`:
```json
  "weakPassword": "Parola este prea slabă — alege cel puțin 8 caractere.",
```
Add to `lib/l10n/app_hu.arb`:
```json
  "weakPassword": "A jelszó túl gyenge — válassz legalább 8 karaktert.",
```
Run `flutter gen-l10n`.

- [ ] **Step 4: Add the missing branches to `_friendlyError`**

In `guide_login_screen.dart`, find the existing `_friendlyError` chain of `if (msg.contains(...))`
checks and add, before the final generic fallback:
```dart
if (msg.contains('weak-password')) return AppLocalizations.of(context).weakPassword;
if (msg.contains('auth-create-failed')) return AppLocalizations.of(context).somethingWentWrong;
```
If `_friendlyError` is private and the test in Step 1 needs a public entry point, extract its body
into a top-level `String friendlyAuthError(String code, AppLocalizations l10n)` function in the same
file (or a small `lib/features/auth/presentation/friendly_auth_error.dart` file), and have both
`guide_login_screen.dart` and `kid_login_screen.dart` call the same shared function instead of each
maintaining an independent copy — this also closes the review's separate observation that the
mapping is duplicated across two files.

- [ ] **Step 5: Run the test again and confirm it passes**

Run:
```bash
flutter test test/features/auth/friendly_error_test.dart
```
Expected: PASS, 2/2.

- [ ] **Step 6: Document the full `HttpsError` contract at the source**

In `functions/lib/registerGuide.js` (from R3), add a doc comment above the exported handler:
```javascript
/**
 * registerGuide(db, authAdmin, data)
 *
 * data: { email, password, displayName, newOrgName? , joinOrgCode? }
 *
 * Throws HttpsError with one of:
 *   invalid-argument   ("missing-fields" | "weak-password") — bad input
 *   permission-denied  ("invalid-invite-code") — joinOrgCode didn't match any org
 *   already-exists     ("email-already-in-use") — Auth user already exists
 *   internal           ("auth-create-failed") — unexpected Auth Admin SDK failure
 *   resource-exhausted ("too-many-attempts") — rate limit (see R2 Task 4)
 *
 * On success: creates the Auth user, sets custom claims { role: 'guide', orgId },
 * and either creates a new organizations/{orgId} doc (newOrgName) or joins an
 * existing one (joinOrgCode). Returns { ok: true }.
 */
```
Add the equivalent comment to `functions/lib/claimCampCode.js`:
```javascript
/**
 * claimCampCode(db, auth, data)
 *
 * data: { code }  — must match /^CAMP-[A-Z0-9]{4}$/
 *
 * Throws HttpsError with one of:
 *   unauthenticated     — no auth context (caller must be anonymously signed in first)
 *   invalid-argument    ("invalid-code") — malformed code string
 *   not-found           ("invalid-code") — well-formed code doesn't exist
 *   failed-precondition ("session-expired") — the code's camp has already ended
 *   already-exists      ("code-used") — code was already claimed
 *   resource-exhausted  ("too-many-attempts") — rate limit (see R2 Task 4)
 *
 * On success: atomically marks the code used, creates the kid's users/{uid}
 * profile, and returns { campId, team, displayName }.
 */
```

- [ ] **Step 7: Run the full Dart and Cloud Functions suites**

Run:
```bash
flutter test && flutter analyze
cd /d/CampConnect/functions && npm test
```

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add lib/features/auth/presentation/guide_login_screen.dart lib/features/auth/presentation/kid_login_screen.dart lib/l10n/*.arb test/features/auth/friendly_error_test.dart functions/lib/registerGuide.js functions/lib/claimCampCode.js
git commit -m "fix: handle weak-password/auth-create-failed error codes; document HttpsError contract"
```

---

### Task 2: Firestore/Storage schema reference

**Files:**
- Create: `docs/firestore-schema.md`

- [ ] **Step 1: Compile the schema from the real, current source of truth**

Read `firestore.rules`, `storage.rules`, and each feature's `domain/` model classes (e.g.
`lib/features/auth/domain/camp_session.dart`, `lib/features/organization/domain/organization.dart`,
`lib/features/leaderboard/domain/team.dart`, `lib/features/announcements/domain/announcement.dart`,
`lib/features/emergency/domain/emergency_alert.dart`, `lib/features/map/domain/location.dart`) —
these are the ground truth, not this plan's guesses about exact field names. Fill in the table
below for each collection using this template:

Create `docs/firestore-schema.md`:
```markdown
# Firestore & Storage Schema

Compiled from `firestore.rules`, `storage.rules`, and each feature's `domain/` model classes —
treat those files as the source of truth if this document ever drifts from them.

## Firestore collections

| Path | Written by | Key fields | Notes |
|---|---|---|---|
| `organizations/{orgId}` | `registerGuide` callable only | `name`, `ownerUid` | Client writes denied |
| `organizations/{orgId}/members/{uid}` | `registerGuide` callable only | `role` | |
| `organizations/{orgId}/locations/{locationId}` | guides (org-scoped) | `name`, `description`, photo ref | Master map locations |
| `users/{uid}` | server-only (`registerGuide`/`claimCampCode`) for create; client may update `campId` only | `role`, `orgId`, `campId`, `team`, `displayName` | |
| `camps/{campId}` | guides (org-scoped) | `orgId`, `createdBy`, `name`, `startDate`, `endDate` | |
| `camps/{campId}/teams/{teamId}` | guides | `name`, `colorHex`, `points` | |
| `camps/{campId}/announcements/{id}` | guides | `text`, `createdAt` | Triggers `onAnnouncementCreated` |
| `camps/{campId}/emergencyAlerts/{id}` | guides | `senderId`, `message`, `createdAt` | Triggers `onEmergencyAlertCreated` |
| `camps/{campId}/pointsHistory/{id}` | guides | `teamId`, `amount`, `reason` | Triggers `onPointsChanged` |
| `camps/{campId}/sessionLocations/{id}` | guides | `name`, group photo ref | |
| `codes/{code}` (top-level) | `registerGuide`/`claimCampCode` callables only | `campId`, `orgId`, `team`, `used`, `usedBy`, `displayName` | Doc ID is the code itself |
| `rateLimits/{key}` | Cloud Functions only (R2) | `count`, `windowStart` | Never client-readable |
| `config/{doc}` | — | — | **Verify**: confirm whether this collection is still used post-multi-org-refactor (the original global `guideInviteCode` design predates per-org invite codes) or is legacy/unused; update or remove this row once confirmed |

## Cloud Storage paths

| Path | Written by | Notes |
|---|---|---|
| `organizations/{orgId}/locations/{locationId}/photo.jpg` | org-scoped guides | Size/content-type enforced (R2 Task 5) |
| `camps/{campId}/sessionLocations/{sessionLocId}/group_photo.jpg` | org-scoped guides | May contain images of children; deleted on camp cleanup (R5 Task 9) |
```

- [ ] **Step 2: Verify every row against the real rules/model files**

Run:
```bash
grep -n "match /" firestore.rules storage.rules
```
Cross-check every path in the table above against this output — add any collection this grep
surfaces that the table is missing, and remove/correct any row that doesn't match a real rule.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add docs/firestore-schema.md
git commit -m "docs: add a Firestore/Storage schema reference"
```

---

### Task 3: Architecture overview document

**Files:**
- Create: `docs/architecture.md`

- [ ] **Step 1: Write the three critical data-flow narratives**

Create `docs/architecture.md`:
```markdown
# Architecture

## System overview

Flutter app (Android/iOS) ↔ Firebase (Auth, Firestore, Storage, Cloud Messaging) ↔ Cloud Functions
(Node 20, `functions/`). No custom backend server — Cloud Functions + Firestore/Storage security
rules are the entire server-side surface. See `docs/firestore-schema.md` for the data model.

## Critical flow 1: Guide registration

1. Guide submits email/password/displayName + either a new org name or an existing org's invite
   code, from `guide_login_screen.dart`.
2. The client calls the `registerGuide` Cloud Function (App Check-enforced and rate-limited as of
   R2) — see `functions/lib/registerGuide.js` for the full contract.
3. Server-side only: validates the invite code (if joining) or creates a new
   `organizations/{orgId}` doc (if founding), creates the Firebase Auth user, and sets custom
   claims `{ role: 'guide', orgId }` — the client never writes a role or org membership directly.
4. The client then signs in with the just-created credentials.

## Critical flow 2: Kid code claim

1. Kid enters a `CAMP-XXXX` code from `kid_login_screen.dart`.
2. The client signs in anonymously first (so the callable below has an auth context), then calls
   the `claimCampCode` Cloud Function — see `functions/lib/claimCampCode.js` for the full contract.
3. Server-side, inside a Firestore transaction: looks up `codes/{code}` (a single document get, not
   a collection scan), checks it's unused and the camp hasn't ended, marks it used, and creates the
   kid's `users/{uid}` profile with `campId`/`team`/`displayName`.
4. On any failure, the client deletes the anonymous Auth user it just created and signs out, so a
   failed claim doesn't leave an orphaned anonymous account.

## Critical flow 3: Emergency alert fan-out

1. A guide writes a new `camps/{campId}/emergencyAlerts/{id}` document from `emergency_screen.dart`
   (rules restrict this write to guides of that camp's org).
2. The Firestore trigger `onEmergencyAlertCreated` fires and sends an FCM push to the
   `camp_{campId}_guides` topic (see the FCM topic schema below).
3. **Known tradeoff (recorded 2026-07-02, still true):** FCM topic names aren't access-controlled,
   so notification bodies are treated as effectively public — the emergency composer UI reminds
   guides of this (R6 Task 3), and it's disclosed in the privacy policy's push-notifications
   section.

## FCM topic schema

| Topic pattern | Subscribers | Published by |
|---|---|---|
| `camp_{campId}_kids` | all kids in a camp | `onAnnouncementCreated`, `onPointsChanged` |
| `camp_{campId}_guides` | all guides in a camp's org | `onAnnouncementCreated`, `onEmergencyAlertCreated`, `onPointsChanged` |
| `camp_{campId}_team_{teamId}` | kids on a specific team | `onPointsChanged` (team-specific points updates) |

Verify the exact topic-string format against `functions/index.js` (the trigger functions) and
`lib/shared/services/fcm_service.dart` (the subscribe calls) before relying on this table — update
it if either side's format ever changes, since a mismatch here would silently break notifications.

## Firebase project topology

See R5's addition to `README.md`'s Configuration section for the current dev/prod project split.
```

- [ ] **Step 2: Verify the FCM topic patterns against the real code**

Run:
```bash
grep -n "camp_" functions/index.js lib/shared/services/fcm_service.dart
```
Confirm the table's patterns match exactly; correct the table if not.

- [ ] **Step 3: Commit**

```bash
cd /d/CampConnect
git add docs/architecture.md
git commit -m "docs: add an architecture overview covering the three critical data flows"
```

---

### Task 4: Start a CHANGELOG

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Seed the file**

Create `CHANGELOG.md`:
```markdown
# Changelog

All notable user-visible changes to CampConnect are recorded here, starting from the first store
submission. Earlier history (the 8-phase production build-out) is documented in
`docs/superpowers/plans/` rather than backfilled here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Firebase App Check and rate limiting on all sensitive Cloud Functions callables.
- A dev Firebase project, separate from production.
- CI pipeline running Flutter, Cloud Functions, and Firestore-rules tests on every push.
- Firestore/Storage schema and architecture documentation.
- In-app links to the privacy policy from Settings and both onboarding forms.

### Changed
- Org invite codes now generated with a cryptographically secure RNG at higher entropy.
- Guide password minimum raised from 6 to 8 characters.

### Fixed
- Hardcoded emergency-red colors now use the theme's `colorScheme.error` token.
- Map markers meet the 48dp touch-target minimum and show tap feedback.
- `cleanupExpiredCamps` now also deletes the corresponding Storage photos, not just Firestore docs.
- A guide entering a weak password now sees a specific error instead of a generic one.

### Security
- Storage rules now enforce content-type and size limits on photo uploads.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add CHANGELOG.md
git commit -m "docs: start a CHANGELOG ahead of the first store submission"
```

---

### Task 5: Add a `firestore-tests/` README

**Files:**
- Create: `firestore-tests/README.md`

- [ ] **Step 1: Write it**

Create `firestore-tests/README.md`:
```markdown
# Firestore & Storage rules tests

Two suites, run against the Firebase emulator via `npm test` (see `package.json` — it wraps
`firebase emulators:exec`):

- `firestore.test.js` — Firestore security rules: org isolation, role-escalation prevention,
  code/camp/team access scoping, the `rateLimits` collection lockdown (R2).
- `storage.test.js` — Storage rules: photo read/write authorization, content-type/size enforcement
  (R2).

## Adding a new rule test

Follow the existing `assertSucceeds`/`assertFails` pattern in either file — seed fixture data with
the `seed()` helper (which bypasses rules via `withSecurityRulesDisabled`), then assert the
behavior you expect under the real rules from an `authenticatedContext`/`unauthenticatedContext`.
Run `npm test` locally before pushing; the CI workflow (`.github/workflows/ci.yml`, added in R5)
runs this suite on every push/PR automatically.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add firestore-tests/README.md
git commit -m "docs: add a README for the firestore-tests suite"
```

---

### Task 6: Add a "Key decisions" pointer section to `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the section**

Add to `README.md`, near the "Architecture" section:
```markdown
## Key decisions (with full rationale in `docs/superpowers/plans/`)

- **Anonymous kid auth, no self-registration** — `docs/superpowers/plans/2026-07-02-phase2-security-hardening.md`
- **FCM topic names are not access-controlled; treat notification bodies as public** —
  `docs/superpowers/plans/00-campconnect-production-roadmap.md` (Phase 5 section) and
  `docs/architecture.md`
- **Per-org invite codes replacing a single global code** —
  `docs/superpowers/plans/2026-07-02-phase5-multi-org.md`
- **Legitimate interest (not consent) as the legal basis for kids' minimal data, with Article 8
  judged not to apply** — `docs/privacy-policy.md` ("Legal basis" section, rewritten in R6)
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add README.md
git commit -m "docs: add a Key Decisions index pointing into the existing planning docs"
```

---

## Post-phase verification

- [ ] `flutter test` includes and passes `friendly_error_test.dart`.
- [ ] `docs/firestore-schema.md` and `docs/architecture.md` both exist and their tables have been
  checked against a live `grep` of the real rules/trigger code, not left as first-draft guesses.
- [ ] `CHANGELOG.md`, `firestore-tests/README.md`, and the README "Key decisions" section all exist.
- [ ] Update the master remediation checklist (`00-verify-team-remediation-roadmap.md`) — this
  should be the last box checked, since R8 documents the end state of everything before it.
