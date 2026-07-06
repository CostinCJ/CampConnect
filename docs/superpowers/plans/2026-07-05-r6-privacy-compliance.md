# R6 — Privacy & Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the privacy policy publishable and actually reachable from inside the app, add a
notice at the point of data collection, correct the legal-basis reasoning for children's data, and
close the remaining GDPR documentation/disclosure gaps (cross-border transfer, processor
agreements, Crashlytics retention, breach response, supervisory authority).

**Architecture:** Mostly content changes to `docs/privacy-policy.md` plus a small UI addition
(`url_launcher` + a settings `ListTile` + an inline link on the two data-collection screens) so the
policy is reachable before and at the point personal data is first collected.

**Tech Stack:** `url_launcher` (new dependency), Flutter `gen-l10n` (ARB files), Markdown.

**Branch:** `remediation/r6-privacy-compliance`.

---

### Task 1: Complete and correct the privacy policy

**Files:**
- Modify: `docs/privacy-policy.md`

- [ ] **Step 1: Fill the publication-date and contact-email placeholders**

Replace:
```
**Last updated:** [DATE — fill in before publishing]
```
with the actual date this policy is finalized (fill in at publish time, not before — leave as-is
until Task 6's manual gate is reached). Replace:
```
[CONTACT EMAIL — fill in before publishing]
```
with a real, monitored email address the user will check for both general contact and GDPR
data-subject-access requests.

- [ ] **Step 2: Rewrite the "Legal basis (GDPR)" section**

Replace the existing section:
```
## Legal basis (GDPR)

- Guide account data is processed under **contract** (providing the service you
  signed up for) and **legitimate interest** (running the camp they organise).
- Kid data is processed under the **legitimate interest of the camp
  organiser/guardian** who distributed the join code, minimised to the smallest
  possible footprint (an anonymous session identity, a self-chosen first name,
  and a team assignment) — no data is collected from children beyond what is
  strictly necessary to run the camp activity they are already participating in
  offline.
```
with:
```
## Legal basis (GDPR)

- **Guide account data** is processed under **contract** (providing the service a
  guide signed up for) and, for camp-management content they create, our
  **legitimate interest** in operating the coordination tool they engaged us for.

- **Kid data**: CampConnect is not offered directly to children in the sense
  Article 8 GDPR addresses. A kid never self-registers, never provides contact
  details, and never creates an account with us directly — they join using a
  one-time code that a guide, acting on behalf of the camp organisation and
  within an existing, offline relationship with the child's parent/guardian
  (camp enrolment), distributes to them. Because access is gated by that adult
  organisation rather than offered directly to the child, we do not treat this
  as an Article 8 "information society service offered directly to a child."

  The resulting kid data (an anonymous session identity, a self-chosen first
  name, and a team assignment) is processed under our **legitimate interest** in
  operating the camp-coordination service the organisation engaged us to provide.
  Our balancing test: **purpose** — enabling the camp activity the child is
  already offline-enrolled in; **necessity** — the data collected is the
  minimum needed to run a team-based leaderboard and route notifications, with
  no profiling, no advertising, and no data collected beyond what's listed
  above; **impact on the child** — negligible, since the data never identifies
  the child by real name, is not shared outside their own camp, and is
  automatically deleted (see "Data retention" below). We judge this balance to
  favour the minimal processing described here. A guardian or camp organiser
  who objects to this processing can request deletion at any time (see "Your
  rights" below), which is treated as equivalent to an objection.
```

- [ ] **Step 3: Add a supervisory-authority line to "Your rights"**

Append to the existing "Your rights and how to delete your data" section:
```
- You also have the right to lodge a complaint with your national data
  protection authority — in Romania, ANSPDCP (dataprotection.ro); in Hungary,
  NAIH (naih.hu); or the authority in your own country of residence.
```

- [ ] **Step 4: Add a cross-border transfer paragraph**

Add a new section after "Data retention" and before "Your rights":
```
## Where your data is stored

CampConnect's backend runs on Google Firebase / Google Cloud. Depending on the
Firebase project's configured region, data may be processed outside the
European Economic Area. Where that is the case, Google's standing
certification under the EU-US Data Privacy Framework (and/or Standard
Contractual Clauses, where applicable) is the safeguard relied upon for that
transfer.
```
(If R5's infra work later pins the project to an EU region, update this paragraph to say so
instead — check `functions/index.js` for a `region` option and the Firestore database's configured
location before finalizing this wording.)

- [ ] **Step 5: Add a Crashlytics retention sentence**

In the existing "## Crash reporting" section, append:
```
Crash reports are retained for Firebase Crashlytics' standard retention period
(90 days) and, as noted above, are never linked to a kid's account or device
identity.
```

- [ ] **Step 6: Call out children's photos distinctly under "From kids"**

In the "From kids:" bullet list, add a new bullet:
```
- Guides may photograph camp activities that include your child (e.g. a team
  group photo) and upload it to the app. Unlike your journal, these photos are
  stored on our servers (not local-only) and are subject to the same 60-day
  retention as other camp content described below.
```

- [ ] **Step 7: Add the FCM confidentiality caveat to the existing push-notification section**

The existing "## Push notifications" section already says notification bodies aren't confidential —
append one sentence connecting this to the emergency channel specifically:
```
This applies to emergency alerts too — guides should avoid including a child's
full name or sensitive medical details in an alert message; the in-app alert
composer repeats this reminder.
```
(The composer-side reminder is added in Task 3 below.)

- [ ] **Step 8: Proofread the whole document once, end to end**

Read the full file top to bottom after all the above edits to confirm no section now
contradicts another (e.g. the retention section, the new "where stored" section, and the
Crashlytics section should all read consistently).

- [ ] **Step 9: Commit**

```bash
cd /d/CampConnect
git add docs/privacy-policy.md
git commit -m "docs(compliance): complete privacy policy — legal basis, transfer, retention, rights"
```

---

### Task 2: Link the privacy policy from inside the app

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/l10n/app_ro.arb`, `app_hu.arb`, `app_en.arb`
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart`
- Modify: `lib/features/settings/presentation/kid_settings_screen.dart`
- Modify: `lib/features/auth/presentation/guide_login_screen.dart` (registration form)
- Modify: `lib/features/auth/presentation/kid_login_screen.dart` (code-entry form)

- [ ] **Step 1: Add `url_launcher`**

Run:
```bash
flutter pub add url_launcher
```

- [ ] **Step 2: Add the policy URL constant**

In `lib/core/constants/app_constants.dart`, add:
```dart
  static const String privacyPolicyUrl = 'https://costincj.github.io/CampConnect/privacy-policy';
```
(Adjust to wherever the policy is actually hosted once published — GitHub Pages from this repo's
`docs/` folder is the simplest option given `docs/privacy-policy.md` already lives there; enabling
GitHub Pages for the repo is a one-time Settings change, separate from this code change.)

- [ ] **Step 3: Add the new localization keys**

Add to `lib/l10n/app_en.arb`:
```json
  "privacyPolicy": "Privacy Policy",
  "byContinuingYouAgreeToPrivacyPolicy": "By continuing, you agree to our Privacy Policy",
```
Add to `lib/l10n/app_ro.arb`:
```json
  "privacyPolicy": "Politica de confidențialitate",
  "byContinuingYouAgreeToPrivacyPolicy": "Continuând, ești de acord cu Politica de confidențialitate",
```
Add to `lib/l10n/app_hu.arb`:
```json
  "privacyPolicy": "Adatvédelmi szabályzat",
  "byContinuingYouAgreeToPrivacyPolicy": "A folytatással elfogadod az Adatvédelmi szabályzatot",
```
Run `flutter gen-l10n` to regenerate the localization classes.

- [ ] **Step 4: Add a "Privacy policy" tile to both settings screens**

In `guide_settings_screen.dart` and `kid_settings_screen.dart`, add (near the existing
"Delete account"/"Delete my data" tile, same list):
```dart
ListTile(
  leading: const Icon(Icons.privacy_tip_outlined),
  title: Text(AppLocalizations.of(context).privacyPolicy),
  onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
),
```
Add `import 'package:url_launcher/url_launcher.dart';` to both files.

- [ ] **Step 5: Add an inline link to the guide registration form**

In `guide_login_screen.dart`'s registration form (around the existing form fields, before the
submit button), add:
```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: RichText(
    text: TextSpan(
      style: Theme.of(context).textTheme.bodySmall,
      children: [
        TextSpan(text: '${AppLocalizations.of(context).byContinuingYouAgreeToPrivacyPolicy} '),
        TextSpan(
          text: AppLocalizations.of(context).privacyPolicy,
          style: const TextStyle(decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
        ),
      ],
    ),
  ),
),
```
Add `import 'package:flutter/gestures.dart';` and the `url_launcher` import to this file.

