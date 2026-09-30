# Production Readiness — CampConnect — 2026-09-30

**Verdict:** 🔴 **BLOCKED** · Scope: diff `477eb74..HEAD` (PR #12 remediation → main; 122 commits, ~14k lines excl. generated) · Specialists: ux, qa, ops, sec, gdpr, docs (none skipped)
**Counts (verified):** C:3 H:10 M:24 L:16 · Rejected as false positive: 0 · vs previous: first `/verify-team` report, so everything is NEW

The orchestrator opened and confirmed every CRITICAL and HIGH at its cited location. Spot-checked MEDIUMs (UX-7, UX-9, QA-4, OPS-3, OPS-8) all held. No reviewer was noisy.

## Blockers (CRITICAL)

| ID | Title | Location | Fix | Effort |
|----|-------|----------|-----|--------|
| **V-1** (SEC-1 = GDPR-1 = OPS-2 = QA-2 = DOC-1) | Children's group photos are never deleted. Uploads moved to `organizations/{orgId}/sessionPhotos/{campId}/…`, but camp delete, the 60-day cleanup and owner account deletion only delete `camps/{campId}/` and `organizations/{orgId}/locations/`. `logo.jpg` is orphaned too. Tests seed only the legacy path. This contradicts the privacy policy, the LIA and the store copy. | `add_session_location_screen.dart:108`, `functions/lib/deleteCampCascade.js:24`, `functions/lib/deleteMyAccount.js:72` | In the cascade, read the camp's `orgId`, then `deleteFiles({prefix: organizations/${orgId}/sessionPhotos/${campId}/})`. In the owner cascade, delete the whole `organizations/${orgId}/` prefix. Add tests on the new path. Run a one-off prod sweep for orphans. | S |
| **V-2** (GDPR-2 = QA-1) | Camp delete or expiry deletes the profiles of guides who had that camp selected. The cascade deletes every `users` doc where `campId == X` with no role filter, and guides store their active camp there. The guide can no longer sign in (`user-not-found` is shown as "wrong credentials"), and `deleteMyAccount` then skips the org cascade. The scheduled cleanup makes this near-certain. | `functions/lib/deleteCampCascade.js:33-36`; guides write `campId` at `auth_repository.dart:136`, `session_auto_select.dart:26-28` | Delete only `role == "kid"`. For guides, `update({campId: FieldValue.delete()})` instead. Chunk batches to ≤500. Add a guide case to the deleteCamp and cleanup tests. Let `deleteMyAccount` fall back to token claims. Audit prod for Auth users with no profile. | S |
| **V-3** (OPS-1, part of DOC-4) | iOS push is disabled. Commit `24589d3` ("fix codemagic issue") removed `aps-environment`, and the entitlements file is now empty and shared by the TestFlight build. The iOS guide topic (`camp_<id>_guides`), which emergency alerts go to, gets no subscribers. Separately, the unawaited `subscribeToTopics` in splash is recorded as a **fatal** Crashlytics error on every guide launch. | `ios/Runner/Runner.entitlements`; `splash_screen.dart:44,54`; `main.dart:81` | Restore `aps-environment` for the signed build. Strip it only in the sideload workflow (separate entitlements file or a script step). Wrap the splash subscribe in try/catch. Verify on TestFlight that `getAPNSToken()` is non-null and that an alert reaches a locked iPhone. | S |

## Fix Before Release (HIGH)

| ID | Title | Location | Fix | Effort |
|----|-------|----------|-----|--------|
| **V-4** (QA-3) | An emergency alert is silently never sent if the guide swipes the sheet away during the GPS wait (up to 8s). `ref.read` after the await throws, the `catch` swallows it, and nothing is sent. | `emergency_screen.dart:71-75, 416-479` | Capture `campId`/`user`/`repo` before the GPS await. Block dismissal while `_isLoading`. Better: send first, patch the coordinates in afterwards. | S |
| **V-5** (OPS-4 = QA-7, part of DOC-4) | The Codemagic `ios-testflight` workflow can't compile because it never restores `lib/firebase_options.dart`. It also has no `--build-number`, so the second upload would be a duplicate `1.0.0 (1)`. | `codemagic.yaml:57-93` | Copy the restore step. Pass an incrementing build number. Pin the Flutter and Xcode versions. | S |
| **V-6** (SEC-2, part of DOC-5) | App Check was removed from the client and from every callable (commit `c3acf77`), but CHANGELOG and architecture.md still advertise it. Kid-code brute force is now bounded only by per-uid/IP limits, and the IP limit is spoofable (SEC-3). | `functions/index.js:344-432`, `lib/main.dart`, `pubspec.yaml`, `CHANGELOG.md:12` | Restore App Check, gated per build flavour if sideload needs it off. If it stays off by choice, fix the docs and consider 6-char code suffixes. | S |
| **V-7** (OPS-3 = DOC-7) | Deploy and rollback commands have no `-P`. The README tells devs to `firebase use dev`, and `npm run deploy` currently ships to prod with no gate. A rollback during an incident could hit the wrong project. | `README.md:77,134,155`, `functions/package.json:8` | Use an explicit `-P default` / `-P dev` everywhere, `deploy:prod`/`deploy:dev` scripts, and predeploy lint/test hooks. | S |
| **V-8** (GDPR-3) | Journal (text and photos) and passport are keyed per device and survive sign-out. On a shared camp device (PRODUCT.md:5), the next kid sees and can export the previous kid's diary. The privacy policy says "per-account". | `providers.dart:46-52, 321, 402`; `main.dart:107-112`; `auth_repository.dart` signOut | Either key by uid with an explicit "restore my journal" flow, or offer an "erase on sign-out" choice for shared devices. Update the policy. | M |
| **V-9** (DOC-3, part of GDPR-6) | Emergency alerts store precise GPS (`LocationAccuracy.high`) in Firestore. Play Data Safety and the Apple label declare only approximate location, and the privacy policy says it is "not stored". | `emergency_screen.dart:426-429`, `docs/store/data-safety.md:16`, `docs/store/app-privacy.md:14`, `docs/privacy-policy.md:51-54` | Declare precise location (guides, optional). Update the policy and the schema doc. | S |
| **V-10** (GDPR-4) | The privacy policy now says "all data and processing stays within the EU" and dropped the DPF/SCC wording. Auth, FCM and Crashlytics are not region-pinned, and GitHub Pages (policy + TV page) is US-hosted and not listed as a processor. | `docs/privacy-policy.md:99-106`, `docs/data-processors.md` | Restore the transfers paragraph and add GitHub Pages. Confirm per-product locations (manual). | S |
| **V-11** (GDPR-5) | The controller/processor role is unresolved now that third-party orgs onboard. The LIA's organiser attestation is still "not implemented". The kid screen's "By continuing you agree…" frames the processing as consent, which contradicts the legitimate-interest basis. | `docs/kid-data-legitimate-interest-assessment.md:64-79`, `registerGuide.js:43-63`, `kid_login_screen.dart:206` | Decide org = controller / app = processor. Write organiser terms. Add an attestation checkbox and store `attestedAt`. Reword the kid screen. | M |
| **V-12** (DOC-2) | `config/registration.orgCreationCode` now gates all org creation (fails closed), but the schema doc calls `config/` "dead" and nothing documents provisioning. A fresh project, or one where `config/` was "cleaned up", can't create orgs. Store review notes describe open org creation. | `docs/firestore-schema.md:25`, `functions/lib/registerGuide.js:56-61`, `docs/store/review-notes.md` | Document the doc, the provisioning step and the error. Fix the review notes. | S |
| **V-13** (UX-1) | The "today for your team" points pill draws its text in the raw team colour on a 16% tint of itself: yellow 1.32:1, lime 1.64:1, orange 2.07:1. It skips `TeamColors.emphasis()`. | `kid_home_screen.dart:499-502` | Use `emphasis()`, and add a design-guard check for `foreground: teamColor`. | S |

## Fix Order

1. **Fix `deleteCampCascade` + `deleteMyAccount`**: role filter, the org-scoped photo and logo prefixes, tests, and a prod orphan sweep plus a guide-profile audit. This closes **V-1, V-2** (both CRITICAL) in one small PR.
2. **Restore iOS push and fix the TestFlight workflow**: closes **V-3, V-5** and the iOS half of DOC-4. It unblocks store submission and the safety path.
3. **Harden the emergency path**: the sheet race, plus `retry: true` and an alert on the FCM trigger. Closes **V-4, OPS-7**.
4. **Make explicit `-P` deploys and predeploy gates**: closes **V-7, OPS-6** (cheap, and prevents prod accidents).
5. **Make the App Check decision** and fix the IP derivation: closes **V-6, SEC-3**, and the related doc lines.
6. **Do the privacy and store doc pass**: covers **V-9, V-10, V-11, V-12, GDPR-6, GDPR-7/DOC-6, DOC-5**. It should come after 1–5 so the docs describe the fixed behaviour.
7. **Fix the shared-device journal**: **V-8** (a product decision, then M effort).
8. **Clear the UX batch**: **V-13**, then UX-2/3/4/5/9.

## Medium / Low

**Access control and security**
- M SEC-4: `sessionPhotos` read rule ignores `{campId}`, so any kid in the org can read another camp's children's photos. Fix: add `userData().campId == campId`. `storage.rules:69-71`
- M SEC-3: rate limits key on `req.ip`, which likely trusts client-supplied X-Forwarded-For. The raw value is also used as the Firestore doc id. `functions/index.js:346,358`, `tvLeaderboard.js:46`
- M SEC-5 = QA-5: `removeMember` doesn't revoke refresh tokens (about 1h of residual access), deletes membership before the claims step, and can't be retried. `orgManagement.js:60-81`
- L SEC-6: owner-set `logoUrl` accepts any URL, and every kid device fetches it unbounded. `firestore.rules:74-76`, `logo_cache_service.dart:47-67`
- L SEC-7: children's photos are uploaded with `Cache-Control: public, max-age=31536000`. `image_upload_service.dart:31-34`
- L SEC-8: `emergencyAlerts` update is unconstrained, so a guide can rewrite `senderId` after create. `firestore.rules:117-120`
- L SEC-9: the `deleteTeam` guard passes when both orgIds are undefined, and path segments aren't validated. `teamManagement.js:18-32`

**Data integrity and tests**
- M QA-4: `deleteTeam` leaves unclaimed codes pointing at the deleted team. `teamManagement.js:241-277`
- M QA-6: the new rules paths (org owner update, `announcementTemplates`, `logo.jpg`, `sessionPhotos`) have no tests. `firestore-tests/`
- M QA-8: 29 lib files are never loaded by any test, including `points_management_screen`, `emergency_screen`, `camp_session_screen` and `session_auto_select`. Measured coverage is 54.0% of loaded files.
- L QA-9: the map GPS stream can start after dispose and has no `onError`. `map_screen.dart:61-77`
- L QA-11: the functions `npm test` chain is flaky because of emulator port reuse between suites. `functions/package.json`
- L QA-12: the alert ack count can exceed the total ("5 of 4"). `emergency_alert.dart:80-86`
- L QA-13: journal legacy migration deletes the old box even if some entries failed. `journal_local_storage.dart:148-156`

**Release and ops**
- M OPS-5: the Android release silently falls back to debug signing. `android/app/build.gradle.kts:63-72`
- M OPS-6 = SEC-10: functions have no lint and no predeploy gate. `npm audit`: 1 high (fast-xml-parser, low reachability), 12 moderate.
- M OPS-7: the emergency push trigger swallows errors with no retry and no alert. `functions/index.js` `onEmergencyAlertCreated`
- M OPS-8: the app can't target the dev project, so all manual testing writes to prod. `lib/main.dart:18,32`
- M OPS-9: Crashlytics native auto-collection isn't disabled in the manifest or plist, so kids' first-launch crashes can upload.
- M OPS-10: no iOS dSYM upload and no obfuscation/symbol pipeline.
- L OPS-11: public `tvLeaderboard` has no `maxInstances`, and its CORS is `*`.
- L OPS-12: unused `FOREGROUND_SERVICE` permission, and no app-level `PrivacyInfo.xcprivacy`.

**Privacy docs**
- M GDPR-6: the LIA, policy and store forms weren't re-assessed for the passport (a self-reported location history), quiz answers, kid opt-in GPS, the per-install UUID and IP rate-limit keys. The store forms over-declare guide live location.
- M GDPR-7 = DOC-6: `firestore-schema.md` has drifted from the rules and functions (org fields, camp delete, `rateLimits`, the Storage table, the `prompt` type).

**Docs**
- M DOC-5: the CHANGELOG is missing all 122 commits' features, still claims App Check, and has two `### Changed` sections.
- L DOC-8: `getOrganizationLogoUrl.test.js` is never run by `npm test`.
- L DOC-9: the README feature list is stale, and the setup-code and org errors have no next step.

**UX**
- M UX-2: kid home flashes "No teams yet" on a grey-olive card on every cold open, and stays that way permanently if the stream errors. `kid_home_screen.dart:46-52`
- M UX-3: award snackbars queue at 6s each, so the current award's Undo is buried. `points_management_screen.dart:110-118`
- M UX-4 (+ QA-10): the celebration fires before the undo window closes, interrupts the journal or quiz, and rank-ups trigger when another team *loses* points. `team_celebration_listener.dart`, `celebration.dart:21-37`
- M UX-5: the quiz marks right and wrong answers by colour alone, with no icon or live region. `quiz_runner_sheet.dart:180-216`
- M UX-6: the guide session card squeezes the camp name to about 0dp at 360dp in RO. `camp_session_screen.dart:750-808`
- M UX-7: app-wide text scale is capped at 130%. `app.dart:106-118`
- M UX-8: the question-of-the-day answer sheet ignores the keyboard inset, and dragging it down drops the typed answer. `announcements_screen.dart:216-227`
- M UX-9: "Remove logo" deletes the org logo from Storage with no confirmation or feedback. `organization_screen.dart:355-378`
- M UX-10: the kid location switch is disabled when off, with no explanation of how to enable it. `kid_settings_screen.dart`
- L UX-11: no "visited" marker on the map for stamped locations.
- L UX-12: team points and rank are shown twice on kid home, and ties show different ranks.
- L UX-13: the passport is named inconsistently within RO and HU.
- L UX-14: legacy "grey/gri/szürke" teams still turn grey, and the enabled my-location FAB has no tooltip.

## Pre-release Manual Checklist

- [ ] **Push:** the Apple App ID has Push enabled, and the APNs auth key is uploaded to FCM (prod). Verify after the V-3 fix.
- [ ] **Codemagic secrets:** the `campconnect_secrets` group has prod `FIREBASE_OPTIONS_DART_B64` and a restricted `MAPTILER_KEY`.
- [ ] **Org creation:** `config/registration.orgCreationCode` exists in prod (long, random) and in dev if needed.
- [ ] **App Check:** console enforcement state for Firestore and Storage matches the V-6 decision.
- [ ] **Old functions:** no leftover us-central1 functions (`firebase functions:list -P default`).
- [ ] **Rate limits:** a TTL policy on `rateLimits`, and a budget alert on the Blaze account.
- [ ] **Backups:** Firestore PITR and scheduled backups are on, and a restore has been tested.
- [ ] **Alerting:** alerts on function errors, especially emergency FCM fan-out and `cleanupExpiredCamps`.
- [ ] **Clean-up after V-1 and V-2:** sweep orphaned `organizations/*/sessionPhotos/*`, and list Auth users with no `users/{uid}` doc.
- [ ] **Privacy policy:** the live page at `costincj.github.io/CampConnect/privacy-policy` has no `[DATE]` / `[CONTACT EMAIL]` placeholders.
- [ ] **Google locations:** confirm where Auth, FCM and Crashlytics process data (needed for V-10 wording).
- [ ] **Agreements:** organiser terms / DPA, and the Google Cloud DPA and MapTiler terms are accepted. A DPIA screening for minors' images.
- [ ] **Store:** decide distribution countries (Play Families + non-EU distribution brings COPPA in).
- [ ] **Firebase API keys:** app restrictions in the GCP console.
- [ ] **Device and accessibility checks:** 360dp in HU and RO, a colour-blind simulation of the quiz and passport, and a TalkBack pass on the celebration dialog and quiz.
- [ ] **Check-in policy:** location check-in is honour-based (no proximity check). Confirm this is intended.

## Domain Scores

| Domain | Score | Key issue |
|--------|-------|-----------|
| Design/UX | 7/10 | New kid widgets reuse raw team colour as text (V-13) |
| Testing/QA | 5/10 | Guide-profile wipe and emergency send race were not covered by tests |
| DevOps/Release | 4/10 | iOS push is off, the TestFlight build is broken, and deploy commands don't name a project |
| Security | 5/10 | App Check removed; photo retention and camp isolation weakened |
| Compliance | 4/10 | Retention and erasure promises are broken; docs misstate processing |
| Documentation | 5/10 | Privacy and store docs have drifted from the code; CHANGELOG is stale |

## Strengths

- **CI:** runs flutter analyze and test, the functions Jest suites and the rules emulator tests on every push. The last 8 runs on main are green. `flutter analyze` is clean.
- **Server-side authorization:** owner checks read from the DB, and the org update rule is field-scoped with `affectedKeys().hasOnly`. Codes use a secure RNG, and org creation fails closed.
- **Points transactions:** these record the applied delta. Undo and async-gap fixes capture refs before awaits.
- **Well-tested new backend:** orgManagement (14), teamManagement (12) and tvLeaderboard (5) have tests, and the rules suite passes 39/39.
- **Design-token discipline:** holds across a large diff, with guard tests passing, and confetti respects reduced motion.
- **TV page:** no XSS sinks, and it returns only team aggregates. Kid GPS is opt-in and never uploaded.
- **Secrets hygiene:** secrets are correctly gitignored, and release builds emit no debug logs.

## Appendix: Rejected Findings

| ID | Claim | Why rejected |
|----|-------|--------------|
| — | None | Every CRITICAL and HIGH was confirmed at its cited location. Spot-checked MEDIUMs all held. |

## Appendix: Commands Run

| Command | Result |
|---------|--------|
| `flutter analyze` | No issues (UX, OPS, QA) |
| `flutter test --coverage` | 153 pass, 0 fail. 54.0% lines of loaded files; 29 lib files never loaded (QA) |
| `flutter test test/core/design_guards_test.dart` | 4/4 pass (UX) |
| `npm --prefix functions test` (chained) | Flaky: emulator port reuse; parallel reviewers also contended |
| `npm --prefix functions test` (per suite) | 79/79 pass (QA) |
| `firestore-tests: npm test` | 39/39 pass on retry (QA) |
| `npm --prefix functions audit --omit=dev` | 0 critical, 1 high, 12 moderate (SEC, OPS) |
| `npm --prefix functions run lint` | No lint script exists (OPS, SEC) |
| `gh run list -L 8` | 8/8 green (OPS) |
| WCAG contrast calc for the team palette | 6 of 9 light-mode colours below 4.5:1 on their own tint (UX) |
| ARB key parity script | en/ro/hu 500 keys each, no gaps (DOC) |
| Orchestrator verification | Opened: `deleteCampCascade.js`, `deleteMyAccount.js`, `add_session_location_screen.dart`, `storage.rules`, `Runner.entitlements`, `splash_screen.dart`, `main.dart`, `codemagic.yaml`, `functions/index.js` (App Check grep), `orgManagement.js`, `registerGuide.js`, `emergency_screen.dart`, `auth_repository.dart`, `session_auto_select.dart`, `providers.dart`, `kid_home_screen.dart`, `team_colors.dart`, `app.dart`, `organization_screen.dart`, `README.md`, the store docs, `teamManagement.js` |
