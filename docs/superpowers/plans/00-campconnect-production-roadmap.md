# CampConnect Production Roadmap (Master Plan)

> **Purpose:** This is the index + sequencing document for turning CampConnect from a
> single-camp thesis project into a multi-organiser app shippable on the App Store and
> Google Play. Each **Phase** below is (or will be) its own standalone plan file that
> produces working, testable software on its own. Implement phases in the order given —
> later phases depend on decisions locked in by earlier ones.

**Overall goal:** Ship a secure, multi-organiser, bilingual (RO/HU + EN) summer-camp app on
both stores, tested on real Android and iOS devices, built from a Windows laptop with no Mac.

**Current state (verified 2026-07-02):**
- Flutter 3.11 / Dart 3.11, Firebase (Auth, Firestore, Storage, Messaging, Functions).
- ~11,400 lines Dart, feature-first architecture, manual Riverpod 2 (`StateNotifier`).
- Single global guide invite code; all guides see all camps; kids sign in anonymously.
- `flutter analyze` is clean (2 trivial infos). Test suite is effectively empty outside the LLM feature.
- On-device LLM (fllama, git dependency) slated for removal.
- Firestore/Storage rules are wide open (any authenticated user can read/write any camp).

---

## Phase sequencing & dependency graph

```
Phase 1  LLM Removal ─────────────┐  (no dependencies; do first — unblocks iOS builds)
Phase 2  Security Hardening ──────┤  (independent; URGENT — exploitable on live backend)
Phase 3  Critical Bug Batch ──────┘  (independent of each other; can interleave)
                │
                ▼
Phase 4  Teams-as-Data ───────────┐  (depends on 2 for rules; feeds 5)
Phase 5  Multi-Organiser Refactor ┘  (depends on 2 + 4; the big structural change)
                │
                ▼
Phase 6  l10n Migration (gen-l10n + diacritics)  (depends on nothing but touches every
                │                                  screen; do after 5 so new screens exist)
                ▼
Phase 7  iOS Enablement (config fixes + Codemagic + TestFlight)
                │
                ▼
Phase 8  Store Release (Crashlytics, account deletion, privacy, listings, closed test)
```

**Rule of thumb:** Phases 1–3 are safe to do immediately and in any order. Phase 2 is the
most urgent because the invite-code leak and open rules are exploitable *today* on the live
Firebase project. Phases 4–5 are the heavy refactor. Phases 6–8 are polish + release.

---

## Phase 1 — LLM Removal
**Plan file:** `2026-07-02-phase1-llm-removal.md` (written — ready to execute)
**Why first:** The `fllama` git dependency breaks reproducible/cloud iOS builds; a 0.5B model
chatting with children is a content-safety liability; removing it deletes ~1,500 lines and
simplifies every later phase.
**Deliverable:** App builds and runs with all LLM code, deps, tests, settings keys, storage
rules, and the model-download UX gone. Map pin detail still shows the knowledge-base text.
**Acceptance:** `flutter analyze` clean; app launches; location detail renders KB with no chat
button; `grep -ri "llm\|fllama\|Llama" lib` returns nothing.

## Phase 2 — Security Hardening
**Plan file:** `2026-07-02-phase2-security-hardening.md` (rev. 2 — ready to execute)
**Why urgent:** (1) `config/app.guideInviteCode` is world-readable → anyone registers as guide.
(2) `camps/**` world-readable → all kid codes enumerable/hijackable pre-auth. (3) Storage photos
of children world-readable. (4) Code-claim isn't atomic → two kids can claim one code.
(5) Role self-escalation: users can write `role: 'guide'` into their own profile doc, so the invite
gate can be bypassed entirely — which is why registration must move server-side, not just validation.
**Deliverable:** Firestore + Storage rules locked down with a rules-unit-test suite; **guide
registration (`registerGuide`) and code-claiming (`claimCampCode`) run fully server-side in callable
Cloud Functions** (Admin SDK writes the profiles; clients can never write a role);
`@firebase/rules-unit-testing` harness in CI.
**Acceptance:** Rules test suite passes (allow legit, deny illegit, deny escalation); unauthenticated
read of `config/app` and `camps/*/codes` is denied; a client cannot create/alter its own profile
role; two concurrent claims of one code → exactly one wins.
**Note:** Some rules here are intentionally *interim* (e.g. member checks) and get tightened again
in Phase 5 when `organizations` + custom claims exist. The plan flags each such rule.

