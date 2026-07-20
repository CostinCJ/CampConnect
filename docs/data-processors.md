# Data Processors

Internal reference (not necessarily public-facing) confirming Article 28 GDPR coverage for every
third party that processes personal data on CampConnect's behalf.

**Data controller:** Joldeș Costin-Cristian, private individual (see
[privacy-policy.md](privacy-policy.md) "Data controller").

| Processor | Role | DPA / terms relied on |
|---|---|---|
| Google Cloud / Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Crashlytics) | Hosts all backend data | Google Cloud's standard Cloud Data Processing Addendum, auto-accepted via the Firebase/GCP Terms of Service |
| MapTiler | Serves map tiles; may see requesting IP addresses | MapTiler's standard Terms of Service / Privacy Policy (see maptiler.com) |
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
  `functions/index.js`'s `setGlobalOptions({ region: "europe-west1" })`) is complete; there is no
  remaining EU/US boundary crossing for this app's processing.
