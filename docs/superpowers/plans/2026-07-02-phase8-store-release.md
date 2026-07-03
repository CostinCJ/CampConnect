# Phase 8 — Store Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get CampConnect approved and live on Google Play and the App Store — add the crash monitoring, account/data-deletion flows, privacy disclosures, and age/audience declarations both stores require in 2026, then complete the listings and the mandatory Google Play closed test.

**Architecture:** Two code deliverables (Crashlytics wiring; in-app account + kid-data deletion) plus a large body of store-console + legal work (privacy policy, Data Safety form, privacy nutrition labels, age-rating questionnaires, mixed-audience declaration, listings, closed test). The app is declared **mixed audience** (organisers + children), not "Made for Kids", to keep FCM + Crashlytics usable while still meeting child-protection rules.

**Tech Stack:** Firebase Crashlytics, Firebase Auth (account deletion), Cloud Functions (kid-data deletion), Google Play Console, App Store Connect, a hosted privacy policy.

**Branch:** `phase8-store-release`.

**Prerequisites:** Phases 1–7 merged (secured, multi-org, bilingual, iOS-capable app). Apple Developer account and a Google Play Developer account ($25 one-time). Deploys/submissions here are outward-facing — get explicit user authorization for each.

---

### Task 1: Branch + Crashlytics

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `android/app/build.gradle` + `android/build.gradle` (Crashlytics Gradle plugin)

- [ ] **Step 1: Branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase8-store-release
```

- [ ] **Step 2: Add Crashlytics packages**

In `pubspec.yaml`:
```yaml
  firebase_crashlytics: ^4.1.3
```
Run:
```bash
flutter pub get
```

- [ ] **Step 3: Add the Gradle plugin (Kotlin DSL)**

This project uses Gradle Kotlin DSL (`android/app/build.gradle.kts`, `android/settings.gradle.kts`).
First locate where the `com.google.gms.google-services` plugin is declared:
```bash
grep -rn "google-services\|google.gms" android/settings.gradle.kts android/app/build.gradle.kts android/build.gradle.kts
```
Mirror that exact pattern for Crashlytics:
- In `android/settings.gradle.kts`, inside the `plugins { ... }` block, next to the google-services line:
  ```kotlin
  id("com.google.firebase.crashlytics") version "3.0.2" apply false
  ```
- In `android/app/build.gradle.kts`, inside its `plugins { ... }` block:
  ```kotlin
  id("com.google.firebase.crashlytics")
  ```
Then verify Gradle still configures:
```bash
cd android && ./gradlew help -q && cd ..
```
Expected: no configuration errors. (If the google-services plugin is wired via the legacy
`buildscript { dependencies { classpath(...) } }` style instead, add
`classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")` there and
`apply(plugin = "com.google.firebase.crashlytics")` in the app module — match whichever style the
project actually uses.)

- [ ] **Step 4: Wire Crashlytics in `main.dart`, privacy-safe for kids**

In `main.dart`, after `Firebase.initializeApp`, route Flutter + platform errors to Crashlytics but **disable collection for anonymous (kid) users** to honor the mixed-audience/child-data stance:
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// ...
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
```
Then, where auth state is known (e.g. in a listener), call:
```dart
// Enable crash reporting only for signed-in guides (email accounts), not kids.
await FirebaseCrashlytics.instance
    .setCrashlyticsCollectionEnabled(user != null && user.isGuide);
```
Never call `setUserIdentifier` with a kid uid. Document this in the commit.

- [ ] **Step 5: Analyze + build**

Run:
```bash
flutter analyze lib/main.dart && flutter build apk --debug
```
Expected: clean; builds.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart android
git commit -m "feat: add Crashlytics with collection disabled for anonymous kid users"
```

---

### Task 2: In-app account deletion (guides) + kid-data deletion path

**Files:**
- Modify: `functions/index.js` (callable `deleteMyAccount`)
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart`
- Modify: `lib/features/settings/presentation/kid_settings_screen.dart`

**Why:** Apple requires in-app account deletion for any app with account creation. 2026 consent-revocation laws require a path to delete a child's data.

- [ ] **Step 1: Callable to delete a guide account + their org data**

In `functions/index.js`:
```javascript
exports.deleteMyAccount = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const db = getFirestore();

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;

  if (user && user.role === "guide" && user.orgId) {
    // If the guide is the org owner, delete the whole org and its camps.
    const org = await db.doc(`organizations/${user.orgId}`).get();
    if (org.exists && org.data().ownerUid === uid) {
      const camps = await db.collection("camps")
        .where("orgId", "==", user.orgId).get();
      for (const camp of camps.docs) {
        await db.recursiveDelete(camp.ref);
      }
      await db.recursiveDelete(org.ref);
    } else {
      // Non-owner guide: just remove membership.
      await db.doc(`organizations/${user.orgId}/members/${uid}`).delete().catch(() => {});
    }
  }

  await db.doc(`users/${uid}`).delete().catch(() => {});
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
```

- [ ] **Step 2: Repository method**

In `auth_repository.dart`:
```dart
  Future<void> deleteMyAccount() async {
    final callable = _functions.httpsCallable('deleteMyAccount');
    await callable.call();
    await _auth.signOut();
  }
