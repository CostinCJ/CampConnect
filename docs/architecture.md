# Architecture

## System overview

Flutter app (Android/iOS) <-> Firebase (Auth, Firestore, Storage, Cloud Messaging) <-> Cloud
Functions (Node 20, `functions/`). There is no custom backend server — Cloud Functions plus
Firestore/Storage security rules are the entire server-side surface. See `docs/firestore-schema.md`
for the full data model (collections, fields, who writes what).

- **Flutter**: feature-first layout under `lib/features/*` (`data` / `domain` / `presentation`),
  Riverpod 2 for state, `go_router` for routing.
- **Cloud Functions** (`functions/index.js` + `functions/lib/*.js`): a small number of callables
  (`registerGuide`, `claimCampCode`, `deleteMyAccount`, all with `enforceAppCheck: true`), one
  scheduled function (`cleanupExpiredCamps`), and three Firestore-triggered functions
  (`onAnnouncementCreated`, `onEmergencyAlertCreated`, `onPointsChanged`) that fan out FCM pushes.
- Two Firebase projects exist (dev/prod) — see "Firebase project topology" below.

## Critical flow 1: Guide registration

1. Guide fills in email/password/displayName and either an existing org's invite code or a new org
   name, in `guide_login_screen.dart`, and submits.
2. The client (`AuthRepository.registerGuide`, in `lib/features/auth/data/auth_repository.dart`)
   calls the `registerGuide` callable (App Check-enforced, rate-limited by caller IP since the
   caller isn't authenticated yet — see R2). See `functions/lib/registerGuide.js`'s doc comment for
   the full `HttpsError` contract.
3. Server-side only, in this order: resolves the org first (validates the invite code for
   "join", or reserves a new `organizations/{orgId}` doc + a fresh invite code for "create") —
   failing before any Auth user is created — then creates the Firebase Auth user, writes the
   `users/{uid}` profile and the `organizations/{orgId}/members/{uid}` doc (owner or guide role) in
   one batch, and finally sets custom claims `{ role: 'guide', orgId }`. The client never writes a
   role or org membership directly.
4. **Correction vs. the plan's draft:** the client does not merely "sign in after" as a separate,
   later step described in the abstract — concretely, `AuthRepository.registerGuide` calls
   `_auth.signInWithEmailAndPassword` itself immediately after the callable returns, using the same
   credentials the guide just typed in, and then loads the `users/{uid}` profile. Because custom
   claims are set before the callable returns, this first sign-in's ID token already carries
   `role`/`orgId`.

## Critical flow 2: Kid code claim

1. Kid enters a `CAMP-XXXX` code in `kid_login_screen.dart` and submits.
2. The client (`AuthRepository.signInWithCode`) signs in anonymously first (`_auth.signInAnonymously()`)
   so the callable below has an auth context, then calls the `claimCampCode` callable (App
   Check-enforced, rate-limited by uid). See `functions/lib/claimCampCode.js`'s doc comment for the
   full `HttpsError` contract.
3. Server-side, inside a single Firestore transaction: gets `codes/{code}` (a top-level collection,
   one document get — not a scan), checks it exists, is unused, and that its camp hasn't already
   ended, then marks the code used and writes the kid's `users/{uid}` profile
   (`role`/`displayName`/`campId`/`orgId`/`team`). Returns `{ campId, team, displayName }`.
4. **Verified as stated in the plan:** on any `FirebaseFunctionsException` from the callable, the
   client's `catch` block best-effort deletes the anonymous Auth user it just created
   (`_auth.currentUser?.delete()`) and signs out, specifically so a failed claim doesn't leave an
   orphaned anonymous account. This cleanup is itself wrapped in its own `try/catch` — a cleanup
   failure is swallowed so it doesn't mask the original claim error shown to the kid.

## Critical flow 3: Emergency alert fan-out

1. A guide writes a new `camps/{campId}/emergencyAlerts/{id}` document from `emergency_screen.dart`
   (`firestore.rules` restricts this write to guides of that camp's org). The composer UI shows a
   confirmation dialog and, inline in the message field, a confidentiality warning
   (`emergencyMessageConfidentialityWarning` — "avoid including a child's full name or sensitive
   medical details ... treat this message as visible outside the app").
2. The Firestore trigger `onEmergencyAlertCreated` (`functions/index.js`) fires and sends a
   high-priority FCM push — notification title is the localized "ALERTĂ DE URGENȚĂ"/emergency
   string, body is the alert's raw `message` text — to the `camp_{campId}_guides` topic (confirmed
   by reading `functions/index.js:148`; matches the plan's guess exactly).
3. **Known tradeoff, still true:** FCM topic subscriptions (`fcm_service.dart`'s
   `subscribeToTopic`/`unsubscribeFromTopic` calls) are plain client-SDK calls with no Cloud
   Function or App Check gate in front of them, and no Firebase product offers a security-rules-like
   authorization layer for topic subscription — so topic names are effectively public strings, not
   an access-control boundary. This is disclosed in `docs/privacy-policy.md`'s "Push notifications"
   section ("Notification content for a given camp/team is visible to anyone who could technically
   subscribe to that camp/team's notification topic; do not treat notification bodies as
   confidential... This applies to emergency alerts too"), and the in-app alert composer repeats the
   reminder as described in step 1.

## FCM topic schema

Verified against `grep -n "camp_" functions/index.js lib/shared/services/fcm_service.dart`.
**Correction vs. the plan's draft:** the plan's table only listed three topic patterns and omitted
a fourth topic the client actually subscribes every user to; the exact format (snake_case, single
underscores, no other separators) matched the plan's guess for the three it did list.

| Topic pattern | Subscribers | Published by |
|---|---|---|
| `camp_{campId}_all` | every signed-in member of a camp (guide or kid, subscribed unconditionally in `subscribeToTopics`) | **Nothing currently publishes to this topic** — no `camp_*_all` string appears anywhere in `functions/index.js`. The subscription exists client-side but is presently unused/dead on the publish side. |
| `camp_{campId}_kids` | kids in a camp | `onAnnouncementCreated` (skipped for `type: 'schedule'` entries) |
| `camp_{campId}_guides` | guides subscribed via that camp (client subscribes by role, not by org — see note below) | `onEmergencyAlertCreated` |
| `camp_{campId}_team_{teamId}` | kids on a specific team (`teamId` is the raw team id/`team` field, not a display name) | `onPointsChanged` — one message to the changed team, plus additional messages to any other team whose leaderboard rank shifted as a result |

Notes:
- `onAnnouncementCreated` and `onPointsChanged` are the two triggers listed in the plan's
  `camp_{campId}_guides` row — that was incorrect; neither of those triggers publishes to the
  `_guides` topic in the current code. Only `onEmergencyAlertCreated` does.
- The client subscribes to `_guides`/`_kids` based on the signed-in user's `role`, scoped to the
  `campId` the guide/kid is currently viewing — there is no separate org-wide guide topic; a guide
  managing multiple camps only receives alerts for the camp they're subscribed to.

## Firebase project topology

See `README.md`'s "Firebase project topology" section (under "Configuration") for the authoritative,
up-to-date description. Summary: two Firebase projects exist — `camp-connect-4644c` (production,
CLI alias `default`) and `campconnect-dev` (development, CLI alias `dev`). Day-to-day development
should target `dev`; deploys to `default` are deliberate and require explicit go-ahead. The
`firebase use` CLI target and which `firebase_options*.dart` file `main.dart` imports are two
independently-forgettable settings with no automated check that they match — see the README's
"Footgun to watch for" callout before deploying.
