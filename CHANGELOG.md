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

### Security
- Storage rules now enforce content-type and size limits on photo uploads.
