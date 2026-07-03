/* eslint-disable no-console */
/* One-time migration to the multi-org model.
 * - Creates a default organization owned by DEFAULT_OWNER_UID.
 * - Backfills orgId on all camps and all guide user docs.
 * - Moves top-level locations/ -> organizations/{orgId}/locations/.
 * - Copies every camps/X/codes/Y into top-level codes/Y with campId+orgId.
 * - Sets custom claims { role, orgId } for every guide.
 * Usage: node migrate_to_orgs.js <projectId> <defaultOwnerUid> <orgName>
 */
const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const [, , PROJECT_ID, DEFAULT_OWNER_UID, ...NAME_PARTS] = process.argv;
if (!PROJECT_ID || !DEFAULT_OWNER_UID || NAME_PARTS.length === 0) {
  console.error("Usage: node migrate_to_orgs.js <projectId> <ownerUid> <org name>");
  process.exit(1);
}
const ORG_NAME = NAME_PARTS.join(" ");

const SA = path.join(__dirname, "service-account.json");
admin.initializeApp(
  fs.existsSync(SA)
    ? { credential: admin.credential.cert(require(SA)), projectId: PROJECT_ID }
    : { projectId: PROJECT_ID }
);
const db = admin.firestore();

async function main() {
  // 1. Default org.
  const orgRef = db.collection("organizations").doc();
  await orgRef.set({
    name: ORG_NAME,
    ownerUid: DEFAULT_OWNER_UID,
    inviteCode: "JOIN-" + Math.random().toString(36).slice(2, 6).toUpperCase(),
  });
  console.log("Created org", orgRef.id);

  // 2. Guides -> members + orgId + claims.
  const guides = await db.collection("users").where("role", "==", "guide").get();
  for (const g of guides.docs) {
    await orgRef.collection("members").doc(g.id).set({
      role: g.id === DEFAULT_OWNER_UID ? "owner" : "guide",
      displayName: g.data().displayName || "",
    });
    await g.ref.update({ orgId: orgRef.id });
    await admin.auth().setCustomUserClaims(g.id, { role: "guide", orgId: orgRef.id });
    console.log("Migrated guide", g.id);
  }

  // 3. Camps -> orgId; codes -> top level; kids -> orgId.
  const camps = await db.collection("camps").get();
  for (const camp of camps.docs) {
    await camp.ref.update({ orgId: orgRef.id });
    const codes = await camp.ref.collection("codes").get();
    for (const c of codes.docs) {
      await db.doc(`codes/${c.id}`).set({
        ...c.data(),
        campId: camp.id,
        orgId: orgRef.id,
      });
    }
    console.log(`Migrated camp ${camp.id} (${codes.size} codes)`);
  }
  const kids = await db.collection("users").where("role", "==", "kid").get();
  for (const k of kids.docs) {
    await k.ref.update({ orgId: orgRef.id });
  }

  // 4. Locations -> under org.
  const locs = await db.collection("locations").get();
  for (const l of locs.docs) {
    await orgRef.collection("locations").doc(l.id).set(l.data());
    await l.ref.delete();
  }
  console.log(`Moved ${locs.size} locations. Done.`);
}

main().then(() => process.exit(0));
