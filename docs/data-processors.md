# Data Processors

Internal reference (not necessarily public-facing) confirming Article 28 GDPR coverage for every
third party that processes personal data on CampConnect's behalf.

**Roles:** each camp organisation is the **controller** for its camp data; CampConnect (Joldeș
Costin-Cristian, private individual) is its **processor** under the
[organiser terms](organiser-terms.md), and the controller only for guide accounts and service
operation. The processors below are therefore CampConnect's **sub-processors** for camp data;
organisations are told about them (organiser terms section 3).

| Processor | Role | DPA / terms relied on |
|---|---|---|
| Google Cloud / Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Crashlytics) | Hosts all backend data | Google Cloud's standard Cloud Data Processing Addendum, auto-accepted via the Firebase/GCP Terms of Service |
| MapTiler | Serves map tiles; may see requesting IP addresses | MapTiler's standard Terms of Service / Privacy Policy (see maptiler.com) |
| GitHub Pages (GitHub, Inc.) | Hosts the public privacy policy / organiser terms and the camp TV leaderboard page (`docs/`); sees visitor IP addresses like any web host | GitHub's Terms of Service and Data Protection Agreement; US-hosted, GitHub is certified under the EU-US Data Privacy Framework |
| Codemagic | CI/CD — builds and signs the iOS app | Does not process end-user personal data; not a GDPR processor for this app's user data |

Revisit this table any time a new third-party SDK or service is added.

## Processing locations (confirmed 2026-07-13)

- **Firestore** (`camp-connect-4644c`, default database): `eur3` (EU multi-region — Belgium +
  Netherlands). Confirmed via `firebase firestore:databases:list --json`.
- **Cloud Storage** (default bucket): shares the project's single default GCP resource location,
  set once at Firestore provisioning time — so also `eur3`/EU. Not independently confirmed via API
  (bucket metadata requires an authenticated request this check didn't have), but this is how
  Firebase provisions the default bucket; verify directly in the GCP Console if this matters for a
  future audit.
- **Cloud Functions**: `europe-west1` for all 13 deployed functions — confirmed via
  `firebase functions:list -P default` on 2026-07-13. The migration from `us-central1` (tracked in
  `functions/index.js`'s `setGlobalOptions({ region: "europe-west1" })`) is complete.
- **Not region-pinned (global services):** Firebase Authentication, Firebase Cloud Messaging and
  Firebase Crashlytics are global Google services and may process data outside the EU (including
  the US); GitHub Pages is US-hosted. These transfers rely on the EU-US Data Privacy Framework
  and/or the Standard Contractual Clauses in the providers' terms, as stated in the privacy
  policy's "Where your data is stored and international transfers" section. **Manual check before
  launch:** confirm each product's current processing locations in Google's Firebase privacy/
  data-location documentation and update this list if it changed.
