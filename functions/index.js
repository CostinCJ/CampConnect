const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

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

// Team color display names
const teamNames = {
  ro: {
    red: "Rosu", blue: "Albastru", green: "Verde", yellow: "Galben",
    orange: "Portocaliu", purple: "Mov", pink: "Roz", teal: "Turcoaz",
  },
  hu: {
    red: "Piros", blue: "Kek", green: "Zold", yellow: "Sarga",
    orange: "Narancs", purple: "Lila", pink: "Roz", teal: "Turkiz",
  },
};

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
    const tn = teamNames[lang] || teamNames["ro"];

    // Read all teams for rank comparison
    const teamsSnapshot = await getFirestore()
      .collection("camps")
      .doc(campId)
      .collection("teams")
      .get();

    // Current points (after the change)
    const currentTeams = [];
    teamsSnapshot.forEach((doc) => {
      currentTeams.push({ color: doc.id, points: doc.data().points || 0 });
    });

    // Compute old points (before this change)
    const oldTeams = currentTeams.map((t) => ({
      color: t.color,
      points: t.color === changedTeam ? t.points - amount : t.points,
    }));

    // Sort by points descending for rankings
    const sortDesc = (a, b) => b.points - a.points;
    const oldRanked = [...oldTeams].sort(sortDesc);
    const newRanked = [...currentTeams].sort(sortDesc);

    const oldRankMap = {};
    oldRanked.forEach((t, i) => (oldRankMap[t.color] = i + 1));
    const newRankMap = {};
    newRanked.forEach((t, i) => (newRankMap[t.color] = i + 1));

    const messages = [];

    // 1. Points notification to the affected team only
    const teamDisplayName = tn[changedTeam] || changedTeam;
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
      const oldRank = oldRankMap[team.color];
      const newRank = newRankMap[team.color];
      if (oldRank !== newRank && team.color !== changedTeam) {
        const tName = tn[team.color] || team.color;
        const rankTitle = newRank < oldRank ? l.rankUp : l.rankDown;
        const rankBody = (newRank < oldRank ? l.rankUpBody : l.rankDownBody)
          .replace("{team}", tName)
          .replace("{rank}", newRank.toString());

        messages.push({
          topic: `camp_${campId}_team_${team.color}`,
          notification: { title: rankTitle, body: rankBody },
          data: { type: "points", campId, team: team.color },
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
