# Breach Response Plan

Proportionate to a solo-developer project — this is a workable one-page plan, not an
incident-response program.

## Detection

Rely on: the R5 Cloud Functions error-rate alert (unusual spikes may indicate abuse), Firebase
Authentication's built-in anomaly signals, and periodic manual review of Firestore/Auth access
patterns in the Firebase Console.

## If a breach affecting EU users' personal data is suspected

1. **Contain**: rotate any exposed credentials immediately (see
   `docs/superpowers/plans/2026-07-05-r1-credential-hygiene.md` for the exact rotation procedure);
   if a Firestore/Storage rules gap is the cause, deploy the fix immediately (see the rollback/
   deploy procedure in `README.md`).
2. **Assess**: within 72 hours, determine whether the breach poses a risk to individuals (exposed
   guide emails, exposed kid team/camp assignments, exposed photos).
3. **Notify the supervisory authority** within 72 hours of becoming aware, if there is a risk to
   individuals: Romania's ANSPDCP (dataprotection.ro) or Hungary's NAIH (naih.hu), depending on
   which country's camps are affected — notify both if unclear.
4. **Notify affected individuals** without undue delay if the risk is high (e.g. children's photos
   or contact-adjacent data exposed).
5. **Log it**: record what happened, who was affected, and what was done — even if never
   externally reported — in a dated entry appended to this file.

## Breach log

(Empty — append a dated entry here if this plan is ever invoked.)
