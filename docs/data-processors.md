# Data Processors

Internal reference (not necessarily public-facing) confirming Article 28 GDPR coverage for every
third party that processes personal data on CampConnect's behalf.

| Processor | Role | DPA / terms relied on |
|---|---|---|
| Google Cloud / Firebase (Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Crashlytics) | Hosts all backend data | Google Cloud's standard Cloud Data Processing Addendum, auto-accepted via the Firebase/GCP Terms of Service |
| MapTiler | Serves map tiles; may see requesting IP addresses | MapTiler's standard Terms of Service / Privacy Policy (see maptiler.com) |
| Codemagic | CI/CD — builds and signs the iOS app | Does not process end-user personal data; not a GDPR processor for this app's user data |

Revisit this table any time a new third-party SDK or service is added.
