# CampConnect Privacy Policy

**Last updated:** [DATE — fill in before publishing]

CampConnect is a mobile app used by summer camp organisers ("guides") to run camp
sessions, and by campers ("kids") to participate in them. This policy explains what
data the app collects, why, and how it is handled. It reflects the app's actual
design — the app was built with data minimisation as a core principle.

## Data controller

CampConnect is operated by Joldeș Costin-Cristian, acting as a private individual
(sole controller — no separate legal entity), contactable at the address in
"Contact" below. If CampConnect is later operated through a registered company or
PFA, this section will be updated to name that entity as controller.

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
- Guides may photograph camp activities that include your child (e.g. a team
  group photo) and upload it to the app. Unlike your journal, these photos are
  stored on our servers (not local-only) and are subject to the same 60-day
  retention as other camp content described below.

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
This applies to emergency alerts too — guides should avoid including a child's
full name or sensitive medical details in an alert message; the in-app alert
composer repeats this reminder.

## Crash reporting

We use Firebase Crashlytics to catch and fix bugs. **Crash reporting is enabled
only for signed-in guide accounts.** It is never enabled for anonymous kid
sessions, and we never associate a kid's device with a crash report.

Crash reports are retained for Firebase Crashlytics' standard retention period
(90 days) and, as noted above, are never linked to a kid's account or device
identity.

## Data retention

- Camp sessions (and everything under them — codes, teams, points history,
  announcements, schedule, emergency alerts) are **automatically and permanently
  deleted 60 days after the camp's end date**, via a scheduled server-side job.
- A kid's local journal and display name persist only until they delete the app,
  use "Delete my data" in Settings, or the local storage is otherwise cleared.

## Where your data is stored

CampConnect's backend runs on Google Firebase / Google Cloud. The Firestore
database and Storage (photos) are located in the EU (`eur3`, Belgium +
Netherlands) — the data described in this policy is stored in the EU. Cloud
Functions (brief server-side processing — e.g. validating a camp code, sending
a push notification) are being migrated to run in the EU (`europe-west1`) as
well; until that migration is complete, this transient processing step occurs
in the US. Where any processing does occur outside the EEA, Google's standing
certification under the EU-US Data Privacy Framework (and/or Standard
Contractual Clauses, where applicable) is the safeguard relied upon for that
transfer.

## Your rights and how to delete your data

- **Guides**: Settings → "Delete account" permanently deletes your account. If
  you are the owner of an organisation, this also deletes the organisation and
  every camp under it.
- **Kids**: Settings → "Delete my data" permanently deletes your camp
  participation record from our servers and clears your local journal and name
  from the device.
- You can also contact us directly (see below) to request deletion.
- You also have the right to lodge a complaint with your national data
  protection authority — in Romania, ANSPDCP (dataprotection.ro); in Hungary,
  NAIH (naih.hu); or the authority in your own country of residence.

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
  automatically deleted (see "Data retention" above). We judge this balance to
  favour the minimal processing described here. A guardian or camp organiser
  who objects to this processing can request deletion at any time (see "Your
  rights and how to delete your data" above), which is treated as equivalent to
  an objection.

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
