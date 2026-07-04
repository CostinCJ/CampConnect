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

The MapTiler key is passed at build time, never committed:

```
--dart-define=MAPTILER_KEY=<your-key>
```

## Running

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=MAPTILER_KEY=<your-key>
```

To run against local Firebase emulators, start them (`firebase emulators:start`)
and launch with `--dart-define=USE_EMULATORS=true`.

## Building for release

```bash
# Android (requires android/key.properties + keystore)
flutter build appbundle --release --dart-define=MAPTILER_KEY=<your-key>

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
