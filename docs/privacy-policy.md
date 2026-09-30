# CampConnect Privacy Policy

**Last updated:** [DATE — fill in before publishing]

CampConnect is a mobile app used by summer camp organisers ("guides") to run camp
sessions, and by campers ("kids") to participate in them. This policy explains what
data the app collects, why, and how it is handled. It reflects the app's actual
design — the app was built with data minimisation as a core principle.

## Who is responsible for your data (controller and processor)

- **The camp organisation is the data controller** for everything about its
  camps: the kids' camp participation, teams, points, announcements, group
  photos and emergency alerts. The organisation decides which camps to run, who
  takes part and what is entered in the app. When an organisation is created in
  CampConnect, its owner confirms this responsibility and accepts the
  [organiser terms](organiser-terms.md) (the confirmation is stored with the
  organisation). Questions or requests about a camp's data should go to the
  organisation first; we will help it respond.
- **CampConnect is the data processor** for that camp data, acting on the
  organisation's instructions under the organiser terms. CampConnect is
  operated by Joldeș Costin-Cristian, acting as a private individual (no
  separate legal entity), contactable at the address in "Contact" below. If
  CampConnect is later operated through a registered company or PFA, this
  section will be updated to name that entity.
- **CampConnect is the controller** only for the guide accounts themselves
  (email, display name, sign-in) and for operating the service (security,
  abuse prevention, crash reports).

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
- Explorer Passport stamps (which camp map locations they checked in at, and
  when) and their quiz results — **also device-only, never uploaded.** A stamp
  is self-reported (the kid taps "check in"; the app does not verify their
  position).
- An anonymous device identity (Firebase anonymous authentication) used only to
  let the app remember which camp/team they belong to for the duration of the
  camp session. This identity is not linked to any real-world personal
  information.
- Guides may photograph camp activities that include your child (e.g. a team
  group photo) and upload it to the app. Unlike your journal, these photos are
  stored on our servers (not local-only) and are subject to the same 60-day
  retention as other camp content described below.

**Location data:**
- The map shows the camp's pre-set locations (added by guides).
- The map can show a user's **own** position as a dot. Guides see theirs by
  default; kids only after they turn it on and the device asks for permission.
  This position is used on the device only — it is never uploaded or stored.
- **Emergency alerts (guides only):** a guide sending an emergency alert can
  choose to attach their **precise GPS position** so other guides can find
  them. That position is stored with the alert in the camp's data (visible only
  to the organisation's guides) and deleted with the camp (see "Data
  retention"). It is never included in the push notification itself.

## What we do NOT collect

- No advertising identifiers, no third-party ad SDKs.
- No third-party analytics SDKs.
- No advertising or hardware device identifiers, no contacts, and no
  background location. (The app generates a random per-install ID that only
  labels the on-device journal storage; it never leaves the device.)
- No personal information from kids beyond the first name they type in, which
  never leaves their device.

## Local-only data

A kid's journal (entries + photos), Explorer Passport and chosen display name
are stored **only on the device**, in an encrypted local database that belongs to
the device (not to a particular sign-in). They are never transmitted to our
servers and are not part of any backup we control.

Because they belong to the device, they **stay on the device after signing
out**, so a kid who signs in again with a new code keeps their diary. On a
**shared device**, the kid should tick "Erase my journal and passport from this
phone" when signing out; otherwise the next person using the app on that device
can see them. Uninstalling the app, the sign-out erase option, or the in-app
"Delete my data" option removes this local data.

## Push notifications

Guides and kids can receive push notifications (new announcements, points
changes, emergency alerts) via Firebase Cloud Messaging. Notification content for
a given camp/team is visible to anyone who could technically subscribe to that
camp/team's notification topic; do not treat notification bodies as confidential.
This applies to emergency alerts too — guides should avoid including a child's
full name or sensitive medical details in an alert message; the in-app alert
composer repeats this reminder.

## Security and abuse prevention

To stop code-guessing and sign-up abuse, the server counts recent attempts per
account and per network address. The network address is stored only as a
one-way hash (never the raw IP address), and the counters are deleted once
they are more than an hour old (cleared by the daily clean-up job).

## Crash reporting

We use Firebase Crashlytics to catch and fix bugs. **Crash reporting is enabled
only for signed-in guide accounts.** It is never enabled for anonymous kid
sessions, and we never associate a kid's device with a crash report.

Crash reports are retained for Firebase Crashlytics' standard retention period
(90 days) and, as noted above, are never linked to a kid's account or device
identity.

## Data retention

- Camp sessions (and everything under them — codes, teams, points history,
  announcements, schedule, emergency alerts including any attached location,
  session group photos, and the kids' camp participation records) are
  **automatically and permanently deleted 60 days after the camp's end date**,
  via a scheduled server-side job. An organisation can also delete a camp
  earlier at any time, with the same effect.
- Deleting an organisation (by its owner deleting their account) deletes all of
  its camps, locations, photos and logo.
- A kid's local journal and display name persist only until they delete the app,
  use "Delete my data" in Settings, or the local storage is otherwise cleared.

## Where your data is stored and international transfers

CampConnect's backend runs on Google Firebase / Google Cloud. The camp data
itself stays in the EU: the Firestore database and Storage (photos) are located
in the EU (`eur3`, Belgium + Netherlands), and Cloud Functions (brief
server-side processing — e.g. validating a camp code, sending a push
notification) run in the EU (`europe-west1`).

Some supporting services are global and may process limited data outside the
EU, including in the United States:

- **Firebase Authentication** (guide email/password sign-in and the kids'
  anonymous sign-in),
- **Firebase Cloud Messaging** (delivering push notifications),
- **Firebase Crashlytics** (guide crash reports only),
- **GitHub Pages** (hosts this privacy policy and the camp TV leaderboard page;
  like any web host it sees the visiting IP address).

Where these transfers happen, they rely on the EU–US Data Privacy Framework
(for which Google and GitHub are certified) and/or the European Commission's
Standard Contractual Clauses included in the providers' data processing terms.

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

For camp data, the organisation (the controller) is responsible for its legal
basis; the basis below is the one CampConnect is designed around and that
organisations confirm when they accept the organiser terms.

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

  The resulting kid data (an anonymous session identity and a team assignment
  on the server; a self-chosen first name, journal and passport on the device
  only) is processed under the organisation's **legitimate interest** in running
  the camp activity with the coordination tool it chose. It is **not** based on
  the child's consent — the notice on the kid sign-in screen informs, it does
  not ask for agreement.
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