## Phase 3 — Critical Bug Batch
**Plan file:** `2026-07-02-phase3-bug-batch.md` (written — ready to execute)
**Scope (from the deep sweep — each is a small, independent fix):**
- Last-day lockout: store camp `endDate` as end-of-day / compare date-only
  (`camp_session.dart:27`, `auth_repository.dart:134`).
- Kid team-topic subscription races on `null` team (`kid_login_screen.dart:58-66`) — invalidate then read.
- Emergency overlay stacks duplicate dialogs (`emergency_overlay.dart:20`) — add "already shown" guard.
- Session delete orphans all subcollections + any guide can delete any camp (`camp_session_screen.dart:139`).
- Bulk code generation >500 crashes (batch cap) + no upper bound in dialog (`camp_repository.dart:210`).
- copyWith can't clear optional fields → can't remove schedule end time (`announcement.dart:89`).
- Journal Hive box not namespaced by uid → shared between users on one device (`journal_local_storage.dart:10`).
- No forgot-password flow for guides.
- Foreground FCM never displayed (no local-notifications plugin wired).
- Logout failure shows LLM error string (`guide_settings_screen.dart:124`) — will already be
  partly handled by Phase 1; verify.
- Splash can hang if no auth-state change fires (`splash_screen.dart:16`).
- Date-range validation (start after end accepted); `_parseTime` crashes on malformed input.
**Acceptance:** Each bug has a repro reference and a test or documented manual verification.
**Deferred to their own phases (not here):** teams-that-don't-exist code bug (fixed by Phase 4),
Romania-locked map + OSM tile policy (Phase 7), diacritics/PDF font (Phase 6).

