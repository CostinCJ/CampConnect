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

### Changed
- Kids are asked to confirm before logging out (their anonymous session can't be resumed without a
  new code).

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
