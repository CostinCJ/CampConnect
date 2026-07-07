# Multi-Org Onboarding & Owner Management — Design

**Date:** 2026-07-06
**Status:** Approved (brainstorming session)
**Scope:** Front-door UX redesign (role selection + registration), day-0 onboarding checklist, owner management tools. No changes to the underlying org/membership data model.

## Problem

The app's data model already supports many independent organisations (each with an owner, an invite code, member guides, camp sessions, and kid codes), but the UX hides it:

1. A camp organiser installing the app sees only "I'm a kid / I'm a guide" — no visible path that says "set up your camp". The create-organisation option is a segmented toggle buried mid-form in guide registration.
2. After creating an organisation, the owner lands on an empty guide home with no guidance toward the three day-0 tasks: create a session, invite guides, generate kid codes.
3. The org invite code — the answer to "how do I add my guides?" — is only visible deep in Settings.
4. The owner has no way to see their members, remove a guide, or rotate a leaked invite code.

## Decisions already made

- **Organiser is not a separate role.** Real-world organisers are usually also guides. The model stays: one `guide` role; the organisation's `ownerUid` grants owner powers. No second account type.
- **Both organisers and guides register with email/password** via the existing `registerGuide` callable. Only kids use code-based anonymous login.
- **Approach chosen:** three-door entry (A). Invite deep-links (C) are a future enhancement, out of scope here.

## 1. Entry flow — role selection

`lib/features/auth/presentation/role_selection_screen.dart` changes from 2 tiles to 3:

| Tile | Subtitle intent | Destination |
|---|---|---|
| I'm setting up a camp | For organisers creating their organisation | `/guide-login?mode=create-org` |
| I'm a guide | "I have an invite code from my organiser" | `/guide-login?mode=join-org` |
| I'm a kid | unchanged | `/kid-login` |

Both adult tiles land on the same screen and account type; the tile only pre-selects the registration mode. Sign-in for returning users is unchanged (email/password, login/register toggle still present).

## 2. Registration screen

`lib/features/auth/presentation/guide_login_screen.dart` accepts a `mode` query parameter (`create-org` | `join-org`, default `join-org`):

- **create-org:** register form shows Organisation name field; no invite code field; title "Set up your camp organisation".
- **join-org:** register form shows Invite code field; title "Join your organisation".
- A small text link lets the user switch modes in place (wrong-door recovery); the segmented toggle as primary UI is removed.
- Common fields in both modes: display name, email, password, privacy policy consent.
- Backend call unchanged: `registerGuide` with `newOrgName` XOR `joinOrgCode`.

## 3. Day-0 onboarding checklist

A dismissible card at the top of the guide home, visible only while incomplete and only meaningful for org owners:

1. ☐ Create your first camp session → navigates to the camp sessions screen
2. ☐ Invite your guides → opens the OS share sheet with a ready message: "Join {orgName} on CampConnect with code {inviteCode}" (localised)
3. ☐ Generate kid codes → navigates to code management

Rules:

- Step completion is **derived from live Firestore data**, not persisted: step 1 = org has ≥1 camp session; step 2 = org has ≥2 members; step 3 = ≥1 kid code exists for the org.
- Card hides automatically when all steps are complete, and can be dismissed manually (dismissal persisted locally, e.g. shared preferences — not in Firestore).
- A guide who joined an existing org never sees the card (they are not `ownerUid`).

## 4. Owner management — "My organisation" screen

New screen at `lib/features/organization/presentation/organization_screen.dart`, reachable from guide home and from Settings (replacing the buried invite-code tile as the primary path; the settings entry becomes a link to this screen):

- Header: org name. Invite code with **copy** and **share** actions — shown to the owner only, matching today's behaviour; non-owner members see the member list but not the code.
- Member list from `organizations/{orgId}/members`: display name, role badge (owner/guide), joined date.
- Owner-only actions:
  - **Remove guide** — confirmation dialog; not available against the owner themself.
  - **Rotate invite code** — confirmation dialog explaining the old code stops working.

### Backend additions (Cloud Functions)

Two new callables, following the existing `registerGuide`/`deleteMyAccount` patterns (server-side only writes; client writes remain denied by rules):

- `removeMember({ memberUid })`
  - Caller must be authenticated and be `ownerUid` of their org; otherwise `permission-denied`.
  - Cannot remove the owner (`invalid-argument`).
  - Deletes `organizations/{orgId}/members/{memberUid}`, clears `orgId` (and `campId`) on `users/{memberUid}`, and clears the member's org custom claims so security-rule access ends immediately.
- `rotateInviteCode()`
  - Caller must be `ownerUid`; otherwise `permission-denied`.
  - Generates a new code via the existing `generateOrgInviteCode` with the same uniqueness check used at org creation; updates `organizations/{orgId}.inviteCode`.

No security-rule changes are expected (org docs are already client-write-denied); rules tests must confirm that remains true for the new mutations.

**Accepted limitation — stale-claims window:** security rules authorise via custom claims in the ID token, and `removeMember` cannot force a token refresh. A removed guide's existing token (with the old `orgId` claim) keeps passing rules for up to ~1 hour until it refreshes; during that window they can still read org data and write to the org-scoped paths their old claims allow. `revokeRefreshTokens` would not close this (Firestore rules don't check revocation). Accepted for the current threat model — an owner removing their own staff. In practice the client only notices the removal on the next app start (the in-memory profile isn't re-fetched mid-session), at which point the router sends them to the join screen; after ~1h their old token expires and org reads start failing, and a restart self-heals. The join direction is NOT subject to this window: after a successful `joinOrganization` the client force-refreshes the ID token so the new claims apply immediately. Revisit with a rules-side membership-existence check on sensitive write paths if the threat model changes.

## 5. Localisation

All new user-facing strings added to `app_en.arb`, `app_ro.arb`, `app_hu.arb` and regenerated via gen-l10n. This includes the three tile labels/subtitles, mode-specific registration titles, checklist step labels, the share message template ({orgName}, {inviteCode} placeholders), member-management labels, and the two confirmation dialogs.

## 6. Error handling

- `removeMember` / `rotateInviteCode` failures map to localised messages through the same friendly-error pattern used by `friendlyGuideAuthError` (new small mapper for org-management error vocabulary).
- Removed guide's client: on next auth-state/user refresh they have no `orgId` → the router redirects them to a **Join your organisation** screen (`/join-organization`): enter an invite code → new `joinOrganization` callable (signed-in guide with no org + valid code → membership + profile `orgId` + claims), or sign out. This callable is required because `registerGuide` only creates new accounts — without it a removed guide's existing account would have no way back into any organisation.
- Share sheet unavailable (rare, platform-level): fall back to copy-to-clipboard with snackbar.

## 7. Testing

- **Widget tests:** 3-tile role selection navigates with the right `mode`; registration form renders the correct fields per mode; mode-switch link works; day-0 checklist shows/hides per derived state and only for owners.
- **Function tests (emulator, Jest):** for each new callable — owner succeeds; non-owner gets `permission-denied`; unauthenticated gets `unauthenticated`; `removeMember` on the owner fails; removed member's user doc and claims are cleared; rotated code differs and old code no longer matches on `registerGuide` join.
- **Rules tests:** org and member docs still deny client writes.

## Out of scope

- Invite deep-links (`campconnect://join?code=...`) — future enhancement layered on this design.
- Multi-org membership per guide (Slack-workspace style).
- Any change to kid login or camp-code claiming.
