const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

initializeApp();

/**
 * Get the camp's language setting from the guide who created the content.
 * Falls back to 'ro' (Romanian) if not found.
 */
async function getCampLanguage(createdByUid) {
  if (!createdByUid) return "ro";
  try {
    const userDoc = await getFirestore()
      .collection("users")
      .doc(createdByUid)
      .get();
    // We don't store language per user in Firestore, so default to 'ro'
    return "ro";
  } catch {
    return "ro";
  }
}

// Localized strings for notifications
const strings = {
  ro: {
    newAnnouncement: "Anunt nou",
    emergencyTitle: "ALERTA DE URGENTA",
    pointsAdded: "Puncte adaugate",
    pointsRemoved: "Puncte scazute",
    teamGotPoints: "{team} a primit {points} puncte",
    teamLostPoints: "{team} a pierdut {points} puncte",
    reason: "Motiv: {reason}",
    rankUp: "Echipa ta a urcat!",
    rankDown: "Echipa ta a coborat",
    rankUpBody: "{team} este acum pe locul {rank}!",
    rankDownBody: "{team} a coborat pe locul {rank}",
  },
  hu: {
    newAnnouncement: "Uj kozlemeny",
    emergencyTitle: "VESZHELYZETI RIASZTAS",
    pointsAdded: "Pontok hozzaadva",
    pointsRemoved: "Pontok levonva",
    teamGotPoints: "{team} kapott {points} pontot",
    teamLostPoints: "{team} veszitett {points} pontot",
    reason: "Ok: {reason}",
    rankUp: "A csapatod feljebb lepett!",
    rankDown: "A csapatod lejjebb csuszott",
    rankUpBody: "{team} most a {rank}. helyen all!",
    rankDownBody: "{team} a {rank}. helyre csuszott",
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
            "interruption-level": "critical",
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
 * Registers a guide entirely server-side: validates the invite code (which is
 * never exposed to clients), creates the Auth user, and writes the profile doc
 * with role 'guide'. Clients can NEVER write a role themselves (rules deny it),
 * which closes the self-escalation hole.
 */
exports.registerGuide = onCall(async (request) => {
  const { email, password, displayName, inviteCode } = request.data || {};
  if (!email || !password || !displayName || !inviteCode) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const cfg = await getFirestore().doc("config/app").get();
  const expected = cfg.exists ? cfg.data().guideInviteCode : null;
  if (!expected || expected !== inviteCode) {
    throw new HttpsError("permission-denied", "invalid-invite-code");
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

  await getFirestore().doc(`users/${userRecord.uid}`).set({
    role: "guide",
    email: email,
    displayName: displayName,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

/**
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp not ended. Creates the kid profile
 * server-side. Returns { campId, team, displayName }.
 *
 * INTERIM (Phase 2): the code is located by scanning the 'codes' collection
 * group, O(total codes). Phase 5 replaces this with a single get() on a
 * top-level codes/{code} document. Do not optimize here.
 */
exports.claimCampCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const code = ((request.data && request.data.code) || "").trim().toUpperCase();
  if (!/^CAMP-[A-Z0-9]{4}$/.test(code)) {
    throw new HttpsError("invalid-argument", "invalid-code");
  }

  const db = getFirestore();

  // Locate the code doc across all camps (doc id == the code string).
  let codeRef = null;
  let campId = null;
  const cg = await db.collectionGroup("codes").get();
  cg.forEach((doc) => {
    if (doc.id === code) {
      codeRef = doc.ref;
      campId = doc.ref.parent.parent.id;
    }
  });
  if (!codeRef) {
    throw new HttpsError("not-found", "invalid-code");
  }

  const campSnap = await db.doc(`camps/${campId}`).get();
  if (campSnap.exists) {
    const endDate = campSnap.data().endDate;
    if (endDate && endDate.toDate && endDate.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "session-expired");
    }
  }

  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(codeRef);
    if (!fresh.exists) throw new HttpsError("not-found", "invalid-code");
    const d = fresh.data();
    if (d.used) throw new HttpsError("already-exists", "code-used");

    tx.update(codeRef, { used: true, usedBy: uid });
    tx.set(db.doc(`users/${uid}`), {
      role: "kid",
      displayName: d.displayName || "Campist",
      campId: campId,
      team: d.team,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { campId: campId, team: d.team, displayName: d.displayName || "Campist" };
  });
});