- [ ] **Step 6: Add the same inline link to the kid code-entry screen**

Apply the identical pattern from Step 5 to `kid_login_screen.dart`, placed below the code-entry
field and above the submit button.

- [ ] **Step 7: Run analyze and the widget test suite**

Run:
```bash
flutter analyze && flutter test
```

- [ ] **Step 8: Commit**

```bash
cd /d/CampConnect
git add pubspec.yaml pubspec.lock lib/core/constants/app_constants.dart lib/l10n/*.arb lib/features/settings/presentation/guide_settings_screen.dart lib/features/settings/presentation/kid_settings_screen.dart lib/features/auth/presentation/guide_login_screen.dart lib/features/auth/presentation/kid_login_screen.dart
git commit -m "feat(compliance): link the privacy policy from settings and both onboarding forms"
```

---

### Task 3: FCM confidentiality caveat in the emergency-alert composer

**Files:**
- Modify: `lib/features/emergency/presentation/emergency_screen.dart`
- Modify: `lib/l10n/app_ro.arb`, `app_hu.arb`, `app_en.arb`

- [ ] **Step 1: Add the localization key**

Add to `lib/l10n/app_en.arb`:
```json
  "emergencyMessageConfidentialityWarning": "Avoid including a child's full name or sensitive medical details — treat this message as visible outside the app.",
```
Add to `lib/l10n/app_ro.arb`:
```json
  "emergencyMessageConfidentialityWarning": "Evită să incluzi numele complet al unui copil sau detalii medicale sensibile — tratează acest mesaj ca fiind vizibil și în afara aplicației.",
```
Add to `lib/l10n/app_hu.arb`:
```json
  "emergencyMessageConfidentialityWarning": "Kerüld a gyermek teljes nevének vagy érzékeny egészségügyi adatainak megadását — kezeld ezt az üzenetet úgy, mintha az alkalmazáson kívül is látható lenne.",
```
(Romanian and Hungarian text above are complete, usable translations — have a native Hungarian
speaker spot-check the Hungarian wording before shipping if one is available, same as any
translated string, but do not block this task on that review.)
Run `flutter gen-l10n`.

