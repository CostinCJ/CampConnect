/* eslint-disable no-console */
/* One-off clean-up after the 2026-09-30 camp-cascade fixes (V-1, V-2).
 *
 * 1. Storage: deletes group photos / logos whose camp or org no longer exists:
 *      organizations/{orgId}/sessionPhotos/{campId}/...  (camp gone)
 *      camps/{campId}/...                                 (camp gone, legacy)
 *      organizations/{orgId}/...                          (org gone)
 * 2. Auth: lists users with no users/{uid} profile. Guides whose profile was
 *    wiped by the old cascade (claims role=guide + orgId, org still exists
 *    and lists them as a member) get their profile restored from the member
 *    doc and Auth record. Anything else is only reported.
 *
 * Dry run by default; pass --apply to actually delete / restore.
 * Usage: node sweep_orphans.js <projectId> [--apply] [--bucket=<name>]
 * The bucket defaults to <projectId>.firebasestorage.app.
 */
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const [, , PROJECT_ID, ...FLAGS] = process.argv;
if (!PROJECT_ID) {
  console.error("Usage: node sweep_orphans.js <projectId> [--apply]");
  process.exit(1);
}
const APPLY = FLAGS.includes("--apply");
const BUCKET_FLAG = FLAGS.find((f) => f.startsWith("--bucket="));
const BUCKET = BUCKET_FLAG
  ? BUCKET_FLAG.slice("--bucket=".length)
  : `${PROJECT_ID}.firebasestorage.app`;

const SA = path.join(__dirname, "service-account.json");
admin.initializeApp(
  fs.existsSync(SA)
    ? {
      credential: admin.credential.cert(require(SA)),
      projectId: PROJECT_ID,
      storageBucket: BUCKET,
    }
    : { projectId: PROJECT_ID, storageBucket: BUCKET }
);
const db = admin.firestore();
const bucket = admin.storage().bucket();

const existsCache = new Map();
async function docExists(docPath) {
  if (!existsCache.has(docPath)) {
    existsCache.set(docPath, (await db.doc(docPath).get()).exists);
  }
  return existsCache.get(docPath);
}

async function sweepStorage() {
  const [files] = await bucket.getFiles();
  const orphans = [];
  for (const file of files) {
    const parts = file.name.split("/");
    let reason = null;
    if (parts[0] === "organizations" && parts.length > 2) {
      if (!(await docExists(`organizations/${parts[1]}`))) {
        reason = "org gone";
      } else if (parts[2] === "sessionPhotos" && parts.length > 3 &&
          !(await docExists(`camps/${parts[3]}`))) {
        reason = "camp gone";
      }
    } else if (parts[0] === "camps" && parts.length > 1 &&
        !(await docExists(`camps/${parts[1]}`))) {
      reason = "camp gone (legacy path)";
    }
    if (reason) orphans.push({ file, reason });
  }
  for (const { file, reason } of orphans) {
    console.log(`${APPLY ? "DELETE" : "would delete"} ${file.name} (${reason})`);
    if (APPLY) await file.delete();
  }
  console.log(`Storage: ${orphans.length} orphaned file(s) of ${files.length}.`);
}

async function auditAuthUsers() {
  let pageToken;
  let missing = 0;
  let restored = 0;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const u of page.users) {
      if (await docExists(`users/${u.uid}`)) continue;
      missing++;
      const claims = u.customClaims || {};
      const member = claims.role === "guide" && claims.orgId
        ? await db.doc(`organizations/${claims.orgId}/members/${u.uid}`).get()
        : null;
      if (member && member.exists) {
        const profile = {
          role: "guide",
          email: u.email || "",
          displayName: member.data().displayName || u.displayName || "",
          orgId: claims.orgId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        console.log(`${APPLY ? "RESTORE" : "would restore"} guide profile ${u.uid} (${u.email})`);
        if (APPLY) await db.doc(`users/${u.uid}`).set(profile);
        restored++;
      } else {
        const kind = u.providerData.length === 0 ? "anonymous" : (u.email || "no email");
        console.log(`no profile: ${u.uid} (${kind}, claims=${JSON.stringify(claims)})`);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`Auth: ${missing} user(s) without a profile, ${restored} restorable guide(s).`);
}

async function main() {
  console.log(`Project ${PROJECT_ID} — ${APPLY ? "APPLYING" : "dry run (pass --apply to change anything)"}`);
  await sweepStorage();
  await auditAuthUsers();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
