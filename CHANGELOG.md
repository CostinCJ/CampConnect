# Changelog

All notable user-visible changes to CampConnect are recorded here, starting from the first store
submission. Earlier history (the 8-phase production build-out) is documented in
`docs/superpowers/plans/` rather than backfilled here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Explorer Passport** for kids: check in at camp map locations to collect stamps (device-only),
  shown on kid home and included in the journal PDF export. Stamped locations get a "visited"
  badge on the map.
- **Location quizzes**: guides author quiz questions in a location's knowledge base; kids play
  them with device-local best scores. Right/wrong answers show an icon and are announced to screen
  readers, not just colour-coded.
- **Question of the day**: guides post a prompt announcement; kids answer it inline and the answer
  lands in their journal. Drafts survive closing the sheet.
- **Team celebrations** for kids when their team gains points (after the guide's undo window, and
  never over another screen), plus a "today for your team" points digest.
- **Public TV leaderboard** page (GitHub Pages) with a per-camp code; team totals only.
- **Emergency alert types** (preset chips + icons) and an optional precise sender location with
  open-in-maps.
- Opt-in "my location" dot for kids on the camp map (device-only).
- Organisation logo upload with cropping; shown on kids' journal PDF export.
- Announcement templates shared across an organisation's camps.
- Day-0 checklist for new organisation owners; first-run onboarding card for kids.
- Points entry: undoable award snackbar, amount chips and reason presets.
- Kids can erase their journal and passport from a shared phone when signing out.
- Organisation creation requires a setup code and the owner's confirmation of the organiser terms
  (the organisation is the GDPR controller); the confirmation is stored with the organisation.
- Rate limiting on all sensitive Cloud Functions callables.
- Firebase App Check support, **currently switched off** (`functions/.env` `ENFORCE_APP_CHECK`
  plus the `APP_CHECK` dart-define) until unsigned test builds are retired; turn both on before
  launch.
- A dev Firebase project, separate from production.
- CI pipeline running Flutter, Cloud Functions, and Firestore-rules tests on every push.
- Firestore/Storage schema and architecture documentation.
- In-app links to the privacy policy from Settings and both onboarding forms.

### Changed
- Org invite codes now generated with a cryptographically secure RNG at higher entropy.
- Guide password minimum raised from 6 to 8 characters.
- Kids are asked to confirm before logging out (their anonymous session can't be resumed without a
  new code).
- Kid navigation trimmed to five destinations; settings moved to the home header.
- The map centres on GPS or the camp's markers instead of fixed coordinates.
- A new guide in an organisation with a running session has it selected automatically.
- Tied teams now share a rank everywhere (leaderboard and kid home).
- A new points award replaces the previous award's snackbar, so its Undo is always the visible one.
- Kid home no longer shows team points and rank twice, and no longer flashes "No teams yet" while
  loading.
- Text scales up to 200% with the system font size (was capped at 130%).
- Emergency alerts are sent immediately; the optional GPS position is attached afterwards.

### Fixed
- Deleting a map location now also removes its photo from Storage: the Storage rules were
  silently denying every client-side delete (and the app swallowed the error), orphaning photos.
- Hardcoded emergency-red colors now use the theme's `colorScheme.error` token.
- Map markers meet the 48dp touch-target minimum and show tap feedback.
- `cleanupExpiredCamps` now also deletes the corresponding Storage photos, not just Firestore docs.
- A guide entering a weak password now sees a specific error instead of a generic one.
- Deleting a camp now removes its access codes and Storage photos too. The old client-side delete
  only cleared a long-empty legacy subcollection, orphaning the real codes and every photo forever.
- Switching or deleting the active camp now re-points notification subscriptions, so guides no
  longer keep receiving a former camp's alerts (or miss the new camp's).
- Session switch/delete now surface an error instead of failing silently.
- Point-history entries record the change that was actually applied after clamping, fixing the
  spurious rank-change notifications a clamped-away deduction used to trigger.
- Journal PDF export renders month names in the user's language instead of English.
- The notification-permission prompt now appears in-context after sign-in, not at cold start.
- Session group photos (org-scoped path) and organisation logos are now deleted with their camp /
  organisation. Previously they were orphaned in Storage.
- Deleting or expiring a camp no longer deletes the profiles of guides who had it selected (which
  locked them out of their accounts).
- iOS push notifications restored for TestFlight/App Store builds (the push entitlement is only
  stripped from unsigned sideload builds); topic-subscription failures are no longer reported as
  fatal crashes.
- An emergency alert is no longer lost if the sheet is dismissed while waiting for GPS.
- Emergency push delivery is retried on failure and logged for alerting.
- Alert confirmation counts can no longer exceed the number of guides.
- The Codemagic TestFlight workflow restores `firebase_options.dart` and increments the build
  number.
- Team-coloured text uses a readable shade (yellow/lime/orange were below contrast minimums).
- Deleting a team also moves or deletes its unclaimed codes.
- Removing a guide from an organisation revokes their sessions immediately and can be retried.
- A failed legacy journal migration keeps the entries it couldn't copy instead of deleting them.
- "Remove logo" asks for confirmation and confirms success.
- The kid location switch explains how to turn it on instead of sitting disabled.

### Removed
- Unused dependencies (`sqflite`, `path`, `permission_handler`) and unused Riverpod codegen/lint
  tooling, plus assorted dead code.

### Security
- Storage rules now enforce content-type and size limits on photo uploads.
- Camp deletion moved to a server-side callable; Firestore rules now deny direct client camp
  deletes (which would orphan subcollections, codes, and photos).
- `claimCampCode` now rejects codes whose camp is missing or whose org doesn't match the camp's,
  and is rate-limited per-IP in addition to per-user.
- `codes` documents are no longer client-updatable, and a code's `campId` must belong to the
  guide's own org at creation time.
- An org owner can no longer delete their account while other guides remain in the org (which
  would have destroyed those guides' camps and data).
- Personal data (sender name) removed from the emergency push payload; the client reads it from
  the rules-protected alert document instead.
- Expired rate-limit records are now purged by the daily cleanup job.
- Session group photos are readable only by kids of the same camp (not the whole organisation),
  and are served with `Cache-Control: private`.
- Rate limits key on the client IP that Google's front end records (not a spoofable
  `X-Forwarded-For` value), stored only as a hash.
- Emergency alerts can no longer be edited after sending, except a guide acknowledging it or the
  sender attaching their location.
- An organisation's logo URL must point at its own Storage logo; the app refuses to download logos
  from other hosts or over 5 MB.
- `deleteTeam` rejects org-less callers and path-like ids.
- The public TV leaderboard only allows the GitHub Pages origin and caps its instances.
- Deploys name their Firebase project explicitly and lint Cloud Functions first.