- [ ] **Step 2: Add the warning text to the composer UI**

In `emergency_screen.dart`, near the message input field (around the existing hint-text field
noted in the review, currently ~lines 222-230), add directly below it:
```dart
Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 8),
  child: Text(
    AppLocalizations.of(context).emergencyMessageConfidentialityWarning,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
  ),
),
```

- [ ] **Step 3: Run analyze**

Run:
```bash
flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
cd /d/CampConnect
git add lib/features/emergency/presentation/emergency_screen.dart lib/l10n/*.arb
git commit -m "feat(compliance): warn guides that emergency alert bodies aren't confidential"
```

---

### Task 4: Write a breach response plan

**Files:**
- Create: `docs/breach-response-plan.md`

- [ ] **Step 1: Write the plan**

Create `docs/breach-response-plan.md`:
```markdown
# Breach Response Plan

Proportionate to a solo-developer project — this is a workable one-page plan, not an
incident-response program.

## Detection

Rely on: the R5 Cloud Functions error-rate alert (unusual spikes may indicate abuse), Firebase
Authentication's built-in anomaly signals, and periodic manual review of Firestore/Auth access
patterns in the Firebase Console.

## If a breach affecting EU users' personal data is suspected

1. **Contain**: rotate any exposed credentials immediately (see
   `docs/superpowers/plans/2026-07-05-r1-credential-hygiene.md` for the exact rotation procedure);
   if a Firestore/Storage rules gap is the cause, deploy the fix immediately (see the rollback/
   deploy procedure in `README.md`).
2. **Assess**: within 72 hours, determine whether the breach poses a risk to individuals (exposed
   guide emails, exposed kid team/camp assignments, exposed photos).
3. **Notify the supervisory authority** within 72 hours of becoming aware, if there is a risk to
   individuals: Romania's ANSPDCP (dataprotection.ro) or Hungary's NAIH (naih.hu), depending on
   which country's camps are affected — notify both if unclear.
4. **Notify affected individuals** without undue delay if the risk is high (e.g. children's photos
   or contact-adjacent data exposed).
5. **Log it**: record what happened, who was affected, and what was done — even if never
   externally reported — in a dated entry appended to this file.

## Breach log

(Empty — append a dated entry here if this plan is ever invoked.)
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add docs/breach-response-plan.md
git commit -m "docs(compliance): add a proportionate breach response plan"
```

