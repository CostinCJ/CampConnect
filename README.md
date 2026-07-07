# CampConnect

A multi-organiser, bilingual (Romanian/Hungarian, plus English) summer-camp
mobile app for guides and campers ("kids"), built with Flutter and Firebase.

Guides register an organisation (or join one with an invite code), create camp
sessions, manage teams, generate per-kid join codes, post announcements and
schedules, run a points leaderboard, share a camp map, and send emergency
alerts. Kids join a camp with a `CAMP-XXXX` code (anonymous sign-in), view camp
info, and keep an on-device journal.

## Architecture

- **Flutter 3.11 / Dart 3.11**, feature-first layout under `lib/features/*`
  (`data` / `domain` / `presentation`), shared code in `lib/core` and
  `lib/shared`.
- **State:** Riverpod 2 (providers in `lib/shared/providers/providers.dart`).
- **Routing:** `go_router` (`lib/core/router/app_router.dart`).
- **Backend:** Firebase — Auth, Firestore, Storage, Cloud Messaging, and
  callable/scheduled Cloud Functions (`functions/`).
- **Localization:** Flutter `gen-l10n` from ARB files in `lib/l10n`.

### Security model (important)

- Guides are created **server-side** by the `registerGuide` Cloud Function,
  which sets custom claims `{ role: 'guide', orgId }`. Clients can never write a
  role or forge org membership.
- Kids sign in anonymously and claim a code via the `claimCampCode` function,
  which writes their profile (`campId`, `orgId`, `team`) server-side. A kid's
  `campId` is immutable on the client.
- Firestore/Storage access is org- and camp-scoped in `firestore.rules` /
  `storage.rules`, enforced against those claims and the server-set profile.
  The rules have a unit-test suite in `firestore-tests/`.

## Key decisions (with full rationale in `docs/superpowers/plans/`)

- **Anonymous kid auth, no self-registration** — `docs/superpowers/plans/2026-07-02-phase2-security-hardening.md`
- **FCM topic names are not access-controlled; treat notification bodies as public** —
  `docs/superpowers/plans/00-campconnect-production-roadmap.md` (Phase 5 section) and
  `docs/architecture.md`
- **Per-org invite codes replacing a single global code** —
  `docs/superpowers/plans/2026-07-02-phase5-multi-org.md`
- **Legitimate interest (not consent) as the legal basis for kids' minimal data, with Article 8
  judged not to apply** — `docs/privacy-policy.md` ("Legal basis (GDPR)" section, rewritten in R6)

## Prerequisites

- Flutter SDK (stable, matching `environment.sdk` in `pubspec.yaml`).
- A Firebase project (Blaze plan — Cloud Functions are used).
- Node.js 20+ for `functions/` and the rules tests.
- A [MapTiler](https://www.maptiler.com/) API key for map tiles.

## Configuration (not committed)

These files are gitignored and must be provided locally / in CI:

- `lib/firebase_options.dart` — generate with `flutterfire configure`
  (a template is in `lib/firebase_options.template.dart`).
- `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist` — from the Firebase console.
- `android/key.properties` + an upload keystore for Android release signing —
  see `android/key.properties.example`.

The MapTiler key is passed at build time, never committed. Copy `dart_defines.example.json` to
`dart_defines.local.json` (gitignored) and fill in your key, then pass it with
`--dart-define-from-file=dart_defines.local.json` on every `flutter run` / `flutter build` — see
below. There's no default: if this flag is omitted, `AppConstants.maptilerKey` compiles to an
empty string, every tile request gets a `403 Missing key` from MapTiler, and the map renders
blank/white with no error surfaced in the UI. `.vscode/launch.json` (gitignored, like the rest of
`.vscode/`) already wires this flag in for VS Code's Run/Debug — recreate it locally if it's
missing, or use `--dart-define-from-file` directly from the terminal.

### Firebase project topology

Two Firebase projects exist: `camp-connect-4644c` (production, alias `default`) and
`campconnect-dev` (development, alias `dev`). Day-to-day development and manual testing should
target `dev` (`firebase use dev`); only deploy to `default` deliberately, with the user's explicit
go-ahead. The automated test suites (`flutter test`, `functions/`'s Jest suites, `firestore-tests/`)
all run against the local emulators and don't depend on either live project.

For the Flutter app, the dev project's config is generated as `lib/firebase_options_dev.dart`
(gitignored, same as the production `lib/firebase_options.dart`) via:

```
flutterfire configure --project=campconnect-dev --out=lib/firebase_options_dev.dart
```

Both files coexist untracked locally; switch which one `main.dart` imports (or wire up Flutter
build flavors later) depending on whether you're pointed at `dev` or `default`.

**Footgun to watch for:** `firebase use` (CLI deploy target) and the `firebase_options*.dart`
import in `main.dart` (Flutter app target) are two independently-forgettable settings — there's no
automated check that they match. Before deploying or doing anything prod-affecting, confirm both
point at the same project; it's possible to run the app against `dev` while `firebase deploy`
targets `default` (or vice versa) without any warning. App IDs embedded in `firebase.json`'s
`flutter` block are not secrets and are safe to have committed — only the API keys inside the
gitignored `firebase_options*.dart` files need to stay out of git.

## Running

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=dart_defines.local.json
```

To run against local Firebase emulators, start them (`firebase emulators:start`)
and launch with `--dart-define=USE_EMULATORS=true`.

## Building for release

```bash
# Android (requires android/key.properties + keystore)
flutter build appbundle --release --dart-define-from-file=dart_defines.local.json
flutter build apk --release --dart-define-from-file=dart_defines.local.json

# iOS is built + signed + shipped to TestFlight via Codemagic (codemagic.yaml)
```

## Tests

```bash
# Dart unit/widget tests
flutter test

# Firestore + Storage security-rules tests (needs the Firebase emulators)
cd firestore-tests && npm ci && npm test
```

## Cloud Functions

```bash
cd functions && npm ci
firebase deploy --only functions        # deploy
firebase emulators:start --only functions   # local
```

Functions: `registerGuide`, `claimCampCode`, `deleteMyAccount`,
`cleanupExpiredCamps` (scheduled), and FCM fan-out on new announcements,
emergency alerts, and points changes.

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

**Remember:** rules and functions are usually changed together in a deploy — roll back both
together, not just one, to avoid a version mismatch between the client and backend.
