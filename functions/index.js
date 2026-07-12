const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const logger = require("firebase-functions/logger");
const { registerGuideHandler } = require("./lib/registerGuide");
const { claimCampCodeHandler } = require("./lib/claimCampCode");
const { cleanupExpiredCampsHandler } = require("./lib/cleanupExpiredCamps");
const { deleteMyAccountHandler } = require("./lib/deleteMyAccount");
const { deleteCampHandler } = require("./lib/deleteCamp");
const { getOrganizationLogoUrlHandler } = require("./lib/getOrganizationLogoUrl");
const { removeMemberHandler, rotateInviteCodeHandler, joinOrganizationHandler } = require("./lib/orgManagement");
const { deleteTeamHandler } = require("./lib/teamManagement");

// The project's Firestore/Storage location is eur3 (EU multi-region);
// europe-west1 is Google's documented nearest Cloud Functions region for
// eur3, so all data processing here stays in the EU rather than round-
// tripping through us-central1 (the Cloud Functions default).
setGlobalOptions({ region: "europe-west1" });

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
      logger.info("Skipping notification for schedule entry");
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
      logger.info("Could not read camp language, defaulting to ro");
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
      logger.info("Announcement notification sent to topic", { topic });
    } catch (error) {
      logger.error("Error sending announcement notification", { error: error.message, stack: error.stack });
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
      logger.info("Could not read camp language, defaulting to ro");
    }

    const l = getStrings(lang);
    const topic = `camp_${campId}_guides`;

    const message = {
      topic: topic,
      notification: {
        title: l.emergencyTitle,
        body: data.message || "",
      },
      // No senderName here: the client reads it from the rules-protected
      // Firestore alert doc, not the push. Keeping personal data out of the
      // (public-topic) FCM payload limits what a topic subscriber can learn.
      // Likewise no latitude/longitude: coordinates stay in the
      // rules-protected alert doc, never in a (public) push payload.
      data: {
        type: "emergency",
        campId: campId,
        alertId: event.params.alertId,
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
      logger.info("Emergency notification sent to topic", { topic });
    } catch (error) {
      logger.error("Error sending emergency notification", { error: error.message, stack: error.stack });
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
      logger.info("Could not read camp language, defaulting to ro");
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
      body += ". " + l.reason.replace("{reason}", data.reason);
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
        logger.info("Notification sent to topic", { topic: msg.topic });
      } catch (error) {
        logger.error("Error sending to topic", { topic: msg.topic, error: error.message, stack: error.stack });
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
exports.registerGuide = onCall((request) => {
  const callerIp = (request.rawRequest && request.rawRequest.ip) || "unknown";
  return registerGuideHandler(getFirestore(), getAuth(), request.data, callerIp);
});

/**
 * Atomically claims a camp code for the calling (already anonymously signed-in)
 * kid. Enforces: code exists, not used, camp not ended. Creates the kid profile
 * server-side. Returns { campId, team, displayName }.
 *
 * Codes live in a top-level `codes/{code}` collection (Phase 5), so this is a
 * single get() instead of a collection-group scan.
 */
exports.claimCampCode = onCall((request) => {
  const callerIp = (request.rawRequest && request.rawRequest.ip) || "unknown";
  return claimCampCodeHandler(
    getFirestore(), request.auth, request.data, callerIp);
});

/**
 * Scheduled server-side cleanup: any camp whose endDate is more than 60 days
 * in the past is fully removed (subcollections via recursiveDelete, plus its
 * top-level codes). Replaces the Phase-1..4 client-side cleanupExpiredSessions.
 */
exports.cleanupExpiredCamps = onSchedule(
  { schedule: "every 24 hours", timeoutSeconds: 540, retryCount: 3 },
  () => cleanupExpiredCampsHandler(getFirestore(), getStorage().bucket())
);

/**
 * Lets a signed-in guide delete their own account and, if they own the
 * organisation, its entire org (camps, top-level codes, locations, members).
 * A non-owner guide is just removed from the org's membership. Required by
 * Apple (in-app account deletion) and 2026 consent-revocation rules.
 */
exports.deleteMyAccount = onCall((request) =>
  deleteMyAccountHandler(getFirestore(), getAuth(), request.auth, getStorage().bucket())
);

/**
 * Deletes a single camp on demand for a guide of the camp's own org, cascading
 * to its Storage photos, all Firestore subcollections, and its top-level codes
 * (via the shared deleteCampCascade). Replaces the old client-side
 * CampRepository.deleteCampSession, which orphaned both the real top-level
 * codes and every Storage photo.
 */
exports.deleteCamp = onCall((request) =>
  deleteCampHandler(getFirestore(), request.auth, request.data, getStorage().bucket())
);

/**
 * Owner-only org management (see lib/orgManagement.js): remove a guide from
 * the caller's org / rotate the org's invite code. Client writes to
 * organizations/** remain denied by rules; these are the only mutation paths.
 */
exports.removeMember = onCall((request) =>
  removeMemberHandler(getFirestore(), getAuth(), request.auth, request.data)
);

exports.rotateInviteCode = onCall((request) =>
  rotateInviteCodeHandler(getFirestore(), request.auth)
);

/**
 * Lets a signed-in guide who belongs to no organisation (e.g. after being
 * removed via removeMember) join one with its invite code. The re-join
 * counterpart of registerGuide's joinOrgCode branch for existing accounts.
 */
exports.joinOrganization = onCall((request) =>
  joinOrganizationHandler(getFirestore(), getAuth(), request.auth, request.data)
);

/**
 * Returns only the caller's org logo URL. Used by kid journal PDF export
 * without granting kids direct read access to the org document.
 */
exports.getOrganizationLogoUrl = onCall((request) =>
  getOrganizationLogoUrlHandler(getFirestore(), request.auth)
);

/**
 * Deletes a camp team, reassigning its kids first if any are still on it (see
 * lib/teamManagement.js). Firestore rules only let a client read its own
 * users/{uid} doc, so the "any kids still on this team?" check — a
 * cross-user query — has to run here on the Admin SDK; it's the only path
 * that can check it at all.
 */
exports.deleteTeam = onCall((request) =>
  deleteTeamHandler(getFirestore(), request.auth, request.data)
);