---

### Task 5: Document processor/DPA coverage

**Files:**
- Create: `docs/data-processors.md`

- [ ] **Step 1: Write the note**

Create `docs/data-processors.md`:
```markdown
# Data Processors

Internal reference (not necessarily public-facing) confirming Article 28 GDPR coverage for every
third party that processes personal data on CampConnect's behalf.

| Processor | Role | DPA / terms relied on |
|---|---|---|
| Google Cloud / Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Crashlytics) | Hosts all backend data | Google Cloud's standard Cloud Data Processing Addendum, auto-accepted via the Firebase/GCP Terms of Service |
| MapTiler | Serves map tiles; may see requesting IP addresses | MapTiler's standard Terms of Service / Privacy Policy (see maptiler.com) |
| Codemagic | CI/CD — builds and signs the iOS app | Does not process end-user personal data; not a GDPR processor for this app's user data |

Revisit this table any time a new third-party SDK or service is added.
```

- [ ] **Step 2: Commit**

```bash
cd /d/CampConnect
git add docs/data-processors.md
git commit -m "docs(compliance): document Article 28 processor coverage"
```

---

### Task 6: Fill the store review-notes demo credentials — blocked until a real camp exists

**Files:**
- Modify: `docs/store/review-notes.md`

This task cannot be completed until Task 2 has shipped (the privacy-policy link needs to be live
for a reviewer to see it) and a real guide account + camp + join code exist against the production
project — it is the last step before store submission, not something to do mid-remediation.

- [ ] **Step 1: Once a production camp exists, replace the three placeholders**

In `docs/store/review-notes.md`, replace the three `[FILL IN]` markers with real, working demo
credentials (a real guide login, a real camp name, and a real unclaimed `CAMP-XXXX` join code).

- [ ] **Step 2: Note the code-refresh risk**

Add one sentence to the same file: "If Apple/Google's review cycle re-tests after this join code
has already been claimed, generate and provide a fresh unclaimed code before the re-test."

- [ ] **Step 3: Remove the file's own DRAFT/placeholder warning header** once real credentials are
in place.

- [ ] **Step 4: Commit** (at submission time, not now)

```bash
cd /d/CampConnect
git add docs/store/review-notes.md
git commit -m "docs: fill in real demo credentials for app store review"
```

---

## Post-phase verification

- [ ] `docs/privacy-policy.md` has no remaining `[FILL IN]`/bracketed placeholders except Task 6's
  intentionally-deferred review-notes credentials.
- [ ] The privacy policy is reachable from both settings screens and both onboarding forms —
  confirmed by tapping through the running app, not just by reading the diff.
- [ ] `flutter analyze` and `flutter test` both pass.
- [ ] Update the master remediation checklist (`00-verify-team-remediation-roadmap.md`).
