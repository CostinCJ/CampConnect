# Operations

How to deploy, watch and recover CampConnect's backend, plus the manual steps that can't live in
code. Project IDs: `camp-connect-4644c` (alias `default`, production) and `campconnect-dev`
(alias `dev`).

## Deploying

Always name the project. `firebase use` persists between sessions and has deployed to the wrong
project before.

```bash
cd functions
npm run deploy:prod        # functions -> camp-connect-4644c (lint runs first as a predeploy hook)
npm run deploy:dev         # functions -> campconnect-dev
firebase deploy --only firestore:rules,storage -P default
```

`npm run deploy` with no suffix refuses to run. Before a production deploy, run `npm test` (all
function suites) and `cd ../firestore-tests && npm test` (rules). CI runs both on every push.

Rolling back: see README "Incident: rolling back a bad deploy" (every command there also uses
`-P default`).

## Monitoring and alerting

Set these up once per project in Google Cloud Console → Monitoring (or with `gcloud`):

1. **Emergency push failures** (most important). Log-based alert on:

   ```
   resource.type="cloud_run_revision"
   textPayload:"EMERGENCY_PUSH_FAILED" OR jsonPayload.message:"EMERGENCY_PUSH_FAILED"
   ```

   Notify by email/SMS immediately. `onEmergencyAlertCreated` logs this marker on every failed
   send (the event is retried for up to 10 minutes) and once more when it gives up.
2. **Scheduled cleanup failures.** Log-based alert on `severity>=ERROR` for the
   `cleanupexpiredcamps` service. If this stops running, camp data (including children's photos)
   outlives the 60-day retention promise.
3. **Function error rate.** Alert on any Cloud Run service's 5xx rate for the callables.
4. **Budget.** Billing → Budgets & alerts: a monthly budget on the Blaze account with alerts at
   50/90/100%.

## Data protection

- **Backups:** enable Firestore point-in-time recovery and a daily scheduled backup:

  ```bash
  gcloud firestore databases update --database="(default)" --enable-pitr --project=camp-connect-4644c
  gcloud firestore backups schedules create --database="(default)" --recurrence=daily \
    --retention=7d --project=camp-connect-4644c
  ```

  Test a restore into a scratch database once before launch. Backup retention (7 days) must stay
  short relative to the 60-day camp retention in the privacy policy.
- **Rate-limit TTL (backstop):** the daily cleanup already purges `rateLimits`; also add a TTL
  policy so they expire even if the job fails. TTL needs a timestamp field, so this is only
  possible once `windowStart` is stored as a Timestamp (it is a millisecond number today); until
  then, alert 2 above covers it.
- **App Check (off until launch):** see "Launch switches" below.

## Launch switches

App Check is wired in but **disabled** so unsigned sideload/debug builds keep working. To turn it
on for launch:

1. Register the apps in Firebase Console → App Check (Play Integrity for Android, App Attest for
   iOS) and add debug tokens for any test devices.
2. Build the app with `--dart-define=APP_CHECK=true` (add it to `dart_defines.local.json` and the
   Codemagic TestFlight build step).
3. Set `ENFORCE_APP_CHECK=true` in `functions/.env` and deploy functions (`npm run deploy:prod`).
4. Watch the App Check metrics for a few days, then enforce for Firestore and Storage in the
   console.

Turn it off again in reverse order if a feature breaks.

**Separate dev app build (OPS-8):** the app currently always targets `default`, which is fine while
nothing is launched. Before launch, give the app a way to target `campconnect-dev` (a build flavor
or a `FIREBASE_ENV` dart-define choosing between `firebase_options.dart` and
`firebase_options_dev.dart`) so manual testing stops writing to production.

## One-off clean-up after the 2026-09-30 cascade fixes

Older camp deletions left children's group photos in Storage and deleted the profiles of guides
who had that camp selected. After deploying the fixed functions:

```bash
cd scripts
node sweep_orphans.js camp-connect-4644c            # dry run: lists what it would change
node sweep_orphans.js camp-connect-4644c --apply    # deletes orphans, restores guide profiles
```

It deletes Storage files whose camp or organisation no longer exists, restores `users/{uid}` for
guides whose Auth claims and org membership still exist, and lists any other Auth users without a
profile for manual review. Needs `scripts/service-account.json` (gitignored) or application
default credentials.

## Pre-launch manual checklist

Items that live in consoles or contracts rather than code (from the 2026-09-30 production-readiness
review):

- [ ] **Push:** the Apple App ID has Push Notifications enabled, and an APNs auth key is uploaded
      to Firebase Cloud Messaging for `camp-connect-4644c`. Then verify on a TestFlight build that
      `getAPNSToken()` is non-null and an emergency alert reaches a locked iPhone. (If Codemagic
      signing fails with "profile doesn't include aps-environment", the App ID capability is the
      missing piece, not the entitlements file.)
- [ ] **Codemagic secrets:** `campconnect_secrets` has the production `FIREBASE_OPTIONS_DART_B64`,
      a restricted `MAPTILER_KEY`, and optionally `FIREBASE_TOKEN` for Dart symbol upload.
- [ ] **Org creation:** `config/registration.orgCreationCode` exists (long, random) in every
      project you create organisations in.
- [ ] **App Check:** decide and apply per "Launch switches" above.
- [ ] **Old functions:** no leftover `us-central1` functions (`firebase functions:list -P default`).
- [ ] **Budget, alerts, backups:** as above; restore tested.
- [ ] **One-off clean-up:** `sweep_orphans.js` run (dry run first) after deploying the fixes.
- [ ] **Privacy policy:** the live page has no `[DATE]` / `[CONTACT EMAIL]` placeholders, and the
      organiser terms page is published next to it.
- [ ] **Google processing locations:** confirm where Auth, FCM and Crashlytics process data and
      update `docs/data-processors.md` if needed.
- [ ] **Agreements:** a lawyer has reviewed `docs/organiser-terms.md`; the Google Cloud DPA and
      MapTiler terms are accepted; a DPIA screening is done for minors' images.
- [ ] **Store:** decide distribution countries (Play Families plus non-EU distribution brings
      COPPA in).
- [ ] **Firebase API keys:** app restrictions set in the GCP console.
- [ ] **Devices and accessibility:** 360dp width in HU and RO, 200% system font size on the kid
      home and guide session list, a colour-blind simulation of the quiz and passport, and a
      TalkBack/VoiceOver pass on the celebration overlay and quiz.
- [ ] **Check-in policy:** passport check-in is honour-based (no proximity check). Confirm that is
      intended.
