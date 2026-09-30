# Legitimate Interest Assessment — Kid (Camper) Data

Internal accountability record (GDPR Art. 5(2) "accountability principle"), not itself
user-facing. Formalizes the balancing test summarized in
[privacy-policy.md](privacy-policy.md) ("Legal basis (GDPR)" → "Kid data") into the standard
three-part LIA structure. **This is not a substitute for review by a qualified data-protection
lawyer** — it documents the reasoning, which a supervisory authority (ANSPDCP) could ask to see.

**Roles (decided 2026-09-30):** each camp organisation is the **controller** for its camp data,
including kid data; CampConnect is its **processor** under the
[organiser terms](organiser-terms.md). This assessment is the one CampConnect is designed around
and offers to organisations; each organisation adopts it (or its own) as controller, and confirms
that responsibility when it creates its organisation (see "Organiser attestation" below).

## 1. Purpose test — what is the legitimate interest?

Operating the camp-coordination service (leaderboard, announcements, emergency alerts, map) that
a camp organisation has engaged CampConnect to provide for a camp session the child is already,
offline, enrolled in. The interest is the controller's (and the organising camp's) ordinary
business interest in running the software the organisation is paying for / using — not marketing,
profiling, or any interest beyond delivering the coordination features described in the privacy
policy.

## 2. Necessity test — is this processing necessary for that purpose?

- **Anonymous session identity** (Firebase anonymous auth uid): required to let the app remember
  which camp/team a device belongs to for the session's duration. No alternative that avoids some
  form of device/session identity exists for a returning-user experience.
- **Self-chosen first name**: required to personalise the in-app experience (journal, leaderboard
  display). Not verified against any real-world identity document; a child can type anything.
- **Team assignment**: required for the leaderboard and to route team-scoped push notifications —
  the core features the organisation engaged the service for.
- **Nothing beyond this is collected** (i.e. leaves the device) from kids: no surname, no contact
  details, no persistent device identifiers beyond the session-scoped anonymous auth uid, no
  location history, no behavioral profiling.

**Device-only processing (re-assessed 2026-09-30).** These never leave the kid's device and are
not "collected" by the organisation or CampConnect, but are recorded here because they are about
the child:

- **Explorer Passport stamps**: which camp locations the kid checked in at, and when. This is a
  self-reported location history (no proximity check — the kid taps "check in"). Stored encrypted
  on the device, shown only to the kid, optionally included in their own journal PDF export.
- **Quiz results**: best score per location quiz. Device-only.
- **Opt-in own-position dot** on the map: off by default for kids; turned on only through an
  explanatory dialog plus the OS permission prompt. The GPS position is used live on the device
  and never stored or uploaded.
- **Per-install random ID** (`journal_device_id`): labels the on-device journal/passport storage.
  Not a hardware or advertising ID, never uploaded, reset by reinstalling.
- **Shared devices**: journal and passport belong to the device and survive sign-out by design
  (a kid who gets a new code keeps their diary). The sign-out dialog offers an explicit "erase
  from this phone" option for shared camp devices.

Conclusion for these: device-only, under the child's own control, deletable in-app — negligible
additional risk; no change to the balance below.

**Server-side, not kid-specific:** rate-limit counters keyed by a **hash** of the caller's IP
address (never the raw IP) and deleted once older than the one-hour window. Necessary to stop
brute-forcing of camp codes (which protects the children's camps); minimal and short-lived.

Conclusion: the data collected is the minimum necessary for the stated purpose; no less intrusive
alternative achieves the same functionality.

## 3. Balancing test — does the child's interest override the legitimate interest?

**Factors favouring processing:**
- Negligible privacy impact: no real name, no contact info, no persistent identifier beyond the
  camp session, no data shared outside the child's own camp.
- Automatic deletion: camp data (including the kid's `users/{uid}` profile — see
  [firestore-schema.md](firestore-schema.md) / `functions/lib/deleteCampCascade.js`) is deleted no
  later than 60 days after the camp ends, regardless of whether anyone requests it.
- No profiling, advertising, or third-party sharing of any kind (see privacy-policy.md "What we do
  NOT collect").
- The processing happens within, and is gated by, an existing offline relationship: the child is
  already enrolled in the camp through their parent/guardian and the organising camp; CampConnect
  is a coordination tool for an activity that already has the guardian's consent-equivalent
  authority behind it, not an independent point of contact with the child.
- The child (via their guardian, through the organising camp) can request deletion at any time,
  treated as equivalent to an objection (privacy-policy.md "Your rights").

**Factors favouring the child's interest / risk factors:**
- Children cannot themselves assess or object to data processing with full understanding.
- Group/session photos are stored server-side (not local-only, unlike the journal) and may depict
  identifiable children — see "Children's photos" note below.
- The offline-consent chain (parent → camp organiser → CampConnect) is not independently verified
  by the controller for every organisation using the app — it is *assumed* to exist as part of the
  organisation's own camp-enrolment process.

**Conclusion:** the balance favours the minimal processing described here, given the negligible
data footprint, automatic deletion, and the absence of any profiling/advertising/third-party
sharing. This conclusion is contingent on the assumption below holding true.

## Organiser attestation (implemented 2026-09-30)

Creating an organisation now requires its owner to tick an attestation that the organisation is
the controller for the children's data it enters, has a lawful basis for it, informs parents, and
accepts the [organiser terms](organiser-terms.md). `registerGuide` rejects org creation without it
(`organiser-attestation-required`) and stores `attestedAt`, `attestedBy` and
`organiserTermsVersion` on the `organizations/{orgId}` doc as evidence.

The kid sign-in screen no longer says "By continuing you agree…" (which framed the processing as
consent, contradicting this legitimate-interest basis); it now informs the kid that the organiser
decides what is stored and links to the privacy policy.

Still open: model wording organisations can give parents (an optional appendix to the organiser
terms), and a DPIA screening for minors' images (see "Children's photos" below).

## Children's photos — distinct note

Session/team group photos (uploaded by guides, stored in Cloud Storage, not local-only) may depict
identifiable children and are covered by the same legitimate-interest basis and 60-day retention
as other camp content. They are readable only by the organisation's guides and the kids **of that
same camp** (`storage.rules`), are served with `Cache-Control: private` so no shared/edge cache
keeps a copy, and are deleted with the camp (`deleteCampCascade`, including the org-scoped
`organizations/{orgId}/sessionPhotos/{campId}/` path). Because these are visual, potentially-identifying data (unlike the
non-identifying text fields above), this is the single highest-risk category of kid data the app
processes and the one most worth an organiser explicitly knowing they're responsible for having
consent to capture and share via the app.

## Review cadence

Re-assess this LIA whenever: kid-facing data collection changes, retention periods change, or a
new feature processes additional data about children.
