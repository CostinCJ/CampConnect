# Google Play Data Safety Form — Draft Answers

> **Status: DRAFT.** Fill the actual Play Console form using these as source
> material; verify against the current build first.

## Does your app collect or share user data?
Yes.

## Data types collected

| Data type | Collected? | From whom | Purpose | Shared with 3rd parties? | Optional/required |
|---|---|---|---|---|---|
| Email address | Yes | Guides only | Account creation/sign-in | No | Required (guides) |
| Name | Yes | Guides (display name), Kids (self-chosen first name, local-only — see note) | App functionality (personalization, leaderboard display) | No | Required |
| Photos | Yes | Guides (location/session photos) | App functionality (camp map, journal — kid photos are local-only) | No | Optional |
| Approximate location | Yes | Guides (optional live position sharing) | App functionality (camp map) | No | Optional |
| App activity / in-app messages | Yes | Both | App functionality (announcements, points, emergency alerts) | No | Required for core features |
| Device or other IDs | Yes | Kids (Firebase anonymous auth UID only) | App functionality (session identity, not used for tracking/advertising) | No | Required |

**Note on kid first names and journal data:** these are stored **only on the
device** (local Hive database), never transmitted to or stored on our servers.
If the Play Console form distinguishes "collected" (leaves the device) from
"processed on-device only", the kid's chosen first name and journal
entries/photos should be marked as **not collected** — only their team/camp
assignment and anonymous session UID are server-side.

## Is all data encrypted in transit?
Yes — all network traffic goes through Firebase services (Firestore, Storage,
Auth, Cloud Functions, Cloud Messaging), which use TLS.

## Do you provide a way for users to request data deletion?
Yes.
- In-app: Settings → "Delete account" (guides) / "Delete my data" (kids).
- Both call a server-side deletion path that removes the Firestore profile and
  the Firebase Auth account; for a guide who owns an organisation, all of that
  organisation's camps and data are also deleted.

## Is data sold to third parties?
No.

## Is data shared with third parties?
No third-party sharing. No third-party ad SDKs, no third-party analytics SDKs.
The only external processor is Firebase/Google Cloud, which is a data
processor for this app's own functionality (not a third-party recipient in the
Play Data Safety sense — declare per Google's current guidance on this
distinction, which may require listing Firebase explicitly as a service
provider even though no separate "sharing" occurs).

## Does your app target children?
Mixed audience — see `docs/store/audience.md` for the target-audience
declaration and rationale.
