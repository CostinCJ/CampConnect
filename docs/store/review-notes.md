# App Review Notes — Draft

> **Status: DRAFT — demo credentials are placeholders.** Before submitting,
> create a real test guide account (and a camp + join code) on the **production**
> Firebase project and fill in the fields below. Do not submit with placeholder
> credentials.

## Explaining the invite-code onboarding

CampConnect's camper ("kid") flow deliberately has no sign-up screen. A camp
guide (an adult organiser, verified by an email/password account gated behind
a per-organisation invite code) generates one-time join codes and hands them
out in person or via the camp's existing communication channels. A camper
enters that code in the app, which:

1. Signs them in anonymously (Firebase Anonymous Auth — no email, no personal
   info collected).
2. Assigns them to the camp/team the code was generated for.
3. Lets them pick a display first name, stored **only on their own device**.

There is no way to create a camper account from outside this flow, no public
sign-up, and no way for a camper to contact anyone outside their own camp's
guides.

## Guide account creation

A new guide either creates a brand-new organisation (becoming its owner) or
joins an existing one using that organisation's invite code (shared by the
owner). This is also gated server-side — no client-side write can assign a
`guide` role or fabricate organisation membership.

## Demo credentials for reviewers

- **Guide test account:**
  - Email: `[FILL IN — create a real test account before submitting]`
  - Password: `[FILL IN]`
- **Test camp join code (for the camper flow):**
  - Code: `[FILL IN — generate from the guide test account before submitting]`

## Suggested reviewer walkthrough

1. Sign in with the guide test account → guide dashboard.
2. Open "Camp Sessions" → confirm an active test session exists (or create one).
3. Open "Codes" → confirm the test join code above is valid and unused.
4. Sign out, go to "I'm a Camper" (or equivalent role-selection option), enter
   the join code → confirm the camper flow works without any account creation
   or personal-data entry beyond a first name.
5. From the camper side, check the map, leaderboard, and journal (journal
   entries stay local to the device/reviewer's test device).

## Anticipated questions

- *"Why does a children's app not require parental consent in-app?"* — see
  `docs/store/audience.md` for the rationale: campers never self-register:
  the invite code is the consent-equivalent gate, controlled entirely by the
  adult organiser.
- *"What happens to camp data after the camp ends?"* — automatically deleted
  60 days after the camp's end date via a scheduled Cloud Function
  (`cleanupExpiredCamps`).
