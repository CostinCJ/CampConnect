# Verify-Team Remediation Roadmap (Master Plan)

> **Purpose:** Index + sequencing document for fixing every finding from the 2026-07-05 `/verify-team`
> six-specialist production-readiness review (product design, QA, DevOps/SRE, security, GDPR
> compliance, technical writing). This is a second wave, run **after** the original 8-phase
> `00-campconnect-production-roadmap.md` reached code-complete. Each **Phase** below (`R1`-`R8`) is
> its own standalone plan file that produces working, testable software on its own — implement in
> the order given where a dependency is noted, otherwise phases are independent and can interleave.

**Overall goal:** Close every CRITICAL/HIGH/MEDIUM/LOW finding from the verify-team report so the
app is genuinely ready for its first real store submission and first real camp's data.

**Source of truth for every finding below:** the six specialist reports produced in the
2026-07-05 `/verify-team` session (product designer, QA engineer, DevOps/SRE+DBA, security
engineer, compliance officer, technical writer). File:line references in each `R*` plan were taken
directly from those reports.

---

## Phase sequencing

```
R1  Credential & Secret Hygiene ───────┐  (do first — cheapest, closes a live admin-credential
                                        │   exposure; some steps need your explicit go-ahead)
R2  Auth Abuse Hardening ──────────────┤  (independent of R1; closes the most severe path to
                                        │   real children's data — do second)
R3  Cloud Functions Test Coverage ──────┤  (depends on R2 — tests should cover the hardened
                                        │   behavior, not the pre-fix behavior)
R4  Flutter Test Coverage ─────────────┘  (independent of R1-R3; can run in parallel)
                │
                ▼
R5  DevOps / Infra (CI, dev project, backups, monitoring) ─── (depends on R2+R3 landing so CI
                │                                                has something real to run)
                ▼
R6  Privacy & Compliance ──────────────┐  (independent of R1-R5; touch app UI + docs only)
R7  Design & Accessibility ────────────┤  (independent of everything else)
R8  Documentation ──────────────────────┘  (last — documents the end state of R1-R7, so writing
                                             it first would just mean rewriting it)
```

**Rule of thumb:** R1 and R2 are the two genuinely urgent ones (live exploitable paths to a real
org's / real children's data). R3-R4 make sure R2's fixes (and everything else security/data-
integrity-critical) can't silently regress. R5-R8 are important but not "an attacker could act on
this today."

## Cross-cutting conventions (same as the original roadmap)

- **Branching:** one branch per phase, e.g. `remediation/r1-credential-hygiene`. Never commit to
  `main` directly. Do NOT commit or push unless the user explicitly asks (project rule).
- **Commits:** small and frequent, `type: what changed` (feat/fix/refactor/test/docs/chore).
- **After every code change:** run `flutter analyze` and the relevant test suite before committing.
- **UI language:** all user-facing strings go through `AppLocalizations`/ARB files — never hard-code
  Romanian/Hungarian/English literals in widgets.
- **Destructive/external actions require your explicit sign-off at the time**, not just because
  this plan exists: rotating cloud credentials, git history rewrites, `firebase deploy`, GCP
  Console changes (billing alerts, App Check enrollment, Firestore region), and Play
  Console/App Store Connect actions all pause for confirmation in the phase files below.

---

## Phase R1 — Credential & Secret Hygiene
**Plan file:** `2026-07-05-r1-credential-hygiene.md`
**Findings closed:** DevOps-CRITICAL (service-account key in git stash), DevOps-HIGH (client API
keys in public git history).
**Why first:** Cheapest fix on the whole list, and closes a live full-admin credential exposure
regardless of how low-probability exploitation is.

