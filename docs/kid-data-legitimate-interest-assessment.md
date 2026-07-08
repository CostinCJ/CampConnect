# Legitimate Interest Assessment — Kid (Camper) Data

Internal accountability record (GDPR Art. 5(2) "accountability principle"), not itself
user-facing. Formalizes the balancing test summarized in
[privacy-policy.md](privacy-policy.md) ("Legal basis (GDPR)" → "Kid data") into the standard
three-part LIA structure. **This is not a substitute for review by a qualified data-protection
lawyer** — it documents the controller's own reasoning, which a supervisory authority (ANSPDCP)
could ask to see.

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
- **Nothing beyond this is collected** from kids: no surname, no contact details, no persistent
  device identifiers beyond the session-scoped anonymous auth uid, no location history, no
  behavioral profiling.

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

## Open item: organiser-side consent chain is not verified

This assessment assumes every organisation using CampConnect has already obtained
parent/guardian consent for their child's camp participation (and, implicitly, for the
coordination data described here) as part of their own, offline camp-enrolment process. The
controller does not currently:
- Require organisations to confirm this as part of registration (`registerGuide`), or
- Provide organisations with model consent language to use with parents.

**Recommendation:** add a checkbox/attestation to the guide registration flow ("I confirm this
organisation has obtained parent/guardian consent for camp participation and data processing as
described in CampConnect's privacy policy") and/or a short organiser-facing terms addendum. This
closes the gap between "the balancing test assumes offline consent exists" and "the controller has
evidence that organisers were told this is their responsibility." Not implemented as of this
record — flagged for the controller to prioritize alongside publishing the privacy policy (see
privacy-policy.md's outstanding placeholders).

## Children's photos — distinct note

Session/team group photos (uploaded by guides, stored in Cloud Storage, not local-only) may depict
identifiable children and are covered by the same legitimate-interest basis and 60-day retention
as other camp content. Because these are visual, potentially-identifying data (unlike the
non-identifying text fields above), this is the single highest-risk category of kid data the app
processes and the one most worth an organiser explicitly knowing they're responsible for having
consent to capture and share via the app.

## Review cadence

Re-assess this LIA whenever: kid-facing data collection changes, retention periods change, or a
new feature processes additional data about children.
