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
