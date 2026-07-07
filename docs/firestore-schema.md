# Firestore & Storage Schema

Compiled from `firestore.rules`, `storage.rules`, and each feature's `domain/` model classes
(`lib/features/*/domain/*.dart`) plus the Cloud Functions handlers in `functions/lib/` and
`functions/index.js` — treat those files as the source of truth if this document ever drifts
from them.

## Firestore collections

| Path | Written by | Key fields | Notes |
|---|---|---|---|
| `users/{uid}` | server-only create (`registerGuide`/`claimCampCode`); `joinOrganization` sets `orgId`, `removeMember` clears `orgId`/`campId`; client may update only the `campId` field on their own doc | `role` ('guide'\|'kid'), `email?`, `displayName`, `campId?`, `team?`, `orgId?`, `createdAt` | A guide switching `campId` must target a camp in their own org (enforced in rules); kids never write their own profile. |
| `organizations/{orgId}` | `registerGuide` / `rotateInviteCode` (owner-only) callables | `name`, `ownerUid`, `inviteCode` | Client writes denied; readable only by guides of that org. `rotateInviteCode` replaces `inviteCode` with a fresh unique code. |
| `organizations/{orgId}/members/{uid}` | `registerGuide` (owner on creation, guide on join) / `joinOrganization` (org-less guide re-joins by code) / `removeMember` (owner removes a guide) / `deleteMyAccount` (removes non-owner membership) | `role` ('owner'\|'guide'), `displayName`, `joinedAt?` | Client writes denied. `joinedAt` is absent on memberships created before it was introduced. `removeMember` also clears `orgId`/`campId` on the ex-member's `users/{uid}` doc and resets their custom claims; rules access ends on their next token refresh (≤ ~1h — see the design doc's accepted-limitation note). |
| `organizations/{orgId}/locations/{locationId}` | org-scoped guides (client, via `location_form_screen.dart`) | `name`, `latitude`, `longitude`, `description`, `category`, `photoUrl?`, `knowledgeBase` (`description`/`facts`/`funFact`), `createdBy`, `timestamp` | Master map locations, readable by any guide or kid of the org. |
| `camps/{campId}` | org-scoped guides (create/update/delete); read by camp members or org guides | `name`, `startDate`, `endDate`, `teams` (list of team names used at creation), `createdBy`, `orgId`, `language` | `language` drives the Cloud Functions notification strings ('ro'/'hu', default 'ro'). Note: this `teams` field is a static snapshot of names captured at creation — distinct from the live, mutable `camps/{campId}/teams/{teamId}` subcollection below. |
| `camps/{campId}/teams/{teamId}` | org-scoped guides | `name`, `colorHex`, `points` | The live per-team docs (points change over time) — not the same as the `teams` name list on the parent `camps/{campId}` doc. |
| `camps/{campId}/announcements/{id}` | org-scoped guides | `title`, `body`, `type` ('announcement'\|'schedule'), `pinned`, `createdBy`, `createdByName`, `timestamp`, plus `scheduledDate?`/`startTime?`/`endTime?` for schedule entries | Triggers `onAnnouncementCreated` (skips FCM for `type: 'schedule'`). |
| `camps/{campId}/emergencyAlerts/{id}` | org-scoped guides | `message`, `senderId`, `senderName`, `acknowledgedBy` (list), `timestamp` | Triggers `onEmergencyAlertCreated`. |
| `camps/{campId}/pointsHistory/{id}` | org-scoped guides | `team`, `amount`, `reason`, `addedBy`, `timestamp`, `teamName`, `teamColorHex` | Triggers `onPointsChanged` (points + rank-change notifications). |
| `camps/{campId}/sessionLocations/{id}` | org-scoped guides | `masterLocationId`, `photoUrl?`, `addedBy`, `visitedAt` | Per-session copy of a visited master location, with its own group photo. |
| `codes/{code}` (top-level) | `registerGuide`/`claimCampCode` callables (create/mark-used); org-scoped guides can create/read/list/update/delete their own org's codes directly | `campId`, `orgId`, `team`, `displayName`, `used`, `usedBy?`, `createdBy` | Doc ID is the code itself (`CAMP-XXXX`). Despite the `codesSubcollection` constant name in `app_constants.dart`, this is a **top-level** collection, not nested under `camps/{campId}` — confirmed by both `firestore.rules` (`match /codes/{code}`) and `camp_repository.dart`/`claimCampCode.js`, which reference `codes/{code}` directly. |
| `rateLimits/{key}` | Cloud Functions only (`registerGuide`/`claimCampCode`, via `rateLimiter.js`) | `count`, `windowStart` | Never client-readable/writable; the Admin SDK bypasses rules, so the explicit deny in `firestore.rules` is defense-in-depth. Key format is `"<callable>:<ip-or-uid>"`, e.g. `registerGuide:1.2.3.4` or `claimCampCode:<uid>`. |
| `config/{document=**}` | **nobody** | — | Explicitly denied in `firestore.rules` (`allow read, write: if false`) and not referenced anywhere in `lib/` or `functions/` — no code builds a `config` path. This is dead/legacy from the pre-multi-org design (a global `guideInviteCode` doc, superseded by per-org `inviteCode` on `organizations/{orgId}`). The rule can be treated as inert defense-in-depth; there is nothing left to migrate off of it. |

Notes on collections that are **not** in Firestore: `JournalEntry` (`lib/features/journal/domain/journal_entry.dart`)
and `AppSettings` (`lib/features/settings/domain/app_settings.dart`) have no `fromFirestore`/Firestore
imports — journal entries and app settings are stored locally on-device only (journal photos are local
file paths, not Storage references).

## Cloud Storage paths

| Path | Written by | Notes |
|---|---|---|
| `organizations/{orgId}/locations/{locationId}/photo.jpg` | org-scoped guides (`location_form_screen.dart`) | Max 10 MB, `image/*` content-type enforced in `storage.rules` (create/update only — deletes are allowed for the org's guides without those checks, since `request.resource` is null on delete). Deleted client-side when a guide deletes the location (`master_locations_screen.dart`), and alongside the org on `deleteMyAccount`'s owner-cascade. Readable by any guide or kid of the org. |
| `camps/{campId}/sessionLocations/{sessionLocId}/group_photo.jpg` | org-scoped guides (`add_session_location_screen.dart`) | Max 10 MB, `image/*` content-type enforced. May contain images of children. Readable by a guide of the camp's org or a member of that camp. Deleted on camp cleanup, both scheduled (`cleanupExpiredCamps`) and on account deletion (`deleteMyAccount`), via `bucket.deleteFiles({ prefix: 'camps/{campId}/' })`. |
