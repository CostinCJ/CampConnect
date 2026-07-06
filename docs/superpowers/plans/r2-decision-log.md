# R2 Decision Log

## Account enumeration via `registerGuide` error codes

`registerGuide` returns a distinct `already-exists`/`email-already-in-use` error, which lets a
caller confirm whether an email address already has a guide account. This is Firebase Auth's own
default `createUser` behavior, not something CampConnect added.

**Decision:** Accepted risk, no code change. Rationale: this app's user base is camp staff, not a
high-value enumeration target (e.g. not a dating app or financial service); the confirmed
information ("this email has an account somewhere") doesn't reveal which organisation, and doesn't
by itself enable any further attack given App Check + rate limiting (R2 Tasks 3-4) now gate the
account-creation endpoint itself. Revisit if this app's threat model changes.