## Phase 4 — Teams-as-Data
**Plan file:** `2026-07-02-phase4-teams-as-data.md` (written — ready to execute)
**Scope:** Replace hard-coded color-key teams with `camps/{campId}/teams/{teamId}` docs holding
`{ name, colorHex, points }`. Guide gets a master-locations-style Teams management UI (add / edit /
delete, preset palette + custom color). Create-session pre-fills the 4 classic teams as editable rows.
Deletes the triple-duplicated team-name maps (Dart `team_colors.dart`, l10n maps, functions
`teamNames`). Cloud Function reads team `name` from the doc. Guard rails: block/reassign on deleting a
team that has kids or points; allow adding mid-camp.
**Depends on:** Phase 2 (rules must cover the `teams` subcollection writes by role).
**Acceptance:** Guide can create a camp with custom teams; codes can only be generated for teams that
exist (fixes sweep #11); notifications show the guide-typed team name; deleting a populated team is guarded.

## Phase 5 — Multi-Organiser Refactor
**Plan file:** `2026-07-02-phase5-multi-org.md` (rev. 2 — ready to execute)
**Scope:** Introduce `organizations/{orgId}` with `{ name, ownerUid, inviteCode }` +
`members/{uid}` (role: owner|guide). **All org writes happen server-side inside the extended
`registerGuide` callable** (create-or-join + custom claims `{role, orgId}` set before first sign-in);
rules deny client org writes. Add `orgId` to every camp; filter all camp queries by `orgId`. Move
master `locations` under the org. Introduce a top-level `codes/{code}` → `{campId, orgId, team,
used}` collection so kid login is a single `get()`. Tighten Phase-2 interim rules to claim-based
org checks. Move session cleanup to a scheduled Cloud Function using `recursiveDelete()`. Includes a
**one-time prod migration script** (`scripts/migrate_to_orgs.js`) that must run before the prod
deploy, and a dev-Firebase-project split so nothing is developed against prod.
**FCM decision (recorded):** topics are retained for now; because topic names are not
access-controlled, every notification body is treated as public information. Token-based fan-out is
deferred to a post-launch hardening pass.
**Depends on:** Phase 2 (rules foundation) + Phase 4 (teams live under camp).
**Acceptance:** Two organisers cannot see/edit each other's camps or locations; kid login resolves via
top-level `codes` in one read; custom claims enforced in rules; cleanup runs server-side on schedule.

## Phase 6 — l10n Migration
**Plan file:** `2026-07-02-phase6-l10n.md` (written — ready to execute)
**Scope:** Migrate the hand-rolled 1,348-line `AppLocalizations` to Flutter `gen-l10n` (ARB files
`app_ro.arb`/`app_hu.arb`/`app_en.arb`) with compile-time-safe keys and ICU plurals. Restore Romanian
+ Hungarian diacritics everywhere (UI strings, Cloud Function notification strings, notification
channel names). Embed a Unicode TTF (Noto Sans) in the journal PDF so ș/ț/ă/ő/ű render. Make all
`DateFormat` calls locale-aware. English map already exists — carries over.
**Depends on:** best done after Phase 5 so all screens (incl. new org/teams screens) exist to translate once.
**Acceptance:** All three locales render with correct diacritics; PDF exports Romanian text correctly;
a missing key is a compile error, not a silent Romanian fallback.

## Phase 7 — iOS Enablement (build from Windows, no Mac)
**Plan file:** `2026-07-02-phase7-ios.md` (written — ready to execute)
**Scope — code/config (done from Windows):** Add `NSCameraUsageDescription`,
`NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist`;
make journal export use `Printing.sharePdf` on iOS instead of the Android-only MethodChannel; change
APNs `interruption-level: critical` → `time-sensitive` in `functions/index.js:197` and drop
`criticalAlert: true` in `fcm_service.dart:13`; switch map tiles off `tile.openstreetmap.org` to a
keyed provider (MapTiler/Stadia) — required by OSM policy for store distribution.
**Scope — operational (no Mac needed):** Enroll Apple Developer Program ($99/yr); set up **Codemagic**
(free tier, 500 macOS min/mo) with **automatic code signing via App Store Connect API key** (no
Keychain/Xcode ever); configure the `codemagic.yaml` workflow to build + sign + upload to TestFlight on
push; acquire one used physical iPhone (~€120–180) for real-device testing (simulators can't do FCM and
don't exist on Windows anyway). Escape hatch for interactive macOS debugging: rent MacinCloud / Scaleway
Apple-silicon by the hour.
**Depends on:** Phase 1 (fllama removed) — mandatory before any iOS cloud build will succeed.
**Acceptance:** Green Codemagic build produces a signed `.ipa`; app installs via TestFlight on the test
iPhone; camera, GPS, map, FCM push, and PDF share all work on-device.

## Phase 8 — Store Release
**Plan file:** `2026-07-02-phase8-store-release.md` (written — ready to execute)
**Scope:** Firebase Crashlytics (configured to avoid identifiers for kid/anonymous users); in-app
**account deletion** for guides + kid-data deletion path (Apple requirement; honors 2026 consent-
revocation signals); privacy policy URL; Google Play **Data Safety** form + Apple **privacy nutrition
labels**; complete both stores' 2026 age-rating questionnaires; declare **mixed audience** (organisers +
children) rather than "Made for Kids" to keep FCM/Crashlytics usable; store listings, screenshots, review
notes explaining the invite-code onboarding; Google Play **closed test with 12+ testers for 14 days**
(required for personal developer accounts before production).
**Depends on:** everything above (needs the secured, multi-org, bilingual, iOS-capable app).
**Acceptance:** Both store submissions pass review; account deletion verified end-to-end; closed test
completed; production release live.

---

## Cross-cutting conventions (apply in every phase)

- **Branching:** one branch per phase, e.g. `phase1-llm-removal`. Never commit to `main` directly.
  Do NOT commit or push unless the user explicitly asks (project rule).
- **Commits:** small and frequent, `type: what changed` (feat/fix/refactor/test/docs/chore).
- **After every code change:** run `flutter analyze` and the relevant tests before committing.
- **UI language:** all user-facing strings go through `AppLocalizations` — never hard-code
  Romanian/Hungarian/English literals in widgets.
- **Testing reality:** the repo has no meaningful test infrastructure yet. Phase 2 introduces the
  Firestore rules-test harness; repository/unit tests use `fake_cloud_firestore` +
  `firebase_auth_mocks`. Where a widget test would be disproportionate, the plan specifies an explicit
  manual verification instead — but logic in repositories and Cloud Functions must have automated tests.
- **Firebase project safety:** there is currently ONE Firebase project serving real-ish data. Before
  Phase 5, create a **separate `dev` Firebase project + build flavors** so refactor experiments don't hit
  a database a real camp would use. (Tracked as the first task of Phase 5.)
- **Coordinated deploys:** Phases 2 and 5 change the auth contract between app and backend. Deploy
  functions + rules together and ship the matching app build promptly — an old app against new rules
  cannot register/claim, and new app against old rules leaves holes open. Phase 5 additionally requires
  the prod migration script to run BEFORE its rules go live. Both projects must be on the Blaze plan
  (the prod project already is — it runs Cloud Functions).

---

## Quick status checklist

- [x] Phase 1 — LLM Removal
- [x] Phase 2 — Security Hardening
- [ ] Phase 3 — Critical Bug Batch
- [ ] Phase 4 — Teams-as-Data
- [ ] Phase 5 — Multi-Organiser Refactor
- [ ] Phase 6 — l10n Migration
- [ ] Phase 7 — iOS Enablement
- [ ] Phase 8 — Store Release
