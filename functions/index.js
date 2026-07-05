const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { generateOrgInviteCode } = require("./lib/inviteCode");

initializeApp();

// Localized strings for notifications
const strings = {
  ro: {
    newAnnouncement: "Anunț nou",
    emergencyTitle: "ALERTĂ DE URGENȚĂ",
    pointsAdded: "Puncte adăugate",
    pointsRemoved: "Puncte scăzute",
    teamGotPoints: "{team} a primit {points} puncte",
    teamLostPoints: "{team} a pierdut {points} puncte",
    reason: "Motiv: {reason}",
    rankUp: "Echipa ta a urcat!",
    rankDown: "Echipa ta a coborât",
    rankUpBody: "{team} este acum pe locul {rank}!",
    rankDownBody: "{team} a coborât pe locul {rank}",
  },
  hu: {
    newAnnouncement: "Új közlemény",
    emergencyTitle: "VÉSZHELYZETI RIASZTÁS",
    pointsAdded: "Pontok hozzáadva",
    pointsRemoved: "Pontok levonva",
    teamGotPoints: "{team} kapott {points} pontot",
    teamLostPoints: "{team} veszített {points} pontot",
    reason: "Ok: {reason}",
    rankUp: "A csapatod feljebb lépett!",
    rankDown: "A csapatod lejjebb csúszott",
    rankUpBody: "{team} most a {rank}. helyen áll!",
    rankDownBody: "{team} a {rank}. helyre csúszott",
  },
};

function getStrings(lang) {
  return strings[lang] || strings["ro"];
}

/**
 * Triggered when a new announcement is created.
 * Sends an FCM notification to all kids in the camp.
 * Only sends for type 'announcement', not 'schedule'.
 */
exports.onAnnouncementCreated = onDocumentCreated(
  "camps/{campId}/announcements/{announcementId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const campId = event.params.campId;

    // Only send notifications for announcements, not schedule entries
    if (data.type === "schedule") {
      console.log("Skipping notification for schedule entry");
      return;
    }

    // Determine language from camp document
    let lang = "ro";
    try {
      const campDoc = await getFirestore()
        .collection("camps")
        .doc(campId)
        .get();
      if (campDoc.exists && campDoc.data().language) {
        lang = campDoc.data().language;
      }
    } catch (e) {
      console.log("Could not read camp language, defaulting to ro");
    }

    const l = getStrings(lang);
    const topic = `camp_${campId}_kids`;
    const body =
      data.body && data.body.length > 100
        ? data.body.substring(0, 100) + "..."
        : data.body || "";

    const message = {
      topic: topic,
      notification: {
        title: data.title || l.newAnnouncement,
        body: body,
      },
      data: {
        type: "announcement",
        campId: campId,
        announcementId: event.params.announcementId,
      },
      android: {
        notification: {
          channelId: "announcements",
          priority: "default",
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`Announcement notification sent to topic: ${topic}`);
    } catch (error) {
      console.error("Error sending announcement notification:", error);
    }
  }
);

/**
 * Triggered when a new emergency alert is created.
 * Sends a HIGH-priority FCM notification to all guides in the camp.
 */
exports.onEmergencyAlertCreated = onDocumentCreated(
  "camps/{campId}/emergencyAlerts/{alertId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const campId = event.params.campId;

    // Determine language from camp document
    let lang = "ro";
    try {
      const campDoc = await getFirestore()
        .collection("camps")
        .doc(campId)
        .get();
      if (campDoc.exists && campDoc.data().language) {
        lang = campDoc.data().language;
      }
    } catch (e) {
      console.log("Could not read camp language, defaulting to ro");
    }

    const l = getStrings(lang);
    const topic = `camp_${campId}_guides`;

    const message = {
      topic: topic,
      notification: {
        title: l.emergencyTitle,
        body: data.message || "",
      },
      data: {
        type: "emergency",
        campId: campId,
        alertId: event.params.alertId,
        senderName: data.senderName || "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "emergency",
          priority: "max",
          defaultVibrateTimings: true,
          defaultSound: true,
          notificationCount: 1,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "interruption-level": "time-sensitive",
          },
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`Emergency notification sent to topic: ${topic}`);
    } catch (error) {
      console.error("Error sending emergency notification:", error);
    }
  }
);

/**
 * Triggered when points are added/removed.
 * - Sends points notification ONLY to the affected team.
 * - Detects rank changes and notifies teams that moved up/down.
 */