## Phase R2 — Auth Abuse Hardening
**Plan file:** `2026-07-05-r2-auth-abuse-hardening.md`
**Findings closed:** Security-CRITICAL (weak org invite-code PRNG/entropy), Security-HIGH (no rate
limiting/App Check on any callable), Security-HIGH (storage rules lack content-type/size
validation), Security-LOW (guide password minimum), Security-LOW (account enumeration — documented
as accepted risk, no code change).
**Why second:** This is the most severe *currently exploitable* path to a real organisation's data
(children's names, teams, photos) found in the whole review.

## Phase R3 — Cloud Functions Test Coverage
**Plan file:** `2026-07-05-r3-functions-test-coverage.md`
**Findings closed:** QA-CRITICAL (`functions/index.js` zero test coverage), QA-CRITICAL
(`claimCampCode` atomicity unverified), QA-HIGH (session/camp cascade deletion untested for
server-side `recursiveDelete` paths).
**Depends on:** R2 (tests should assert the hardened invite-code/rate-limit behavior, not the
pre-fix behavior).

## Phase R4 — Flutter Test Coverage
**Plan file:** `2026-07-05-r4-flutter-test-coverage.md`
**Findings closed:** QA-HIGH (bulk code generation unbounded), QA-HIGH (camp-end lockout untested,
non-injectable clock), QA-HIGH (kid team-topic FCM subscription untested), QA-MEDIUM
(emergency-overlay duplicate-dialog guard untested), QA-MEDIUM (journal Hive corrupted-entry +
`clearAll` untested), QA-MEDIUM (points clamping boundaries untested).

## Phase R5 — DevOps / Infra
**Plan file:** `2026-07-05-r5-devops-infra.md`
**Findings closed:** DevOps-CRITICAL (no dev/staging Firebase project), DevOps-CRITICAL (no CI
pipeline), DevOps-HIGH (no Cloud Functions timeout/retry config), DevOps-HIGH (scheduled cleanup
failures silent, no alerting), DevOps-MEDIUM (no `firestore.indexes.json`), DevOps-MEDIUM (no
rollback procedure documented), DevOps-MEDIUM (no Firestore PITR/backups), DevOps-MEDIUM (no
billing alerts), DevOps-MEDIUM (no storage lifecycle policy — orphaned children's photos after
camp cleanup; this is also a Compliance-HIGH cross-reference), DevOps-LOW (unpinned caret ranges —
already mitigated by lockfile, documented only), DevOps-LOW (unstructured logging).
**Depends on:** R2+R3 landing (so the new CI has real tests to run).

## Phase R6 — Privacy & Compliance
**Plan file:** `2026-07-05-r6-privacy-compliance.md`
**Findings closed:** Compliance-CRITICAL (privacy policy unpublishable + unreachable from the app),
Compliance-CRITICAL (no consent/notice at point of collection), Compliance-HIGH (legal basis for
children's data weak/miscategorized), Compliance-HIGH (FCM notification transparency to guides),
Compliance-MEDIUM (cross-border transfer undocumented), Compliance-MEDIUM (no Article 28 processor
documentation), Compliance-MEDIUM (Crashlytics retention/erasure undocumented), Compliance-LOW
(children's photos not distinctly called out), Compliance-LOW (no breach response plan),
Compliance-LOW (no supervisory authority mention), TechWriter-MEDIUM (privacy policy placeholders —
same root cause as the Compliance-CRITICAL item above, one fix closes both), TechWriter-MEDIUM
(`review-notes.md` placeholder demo credentials).

## Phase R7 — Design & Accessibility
**Plan file:** `2026-07-05-r7-design-accessibility.md`
**Findings closed:** Design-HIGH (hardcoded `Colors.red` in emergency screens), Design-HIGH (map
marker touch targets/feedback), Design-HIGH (systemic absence of accessibility semantics),
Design-MEDIUM (kid nav label visibility contradicts DESIGN.md), Design-MEDIUM (guide nav density vs.
RO/HU text expansion), Design-MEDIUM (journal photo-remove control undersized/unconfirmed),
Design-LOW (teams-management dialog no loading guard), Design-LOW (second hardcoded red in
`camp_session_screen.dart`), Design-LOW (spinner-only loading states — documented as accepted, no
action), Security-LOW (Hive journal unencrypted at rest — bundled here since it touches the same
journal feature as this phase's Task 5).

## Phase R8 — Documentation
**Plan file:** `2026-07-05-r8-documentation.md`
**Findings closed:** TechWriter-HIGH (Cloud Functions `HttpsError` contract undocumented — **and**
the live `weak-password`/`auth-create-failed` silent-fallthrough bug this caused),
TechWriter-HIGH (FCM topic schema undocumented), TechWriter-HIGH (no Firestore/Storage schema doc),
TechWriter-MEDIUM (no `CHANGELOG.md`), TechWriter-MEDIUM (no architecture overview document),
TechWriter-LOW (dev/prod Firebase topology decision undocumented — same root cause as the
DevOps-CRITICAL item in R5; R5 fixes the infra, R8 just adds the one-line note if R5's answer is
"accept the risk" instead), TechWriter-LOW (`firestore-tests/` no README), TechWriter-LOW
(architectural decisions only in dated planning docs, no discoverable index).

---

## Full finding checklist (all ~56 findings — check off as each phase completes)

### Security
- [x] Org invite-code weak PRNG + entropy (`R2.1`)
- [x] No rate limiting/App Check on any callable (`R2.2`, `R2.3`)
- [x] Storage rules lack content-type/size validation (`R2.4`)
- [x] Guide password minimum too low (`R2.5`)
- [x] Account enumeration via `registerGuide` (`R2.6` — accepted risk, documented)
- [x] Hive journal unencrypted at rest (`R7.8` — bundled into the design phase since it touches
  the same journal feature as `R7.6`; box now opened with `HiveAesCipher`, key in
  `flutter_secure_storage`, safe migration off a legacy plaintext box. Code review independently
  reproduced a real data-destruction bug in the plan's own literal migration approach — Hive's
  default `crashRecovery: true` silently truncates a plaintext box to 0 bytes on cipher mismatch
  instead of throwing — caught and fixed with `crashRecovery: false` before it shipped. A
  resulting benign Crashlytics error leak was scoped to the migration window and reported
  non-fatal rather than swallowed; residual risks (narrow crash-mid-migration data-loss window,
  message-string matching) accepted and documented in `r7-decision-log.md`)

### DevOps / SRE / DBA
- [x] Service-account key in git stash (`R1.1`, `R1.2`)
- [x] Client API keys in public git history (`R1.3` — decision + optional rewrite)
- [x] No dev/staging Firebase project (`R5.1`)
- [x] No CI pipeline (`R5.2`)
- [x] No Cloud Functions timeout/retry config (`R5.3`)
- [ ] Scheduled cleanup failures silent (`R5.4` — **outstanding, manual**: needs GCP Console
  access to create the log-based alerting policy; no CLI/browser access available to this agent)
- [x] No `firestore.indexes.json` (`R5.5`)
- [x] No rollback procedure documented (`R5.6`)
- [ ] No Firestore PITR/backups (`R5.7` — **outstanding, manual**: needs GCP Console access)
- [ ] No billing alerts (`R5.8` — **outstanding, manual**: needs GCP Console access)
- [x] No storage lifecycle policy / orphaned children's photos (`R5.9` — fixed at the
  application level: `cleanupExpiredCamps`/`deleteMyAccount` now delete Storage photos
  alongside Firestore docs; a bucket-level TTL lifecycle rule was not additionally configured
  since app-level deletion now closes the retention gap)
- [x] Unpinned caret ranges (`R5.10` — documented, `npm ci` already mitigates)
- [x] Unstructured logging (`R5.11`)

### QA
- [x] `functions/index.js` zero test coverage (`R3.1`-`R3.4`)
- [x] `claimCampCode` atomicity unverified (`R3.2`)
- [x] Session/camp cascade deletion untested (`R3.3`, `R3.4`)
- [x] Bulk code generation unbounded (`R4.1`)
- [x] Camp-end lockout untested / non-injectable clock (`R4.2`)
- [x] Kid team-topic FCM subscription untested (`R4.3`)
- [x] Emergency-overlay duplicate-dialog guard untested (`R4.4`)
- [x] Journal Hive corrupted-entry + `clearAll` untested (`R4.5`)
- [x] Points clamping boundaries untested (`R4.6`)

### Compliance
- [x] Privacy policy unpublishable + unreachable from app (`R6.1`, `R6.2` — content complete
  and reachable from settings + both onboarding forms; publish-date/contact-email placeholders
  and GitHub Pages hosting are intentionally left for the user at actual publish time)
- [x] No consent/notice at point of collection (`R6.2`)
- [x] Legal basis for children's data weak (`R6.3`)
- [x] FCM notification transparency to guides (`R6.4`)
- [x] Cross-border transfer undocumented (`R6.5`)
- [x] No Article 28 processor documentation (`R6.6`)
- [x] Crashlytics retention/erasure undocumented (`R6.7`)
- [x] Children's photos not distinctly called out (`R6.8`)
- [x] No breach response plan (`R6.9`)
- [x] No supervisory authority mention (`R6.10`)
- [ ] `review-notes.md` placeholder credentials (`R6.11` — **intentionally deferred**: cannot
  be completed until a real guide/camp/join-code exists against production, at store-submission
  time, per the plan's own design)

### Product Design
- [x] Hardcoded `Colors.red` in emergency screens (`R7.1` — replaced with
  `colorScheme.error`/`errorContainer` tokens; light-mode contrast defect found on the
  full-screen emergency overlay during review, fixed by switching that dialog to `error`/`onError`)
- [x] Map marker touch targets/feedback (`R7.2` — extracted `MapMarker` widget, 48dp target,
  tap feedback, semantic label)
- [x] Systemic absence of accessibility semantics (`R7.3` — the two color-only team indicators
  named explicitly in the review are labeled; a full pass over every icon-only control app-wide
  is real follow-up work, not attempted in this phase — see `r7-decision-log.md`)
- [x] Kid nav label visibility contradicts DESIGN.md (`R7.4` — `alwaysShow` label behavior)
- [x] Guide nav density vs. text expansion (`R7.4`, same task — "Codes" destination removed,
  7→6 items)
- [x] Journal photo-remove control undersized/unconfirmed (`R7.5` — 48dp control + Undo path
  before deleting; a `dispose()`-after-unmount crash and a Timer/SnackBar duration race were
  found and fixed during review, with explicit regression tests)
- [x] Teams-management dialog no loading guard (`R7.6` — submit-disable guard + `mounted` checks
  on both success and error paths, with a dismiss-during-async-save regression test)
- [x] Second hardcoded red in `camp_session_screen.dart` (`R7.1`, same task)
- [x] Spinner-only loading states (`R7.7` — documented as accepted, no action; see
  `r7-decision-log.md`)

### Technical Writer
- [ ] `HttpsError` contract undocumented + live `weak-password` bug (`R8.1`)
- [ ] FCM topic schema undocumented (`R8.2`)
- [ ] No Firestore/Storage schema doc (`R8.3`)
- [ ] No `CHANGELOG.md` (`R8.4`)
- [ ] No architecture overview document (`R8.5`)
- [ ] Dev/prod Firebase topology undocumented (`R8.6`, ties to `R5.1`)
- [ ] `firestore-tests/` no README (`R8.7`)
- [ ] Architectural decisions only in dated planning docs (`R8.8`)