```

- [ ] **Step 3: Guide "Delete account" UI**

In `guide_settings_screen.dart`, below logout, add a destructive `TextButton` that shows a confirm dialog (typing/warning) explaining it removes the account and, if they own the org, all its camps. On confirm, call `deleteMyAccount()` and navigate to `/role-selection`.
```dart
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: const Icon(Icons.delete_forever),
            label: Text(l10n.deleteAccount),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteAccount),
                  content: Text(l10n.deleteAccountWarning),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel)),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.delete)),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                await ref.read(authRepositoryProvider).deleteMyAccount();
                if (context.mounted) context.go('/role-selection');
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.somethingWentWrong)),
                  );
                }
              }
            },
          ),
```

- [ ] **Step 4: Kid "Delete my data" UI**

In `kid_settings_screen.dart`, add a similar destructive button `l10n.deleteMyData` that calls `deleteMyAccount()` (deletes the anonymous user + their `users/{uid}` doc) and also clears the local journal + kid name. Because kids are anonymous, this is their consent-revocation path. Wire it to also call `ref.read(journalProvider.notifier)` cleanup and remove `kid_name_$uid` from prefs.

- [ ] **Step 5: Add strings (`deleteAccount`, `deleteAccountWarning`, `deleteMyData`) to all locales**

RO/HU/EN, e.g. EN: `'deleteAccount': 'Delete account', 'deleteAccountWarning': 'This permanently deletes your account. If you own the organisation, all its camps are also deleted.', 'deleteMyData': 'Delete my data',` with RO/HU equivalents (diacritics).

- [ ] **Step 6: Analyze**

Run:
```bash
flutter analyze lib/features/auth lib/features/settings
```
Expected: no issues.

- [ ] **Step 7: Commit**

```bash
cd /d/CampConnect
git add functions/index.js lib
git commit -m "feat: in-app account deletion for guides and kid-data deletion path"
```

---

### Task 3: Privacy policy + legal copy

**Files:**
- Create: `docs/privacy-policy.md` (source; host it publicly)

- [ ] **Step 1: Write the privacy policy**

Create `docs/privacy-policy.md` covering, honestly reflecting the app's GDPR-first design: what's collected (guide email; kids anonymous with only a locally-stored first name + team; camp content; optional photos; approximate location for the map), what's NOT (no third-party ads/analytics; no device identifiers for kids), retention (camps auto-deleted 60 days after end; journal is local-only), the deletion mechanisms (Task 2), the legal bases (GDPR), and contact info. Keep it truthful — the architecture makes this easy.

- [ ] **Step 2: Host it**

Publish the policy at a stable public URL (GitHub Pages, Firebase Hosting, or a simple static host). Record the URL — both stores require it in the listing and the app should link to it from settings.

- [ ] **Step 3: Link the policy in-app**

Add a "Privacy policy" `ListTile` in both settings screens opening the URL (via `url_launcher` — add the dependency if not present). Add the `privacyPolicy` string to all locales.

- [ ] **Step 4: Commit**

```bash
git add docs/privacy-policy.md pubspec.yaml pubspec.lock lib
git commit -m "docs: add privacy policy and in-app link"
```

---

### Task 4: Age ratings, audience declaration, and data disclosures (console work)

**Files:** none in-repo (store consoles) — record answers in `docs/store/` for reproducibility.

- [ ] **Step 1: Complete the 2026 age-rating questionnaires (both stores)**

Both stores require the new age-rating questionnaire (Apple's deadline was Jan 31 2026; Google Play's updated form). Answer truthfully: no violence, no ads, user-generated content is present (announcements/journal/photos) and gated behind guide accounts — declare UGC accordingly. Save the answers under `docs/store/age-rating.md`.

- [ ] **Step 2: Declare mixed audience (not "Made for Kids")**

- **Google Play Families:** in the Play Console "App content → Target audience and content", select target age groups **including under-13 AND 13+/adults** (mixed audience). This keeps you in Families policy scope (no ads/identifiers for kids — already true) without the stricter "Primarily child-directed" bucket that would break FCM/Crashlytics.
- **Apple:** in App Store Connect, do **not** check "Made for Kids". Set the age rating from the questionnaire. Because children use it, keep the kids-data restrictions (no third-party analytics/ads — already true).
Record the rationale in `docs/store/audience.md`.

- [ ] **Step 3: Google Play Data Safety form**

Fill the Data Safety form: data collected = email (guides), photos, approximate location, app content; purpose = app functionality; encrypted in transit; users can request deletion (link the Task-2 flow); no data sold; no third-party sharing. Save under `docs/store/data-safety.md`.

- [ ] **Step 4: Apple privacy nutrition labels**

In App Store Connect App Privacy, declare the same: email (linked to identity, app functionality), photos, coarse location, user content; no tracking; no third-party analytics/ads. Save under `docs/store/app-privacy.md`.

- [ ] **Step 5: Commit the documentation**

```bash
git add docs/store
git commit -m "docs: record store age-rating, audience, and data-disclosure answers"
```

---

### Task 5: Store listings + assets

**Files:**
- Create: `docs/store/listing.md` (copy for both stores)

- [ ] **Step 1: Write listing copy (RO + EN at minimum)**

App name, short + full description emphasising: camp organisers manage sessions, teams, points, schedule, announcements, emergency alerts, offline map, and a private camper journal; bilingual RO/HU; privacy-first (kids anonymous). Save to `docs/store/listing.md`.

- [ ] **Step 2: Produce screenshots**

Capture required screenshot sets: Android phone + iOS 6.7" (and any other required sizes) of role selection, guide dashboard, leaderboard, schedule, map pin detail, journal. Use a real device or emulator; store under `docs/store/screenshots/`.

- [ ] **Step 3: Prepare review notes**

Write reviewer notes explaining the **invite-code onboarding** (adult organiser distributes codes to campers; kids never create accounts or enter personal data beyond a local first name) and provide **demo credentials** (a test guide account + a test camp code) so reviewers can get in. Save to `docs/store/review-notes.md`.

- [ ] **Step 4: Commit**

```bash
git add docs/store
git commit -m "docs: store listing copy, screenshots, and reviewer notes"
```

---

### Task 6: Google Play closed test (14 days, 12+ testers)

**Files:** none (console + operational)

- [ ] **Step 1: Build the release App Bundle**

Run (with the MapTiler key + prod Firebase):
```bash
flutter build appbundle --release --dart-define=MAPTILER_KEY=<key>
```
Expected: `build/app/outputs/bundle/release/app-release.aab`. Ensure release signing is configured (`android/key.properties` + a keystore — create one if absent; keep it out of git).

- [ ] **Step 2: Create the closed test track**

In Play Console, create a **Closed testing** track, upload the AAB, and recruit **12+ testers** who must stay opted in for **14 continuous days** (required for personal developer accounts before production access). Your first real camp cohort of organisers/staff is an ideal tester group.

- [ ] **Step 3: Run the test period**

Over 14 days, collect crash reports (Crashlytics) and feedback; fix blockers; upload new builds to the same track as needed.

- [ ] **Step 4: Record completion**

Note the test window dates + outcomes in `docs/store/closed-test.md` and commit.

```bash
git add docs/store/closed-test.md
git commit -m "docs: record Google Play closed-test window and outcomes"
```

---

### Task 7: Production submission (both stores)

**Files:** none (console) — all outward-facing; require explicit user authorization for each submission.

- [ ] **Step 1: Deploy backend to prod (authorized)**

With the user's explicit go-ahead, and after the Phase-5 prod data migration has run:
```bash
firebase use prod
firebase deploy --only firestore:rules,storage,functions
```

- [ ] **Step 2: Google Play production release**

Promote the tested build from the closed track to Production. Complete the store listing, content rating, data safety, and target-audience sections (all prepared above). Submit for review.

- [ ] **Step 3: Apple App Store submission**

From the TestFlight build (Phase 7), submit for App Store review with the privacy labels, age rating, and reviewer notes/demo credentials. Ensure the account-deletion path (Task 2) is present — Apple checks for it.

- [ ] **Step 4: Post-submission monitoring**

Watch Crashlytics + store review status. Respond to any reviewer questions (the invite-code onboarding is the most likely question — the review notes pre-empt it).

- [ ] **Step 5: Final commit**

```bash
git commit --allow-empty -m "release: submit CampConnect to Google Play and App Store production"
```

---

## Notes for the implementer

- **Every store submission and every prod deploy is outward-facing and irreversible-ish** (published
  content can be cached/indexed). Get explicit user authorization before each — do not submit or deploy
  autonomously.
- The app's genuine privacy-first design (anonymous kids, local journal, 60-day auto-cleanup, no ad
  SDKs) makes the Data Safety / privacy-label forms honest and simple — fill them truthfully.
- If the developer account is an **organisation** rather than personal, the Google Play 12-tester/14-day
  closed-test requirement may not apply — verify your account type first.
- After production release, update the roadmap checklist: Phase 8 done. 🎉
