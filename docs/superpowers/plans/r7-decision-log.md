# R7 Decision Log

## Accessibility semantics — scope of this phase

The verify-team design review found a systemic absence of `Semantics`/accessibility labels across
`lib/features/{emergency,leaderboard,map,journal,auth,announcements}` and `lib/shared/widgets`.
This phase closes the map markers (R7 Task 2) and the two color-only team indicators named
explicitly in the review (this task). A full pass over every icon-only `IconButton` and custom-
drawn widget in the app is real, proportionate follow-up work — **not done in this phase** — and
should be scheduled as its own dedicated task before or shortly after the first store submission,
scoped screen-by-screen rather than attempted all at once.

## Spinner-only loading states vs. skeleton screens

The design review noted the app uses `CircularProgressIndicator` everywhere rather than skeleton
screens. **Decision:** no change. At this app's actual scale (small camps, fast Firestore reads),
skeleton screens would be disproportionate effort for a marginal perceived-speed gain, and the
current approach is at least applied consistently everywhere. Revisit only if a specific screen's
load time becomes a real user complaint.

## Journal Hive box encryption — accepted residual risks (Task 8)

Encrypting the on-device journal box (`journal_local_storage.dart`) required a one-time migration
for guides with a pre-existing plaintext box. Two residual risks were identified during review and
are accepted rather than engineered away, since neither the original task nor the app's actual
usage pattern (a single guide's own device, small in-memory journal volumes) justifies the added
complexity:

- **Crash/kill mid-migration can lose data.** The migration reads the legacy box into memory,
  deletes the legacy file from disk, then writes the entries into a new encrypted box. If the
  process is killed (OS low-memory kill, force-stop, battery pull) between the delete and the
  encrypted write finishing, the legacy file is gone and the new file may be partial or empty. This
  window is sub-second for realistic journal sizes and only affects guides with a legacy box on
  their very first post-upgrade launch. Not mitigated with write-to-temp-then-rename or
  deferred-delete, since the original task didn't call for crash-atomicity and the added complexity
  isn't proportionate to the narrow, one-time exposure.
- **The `main.dart` Crashlytics filter for the expected internal Hive error leak** (see
  `PlatformDispatcher.instance.onError`) is scoped to `JournalLocalStorage.migratingLegacyJournalBox`
  rather than to the error message alone, specifically so a genuinely corrupted box (this one after
  migration, or any other box opened with `crashRecovery: false` in the future) still reports as
  fatal rather than being silently swallowed by a message-string match. The expected migration leak
  itself is reported non-fatal (not dropped), so Crashlytics still shows whether migrations are
  completing across the field.