exports.onPointsChanged = onDocumentCreated(
  "camps/{campId}/pointsHistory/{entryId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const campId = event.params.campId;
    const amount = data.amount || 0;
    if (amount === 0) return;

    const changedTeam = data.team || "";

    // Read camp language
    let lang = "ro";
    try {
      const campDoc = await getFirestore()
        .collection("camps")
        .doc(campId)
        .get();
      if (campDoc.exists && campDoc.data().language) {
        lang = campDoc.data().language;
      }
    } catch (e) {
      console.log("Could not read camp language, defaulting to ro");
    }

    const l = getStrings(lang);

    // Read all teams for rank comparison
    const teamsSnapshot = await getFirestore()
      .collection("camps")
      .doc(campId)
      .collection("teams")
      .get();

    // Current points (after the change). Team display names now come from
    // the guide-typed `name` field on each team doc, not a hard-coded map.
    const currentTeams = [];
    teamsSnapshot.forEach((doc) => {
      currentTeams.push({
        id: doc.id,
        name: doc.data().name || doc.id,
        points: doc.data().points || 0,
      });
    });

    // Compute old points (before this change)
    const oldTeams = currentTeams.map((t) => ({
      id: t.id,
      points: t.id === changedTeam ? t.points - amount : t.points,
    }));

    // Sort by points descending for rankings
    const sortDesc = (a, b) => b.points - a.points;
    const oldRanked = [...oldTeams].sort(sortDesc);
    const newRanked = [...currentTeams].sort(sortDesc);

    const oldRankMap = {};
    oldRanked.forEach((t, i) => (oldRankMap[t.id] = i + 1));
    const newRankMap = {};
    newRanked.forEach((t, i) => (newRankMap[t.id] = i + 1));

    const messages = [];

    // 1. Points notification to the affected team only
    const changed = currentTeams.find((t) => t.id === changedTeam);
    const teamDisplayName = changed ? changed.name : changedTeam;
    const absAmount = Math.abs(amount);
    const title = amount > 0 ? l.pointsAdded : l.pointsRemoved;
    let body = amount > 0
      ? l.teamGotPoints
          .replace("{team}", teamDisplayName)
          .replace("{points}", absAmount.toString())
      : l.teamLostPoints
          .replace("{team}", teamDisplayName)
          .replace("{points}", absAmount.toString());

    if (data.reason) {
      body += " — " + l.reason.replace("{reason}", data.reason);
    }

    messages.push({
      topic: `camp_${campId}_team_${changedTeam}`,
      notification: { title, body },
      data: { type: "points", campId, team: changedTeam },
      android: {
        notification: { channelId: "announcements", priority: "default" },
      },
    });

    // 2. Rank change notifications for any team whose rank changed
    for (const team of currentTeams) {
      const oldRank = oldRankMap[team.id];
      const newRank = newRankMap[team.id];
      if (oldRank !== newRank && team.id !== changedTeam) {
        const rankTitle = newRank < oldRank ? l.rankUp : l.rankDown;
        const rankBody = (newRank < oldRank ? l.rankUpBody : l.rankDownBody)
          .replace("{team}", team.name)
          .replace("{rank}", newRank.toString());

        messages.push({
          topic: `camp_${campId}_team_${team.id}`,
          notification: { title: rankTitle, body: rankBody },
          data: { type: "points", campId, team: team.id },
          android: {
            notification: { channelId: "announcements", priority: "default" },
          },
        });
      }
    }

    // Send all notifications
    for (const msg of messages) {
      try {
        await getMessaging().send(msg);
        console.log(`Notification sent to topic: ${msg.topic}`);
      } catch (error) {
        console.error(`Error sending to ${msg.topic}:`, error);
      }
    }
  }
);

/**
 * Registers a guide server-side and attaches them to an organisation:
 *  - newOrgName set  -> creates a new org (caller becomes owner) with a fresh invite code
 *  - joinOrgCode set -> joins the org whose inviteCode matches
 * Creates the Auth user, the users/{uid} profile, the org membership, and sets
 * custom claims { role: 'guide', orgId } BEFORE returning, so the client's
 * first sign-in token already carries them.
 */
