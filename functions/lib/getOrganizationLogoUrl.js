const { HttpsError } = require("firebase-functions/v2/https");

/**
 * Returns only the signed-in user's organisation logo URL.
 *
 * Kids cannot read organizations/{orgId} directly because that document also
 * contains guide invite data. This callable lets the PDF export get the logo
 * without broadening Firestore rules or depending on Storage rules'
 * cross-service Firestore reads.
 */
async function getOrganizationLogoUrlHandler(db, auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");

  const userSnap = await db.doc(`users/${auth.uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || !user.orgId) {
    return { logoUrl: "" };
  }

  const orgSnap = await db.doc(`organizations/${user.orgId}`).get();
  if (!orgSnap.exists) {
    return { logoUrl: "" };
  }

  const logoUrl = orgSnap.data().logoUrl;
  return { logoUrl: typeof logoUrl === "string" ? logoUrl : "" };
}

module.exports = { getOrganizationLogoUrlHandler };
