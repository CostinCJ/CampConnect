# Target Audience & Age Rating — Draft Answers

> **Status: DRAFT.** These are recommended answers derived from the app's actual
> code/data behavior, for whoever fills in the real Google Play Console / App
> Store Connect forms. Verify against the current build before submitting —
> this file is not itself a submission.

## Why "mixed audience", not "Made for Kids" / "Primarily child-directed"

CampConnect is used by two distinct groups in the same app:
- **Guides**: adults with email/password accounts, running camp logistics.
- **Kids**: campers who join via an invite code distributed by their camp's
  guide, participating anonymously (no account creation, no personal data
  beyond a locally-stored first name).

The app is **not** a kids' app in isolation — the guide-facing surface (session
management, points, announcements, emergency alerts) is squarely adult-facing
software. Declaring the app "Primarily child-directed" (Google) or checking
"Made for Kids" (Apple) would incorrectly restrict functionality this app
genuinely needs for its adult users (FCM push to guides, Crashlytics for guides)
and doesn't match how a mixed audience actually uses it.

**Recommendation: declare "mixed audience".**

- **Google Play** (App content → Target audience and content): select target age
  groups spanning **under 13 AND 13+/adults**. This keeps the app in Google
  Play Families policy scope for the under-13 audience (already compliant: no
  ads, no third-party trackers, no behavioral advertising identifiers for
  anyone) without forcing the stricter "Primarily child-directed" bucket.
- **Apple** (App Store Connect → App Information): do **not** enable "Made for
  Kids". Complete the standard age-rating questionnaire honestly (see below).
  Kids-data restrictions (no third-party analytics/ads) are already met
  app-wide, not just for the kid-facing screens.

## Age rating questionnaire — draft answers

Based on actual app content as of this phase:
- Violence: none.
- Sexual content: none.
- Profanity: none built into the app (user-generated announcement/journal text
  is theoretically free-form, but is created by camp staff/campers in a
  supervised context, not public-facing).
- Gambling: none.
- User-generated content: **yes** — announcements (guide-authored, visible to
  campers), journal entries (kid-authored, local-only, never leaves the
  device), and photos (guide-authored, attached to map locations/session
  group photos). None of this is publicly visible outside the camp's own
  guides/campers — there is no public feed, no cross-camp visibility, no
  stranger contact.
- Unrestricted internet access / user-to-user communication with strangers:
  no — all content is scoped to a single organisation's camps; there is no
  open messaging or discovery between unrelated users.

**Recommendation:** low/minimal age rating (e.g. Google Play "PEGI 3" /
Everyone-equivalent, Apple "4+"), noting UGC is present but access-gated and
non-public.

## Rationale for reviewers

If a reviewer questions why children can use an app with no visible parental
consent flow: the app is distributed exclusively through **adult-controlled
invite codes** — a child cannot install and start using CampConnect
independently; they need a code from the camp guide/organiser who already has
consent-equivalent authority in the in-person camp context (the same authority
a school or camp already exercises over activity participation). No child
self-registers, provides an email, or is contactable by strangers through the
app.