exports.registerGuide = onCall({ enforceAppCheck: true }, async (request) => {
  const { email, password, displayName, newOrgName, joinOrgCode } =
    request.data || {};
  if (!email || !password || !displayName || (!newOrgName && !joinOrgCode)) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const db = getFirestore();

  // Resolve or create the organisation FIRST (fail before creating the user).
  let orgId;
  let pendingOrg;
  if (newOrgName) {
    // Unique invite code.
    let code;
    let clash;
    do {
      code = generateOrgInviteCode();
      clash = await db.collection("organizations")
        .where("inviteCode", "==", code).limit(1).get();
    } while (!clash.empty);
    const orgRef = db.collection("organizations").doc();
    orgId = orgRef.id;
    // Org + owner membership are written after the user exists (below).
    pendingOrg = { orgRef, name: newOrgName.trim(), inviteCode: code };
  } else {
    const match = await db.collection("organizations")
      .where("inviteCode", "==", joinOrgCode.trim().toUpperCase())
      .limit(1).get();
    if (match.empty) {
      throw new HttpsError("permission-denied", "invalid-invite-code");
    }
    orgId = match.docs[0].id;
  }

  let userRecord;
  try {
    userRecord = await getAuth().createUser({ email, password, displayName });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "email-already-in-use");
    }
    if (e.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "weak-password");
    }
    throw new HttpsError("internal", "auth-create-failed");
  }
  const uid = userRecord.uid;

  const batch = db.batch();
  if (pendingOrg) {
    batch.set(pendingOrg.orgRef, {
      name: pendingOrg.name,
      ownerUid: uid,
      inviteCode: pendingOrg.inviteCode,
    });
    batch.set(pendingOrg.orgRef.collection("members").doc(uid), {
      role: "owner",
      displayName: displayName,
    });
  } else {
    batch.set(
      db.doc(`organizations/${orgId}/members/${uid}`),
      { role: "guide", displayName: displayName });
  }
  batch.set(db.doc(`users/${uid}`), {
    role: "guide",
    email: email,
    displayName: displayName,
    orgId: orgId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  // Claims BEFORE the client signs in -> first token already carries them.
  await getAuth().setCustomUserClaims(uid, { role: "guide", orgId: orgId });

  return { ok: true, orgId: orgId };
});

/**
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp not ended. Creates the kid profile
 * server-side. Returns { campId, team, displayName }.
 *
 * Codes live in a top-level `codes/{code}` collection (Phase 5), so this is a
 * single get() instead of a collection-group scan.
 */
exports.claimCampCode = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const code = ((request.data && request.data.code) || "").trim().toUpperCase();
  if (!/^CAMP-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const db = getFirestore();
  const codeRef = db.doc(`codes/${code}`);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists) throw new HttpsError("not-found", "invalid-code");
    const d = snap.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    const campSnap = await tx.get(db.doc(`camps/${d.campId}`));
    if (campSnap.exists) {
      const end = campSnap.data().endDate;
      if (end && end.toDate && end.toDate() < new Date()) {
        throw new HttpsError("failed-precondition", "session-expired");
      }
    }

    tx.update(codeRef, { used: true, usedBy: uid });
    tx.set(db.doc(`users/${uid}`), {
      role: "kid",
      displayName: d.displayName || "Campist",
      campId: d.campId,
      orgId: d.orgId,
      team: d.team,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      campId: d.campId,
      team: d.team,
      displayName: d.displayName || "Campist",
    };
  });
});

/**
 * Scheduled server-side cleanup: any camp whose endDate is more than 60 days
 * in the past is fully removed (subcollections via recursiveDelete, plus its
 * top-level codes). Replaces the Phase-1..4 client-side cleanupExpiredSessions.
 */
exports.cleanupExpiredCamps = onSchedule("every 24 hours", async () => {
  const db = getFirestore();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 60);
  const expired = await db.collection("camps")
    .where("endDate", "<", cutoff).get();
  for (const camp of expired.docs) {
    // recursiveDelete clears all subcollections (teams, announcements, ...).
    await db.recursiveDelete(camp.ref);
    const codes = await db.collection("codes")
      .where("campId", "==", camp.id).get();
    const batch = db.batch();
    codes.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
});

/**
 * Lets a signed-in guide delete their own account and, if they own the
 * organisation, its entire org (camps, top-level codes, locations, members).
 * A non-owner guide is just removed from the org's membership. Required by
 * Apple (in-app account deletion) and 2026 consent-revocation rules.
 */
exports.deleteMyAccount = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid;
  const db = getFirestore();

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;

  // Free any camp code this user claimed so it can be re-issued. (Kids claim a
  // code via claimCampCode, which stamps used/usedBy; deleting the account must
  // release it.)
  const claimed = await db.collection("codes").where("usedBy", "==", uid).get();
  if (!claimed.empty) {
    const batch = db.batch();
    claimed.forEach((d) =>
      batch.update(d.ref, { used: false, usedBy: FieldValue.delete() }));
    await batch.commit();
  }

  if (user && user.role === "guide" && user.orgId) {
    const org = await db.doc(`organizations/${user.orgId}`).get();
    if (org.exists && org.data().ownerUid === uid) {
      // Owner: delete the whole org — camps (+ subcollections), their
      // top-level codes, and the org doc itself (locations, members).
      const camps = await db.collection("camps")
        .where("orgId", "==", user.orgId).get();
      for (const camp of camps.docs) {
        await db.recursiveDelete(camp.ref);
        const codes = await db.collection("codes")
          .where("campId", "==", camp.id).get();
        const batch = db.batch();
        codes.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
      await db.recursiveDelete(org.ref);
    } else {
      // Non-owner guide: just remove membership.
      await db.doc(`organizations/${user.orgId}/members/${uid}`).delete().catch(() => {});
    }
  }

  await db.doc(`users/${uid}`).delete().catch(() => {});
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
