# CampConnect Privacy Policy

**Last updated:** [DATE — fill in before publishing]

CampConnect is a mobile app used by summer camp organisers ("guides") to run camp
sessions, and by campers ("kids") to participate in them. This policy explains what
data the app collects, why, and how it is handled. It reflects the app's actual
design — the app was built with data minimisation as a core principle.

## Who this applies to

- **Guides**: adult camp organisers/staff who create an account with an email and
  password.
- **Kids**: campers who join a camp session using a one-time code given to them by
  a guide. Kids never create an account, never provide an email address, and never
  enter any personal information beyond a first name they choose themselves.

## What we collect

**From guides:**
- Email address and password (for account sign-in).
- Display name.
- Camp content they create: camp session names/dates, teams, points history,
  announcements, schedule entries, emergency alerts, and location descriptions for
  the camp map.
- Photos they optionally attach to map locations or session group photos.

**From kids:**
- A first name they choose when joining (stored only on their own device — see
  "Local-only data" below).
- Their camp/team assignment (needed for the leaderboard and to route
  notifications).
- Journal entries and photos they write/take in the app — **these stay on the
  device and are never uploaded to our servers.**
- An anonymous device identity (Firebase anonymous authentication) used only to
  let the app remember which camp/team they belong to for the duration of the
  camp session. This identity is not linked to any real-world personal
  information.

**Location data:** the map shows the camp's pre-set locations (added by guides).
If a guide adds their live position to help campers find them, that is an
approximate, in-app-only location shared while the feature is active — it is not
continuously tracked or stored as location history.

## What we do NOT collect

- No advertising identifiers, no third-party ad SDKs.
- No third-party analytics SDKs.
- No device identifiers, contacts, or precise background location.
- No personal information from kids beyond the first name they type in, which
  never leaves their device.

## Local-only data

A kid's journal (entries + photos) and chosen display name are stored **only on
the device**, in a per-account local database. They are never transmitted to our
servers and are not part of any backup we control. Uninstalling the app, or using
the in-app "Delete my data" option, removes this local data.

## Push notifications

Guides and kids can receive push notifications (new announcements, points
changes, emergency alerts) via Firebase Cloud Messaging. Notification content for
a given camp/team is visible to anyone who could technically subscribe to that
camp/team's notification topic; do not treat notification bodies as confidential.

## Crash reporting

We use Firebase Crashlytics to catch and fix bugs. **Crash reporting is enabled
only for signed-in guide accounts.** It is never enabled for anonymous kid
sessions, and we never associate a kid's device with a crash report.

## Data retention

- Camp sessions (and everything under them — codes, teams, points history,
  announcements, schedule, emergency alerts) are **automatically and permanently
  deleted 60 days after the camp's end date**, via a scheduled server-side job.
- A kid's local journal and display name persist only until they delete the app,
  use "Delete my data" in Settings, or the local storage is otherwise cleared.

## Your rights and how to delete your data

- **Guides**: Settings → "Delete account" permanently deletes your account. If
  you are the owner of an organisation, this also deletes the organisation and
  every camp under it.
- **Kids**: Settings → "Delete my data" permanently deletes your camp
  participation record from our servers and clears your local journal and name
  from the device.
- You can also contact us directly (see below) to request deletion.

## Legal basis (GDPR)

- Guide account data is processed under **contract** (providing the service you
  signed up for) and **legitimate interest** (running the camp they organise).
- Kid data is processed under the **legitimate interest of the camp
  organiser/guardian** who distributed the join code, minimised to the smallest
  possible footprint (an anonymous session identity, a self-chosen first name,
  and a team assignment) — no data is collected from children beyond what is
  strictly necessary to run the camp activity they are already participating in
  offline.

## Children's privacy

CampConnect is used by children under adult supervision as part of an organised
camp activity, distributed via an invite code the organiser controls — kids never
self-register or provide contact information. We do not knowingly collect more
data from a child than described above, and we do not serve ads or run
third-party trackers anywhere in the app.

## Changes to this policy

If this policy changes materially, the "Last updated" date above will be revised
and, where required, users will be notified in-app.

## Contact

[CONTACT EMAIL — fill in before publishing]
