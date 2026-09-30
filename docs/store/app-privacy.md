# Apple App Privacy (Nutrition Labels) — Draft Answers

> **Status: DRAFT.** Fill the actual App Store Connect "App Privacy" section
> using these as source material; verify against the current build first.

## Data collected

| Category | Data | Linked to identity? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Contact Info | Email address | Yes (guides) | No | App Functionality |
| Contact Info | Name | Yes (guides); kid first name is local-only, not collected | No | App Functionality |
| User Content | Photos | Yes (guides) | No | App Functionality |
| User Content | Other user content (announcements, camp content) | Yes (guides) | No | App Functionality |
| Location | Precise location | Yes (guides only, optional: attached to an emergency alert) | No | App Functionality |
| Identifiers | Device ID (anonymous Firebase UID, kids only) | No — not linked to real identity | No | App Functionality |
| Diagnostics | Crash data | Yes (guides only — never collected for kids) | No | App Functionality |

## Tracking
**No tracking.** CampConnect does not use the data collected above to track
users across apps or websites owned by other companies, and does not use it
for third-party advertising. No SKAdNetwork / ATT prompt is needed since no
tracking occurs.

The app's `ios/Runner/PrivacyInfo.xcprivacy` privacy manifest declares the same
data types; keep the two in sync.

## Kid-specific notes for the label
- A kid's chosen first name and journal (text + photos) never leave the
  device — do not declare these as "collected" if App Store Connect
  distinguishes on-device-only data from collected data.
- The Explorer Passport, quiz results and the kid's opt-in "my location" map
  dot are also on-device only; do not declare them.
- Crash reporting (Crashlytics) is disabled natively at launch
  (`FirebaseCrashlyticsCollectionEnabled = false` in `Info.plist`) and in code
  (`lib/main.dart` / `lib/app.dart`); it is only enabled once a signed-in guide
  session is detected.

## Data deletion
The app supports in-app account/data deletion (Settings → "Delete account" /
"Delete my data"), satisfying Apple's account-deletion requirement.
