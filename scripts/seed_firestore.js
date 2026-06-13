/* eslint-disable no-console */
/**
 * CampConnect seed script.
 *
 * Adds master locations (shared across camps), one currently-active camp
 * ("Apuseni Summer Camp 2026") and one archived camp from last summer
 * ("Apuseni Summer Camp 2025") to Firestore.
 *
 * Does NOT touch existing data. Every document uses a deterministic
 * `seed-*` ID, so re-running the script overwrites only the seeded docs
 * and leaves everything else (other camps, other master locations, your
 * guide account) alone.
 *
 *
 * USAGE
 *   1. cd D:\CampConnect\scripts
 *   2. npm install
 *   3. gcloud auth application-default login
 *      (one-time; produces an ADC file the script reads automatically)
 *   4. node seed_firestore.js
 *
 * To wipe just the seeded data later:
 *   node seed_firestore.js --wipe
 */

const admin = require("firebase-admin");

// ---------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------

const PROJECT_ID = "camp-connect-4644c";
const GUIDE_UID = "NwhdJOVIL2eZnkQaWPraO4rsU5s2";
const GUIDE_NAME = "CostinCristian";

const TEAMS = ["red", "blue", "green", "yellow"];

// ---------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const WIPE = process.argv.includes("--wipe");

// ---------------------------------------------------------------------
// Master locations (the `locations/` global registry)
// All four POIs sit in the Alba / Bihor part of the Apuseni Mountains.
// Coordinates are taken from public references and Wikipedia.
//
// Photo URLs are stable Wikimedia Commons thumbnails (CC BY-SA).
// CachedNetworkImage in the app handles any HTTPS URL, so no Firebase
// Storage upload is required.
// ---------------------------------------------------------------------

const LOCATIONS = [
  {
    id: "seed-scarisoara-ice-cave",
    name: "Scarisoara Ice Cave",
    latitude: 46.4900,
    longitude: 22.8125,
    category: "nature",
    photoUrl:
      "https://upload.wikimedia.org/wikipedia/commons/f/f1/Pestera_Scarisoara_-_Sala_Biserica.jpg",
    description:
      "An underground ice cave in the Apuseni Mountains, holding one of the largest compact underground glaciers in the world.",
    knowledgeBase: {
      description:
        "Scarisoara Ice Cave is a glacier cave near the village of Ghetari, in Garda de Sus commune, Alba County. It sits at about 1150 meters altitude inside the Apuseni Natural Park and is one of the most famous natural monuments in Romania. Visitors descend into a giant shaft and reach the Great Hall, where the ice block first comes into view, then continue into smaller chambers full of ice stalagmites.",
      facts:
        "The ice block has an estimated volume of around 75000 cubic meters, with thicknesses of up to 20 meters in some places. The cave is roughly 720 meters long and 120 meters deep. The lower layers of the glacier are more than 10000 years old. The temperature inside stays between -7 degrees Celsius in winter and about +1 degree Celsius in summer. From the Great Hall, passages lead to named rooms such as the Church, which contains over 100 ice stalagmites.",
      funFact:
        "The cave is home to a tiny insect called Pholeuon prozerpinae glaciale, only 2 to 3 millimeters long, that lives nowhere else on Earth except in this ice cave and a few neighbouring caves.",
    },
  },
  {
    id: "seed-varciorog-waterfall",
    name: "Varciorog Waterfall",
    latitude: 46.4858,
    longitude: 22.6500,
    category: "nature",
    photoUrl:
      "https://upload.wikimedia.org/wikipedia/commons/7/7c/Stropi%2CV%C3%A2rciorog_-_panoramio.jpg",
    description:
      "A 15 meter two-step waterfall on the Varciorog stream, hidden inside a fir forest at the foot of Piatra Graitoare.",
    knowledgeBase: {
      description:
        "Varciorog Waterfall is one of the best known waterfalls in the Apuseni Mountains. It is located near the village of Vanvucesti, in Arieseni commune, Alba County, at the foot of Mount Piatra Graitoare. The waterfall has been protected as a geological and landscape reserve since the year 2000, covering five hectares of fir forest around the cascade.",
      facts:
        "The waterfall is about 15 meters high and falls in two stages over mossy rock. It is fed by the Varciorog stream, a right tributary of the Aries River. To reach it, hikers walk a forest trail of about 3 to 3.5 kilometers from the main road DN75. The path is gentle enough for small children, and during the tourist season horse-drawn carts often carry visitors along part of it.",
      funFact:
        "Spring and early summer are the best times to visit, because the snowmelt doubles the water flow and the cascade looks roughly twice as powerful as in late summer.",
    },
  },
  {
    id: "seed-groapa-ruginoasa",
    name: "Groapa Ruginoasa",
    latitude: 46.5263,
    longitude: 22.6522,
    category: "nature",
    photoUrl:
      "https://upload.wikimedia.org/wikipedia/commons/2/25/Ruginoasa_pit_natural_erosion.jpg",
    description:
      "A giant rust-colored ravine in the Apuseni Natural Park, often called the Red Pit because of the iron-rich sandstone walls.",
    knowledgeBase: {
      description:
        "Groapa Ruginoasa, which translates as the Rusty Pit, is a protected geological reserve in Pietroasa commune, Bihor County, inside the Apuseni Natural Park. It is a huge ravine carved into Permian and Lower Triassic sediments, whose iron-rich sandstones, conglomerates and clays give the slopes their yellow to deep red color.",
      facts:
        "The ravine is more than 600 meters wide and around 100 meters deep, covering about 20 hectares. Geologists estimate that around 7 million cubic meters of rock have been eroded out of it. It was shaped by headward erosion of a small intermittent stream in the Valea Seaca, the Dry Valley, and is still actively growing every year.",
      funFact:
        "Comparisons between 19th century maps and today show that Groapa Ruginoasa has visibly grown larger over the past century, which means visitors are looking at a landform that is still being sculpted in real time.",
    },
  },
  {
    id: "seed-avram-iancu-museum",
    name: "Avram Iancu Memorial Museum",
    latitude: 46.3486,
    longitude: 22.9133,
    category: "historical",
    photoUrl:
      "https://upload.wikimedia.org/wikipedia/commons/9/94/Casa_craisorului_Avram_Iancu.JPG",
    description:
      "The memorial house of Avram Iancu, a leader of the 1848 Transylvanian Revolution, set up in his family home in the Apuseni village of Vidra.",
    knowledgeBase: {
      description:
        "The Avram Iancu Memorial Museum is housed in the family home of Avram Iancu (1824-1872), a Romanian lawyer and one of the leaders of the 1848-1849 Revolution in Transylvania. It is located in the village of Incesti, part of Vidra commune in Alba County, in the heart of the Moti Country region of the Apuseni Mountains.",
      facts:
        "The house was built by Avram Iancu's parents, Alexandru and Maria, around the year 1800. It is a typical Moti dwelling: a lower level of river stone bound with clay and an upper level of fir-tree beams, plastered with yellow earth and wheat straw, finished with a steep roof of four semicircular arches. The museum was inaugurated in 1924 by the ASTRA Association from Sibiu and was visited by the Romanian royal family soon after.",
      funFact:
        "The exhibition is split into four sections, including the ethnographic family rooms, the revolution gallery, and the cellar with everyday Moti objects. Two swords that once belonged to Avram Iancu himself are on display in the historical section.",
    },
  },
];

// ---------------------------------------------------------------------
// Camp 1: ACTIVE — current run, ~mid May 2026
// ---------------------------------------------------------------------

const ACTIVE_CAMP = {
  id: "seed-apuseni-summer-2026",
  name: "Apuseni Summer Camp 2026",
  startDate: new Date("2026-05-10T08:00:00Z"),
  endDate: new Date("2026-05-24T18:00:00Z"),
  language: "en",
  teamPoints: { red: 120, blue: 105, green: 135, yellow: 70 },
  pointsHistory: [
    { team: "green", amount: 30, reason: "Won the morning orienteering race", whenDaysAgo: 4 },
    { team: "blue", amount: 25, reason: "Best campfire song performance", whenDaysAgo: 4 },
    { team: "red", amount: 25, reason: "Best campfire song performance", whenDaysAgo: 4 },
    { team: "yellow", amount: 20, reason: "Helped clean the dining hall after lunch", whenDaysAgo: 3 },
    { team: "green", amount: 35, reason: "First team back from the Scarisoara hike", whenDaysAgo: 3 },
    { team: "red", amount: 40, reason: "Won the team relay at the lake", whenDaysAgo: 3 },
    { team: "blue", amount: 30, reason: "Best presentation about the Varciorog Waterfall trail", whenDaysAgo: 2 },
    { team: "yellow", amount: 25, reason: "Excellent teamwork during the museum visit", whenDaysAgo: 2 },
    { team: "red", amount: 30, reason: "First place in the evening quiz", whenDaysAgo: 1 },
    { team: "green", amount: 50, reason: "Outstanding behaviour during the Groapa Ruginoasa trip", whenDaysAgo: 1 },
    { team: "blue", amount: 25, reason: "Helped a younger team finish their craft project", whenDaysAgo: 1 },
    { team: "yellow", amount: 25, reason: "Best decorated cabin inspection", whenDaysAgo: 0 },
    { team: "green", amount: 20, reason: "Volunteered to lead the morning warm-up", whenDaysAgo: 0 },
    { team: "blue", amount: 25, reason: "Won the trivia round at the camp meeting", whenDaysAgo: 0 },
    { team: "red", amount: 25, reason: "Helped guides set up the obstacle course", whenDaysAgo: 0 },
  ],
  codes: [
    { code: "CAMP-R7K2", team: "red", displayName: "Camper R1", used: true, fakeKidUid: "seed-kid-red-1" },
    { code: "CAMP-R9XP", team: "red", displayName: "Camper R2", used: false },
    { code: "CAMP-B4M3", team: "blue", displayName: "Camper B1", used: true, fakeKidUid: "seed-kid-blue-1" },
    { code: "CAMP-B8VN", team: "blue", displayName: "Camper B2", used: false },
    { code: "CAMP-G2QH", team: "green", displayName: "Camper G1", used: true, fakeKidUid: "seed-kid-green-1" },
    { code: "CAMP-G6TS", team: "green", displayName: "Camper G2", used: false },
    { code: "CAMP-Y5LK", team: "yellow", displayName: "Camper Y1", used: true, fakeKidUid: "seed-kid-yellow-1" },
    { code: "CAMP-Y3WJ", team: "yellow", displayName: "Camper Y2", used: false },
  ],
  // Which master locations are published to this camp's map, in display order.
  sessionLocationIds: [
    "seed-scarisoara-ice-cave",
    "seed-varciorog-waterfall",
    "seed-groapa-ruginoasa",
    "seed-avram-iancu-museum",
  ],
  announcements: [
    {
      id: "seed-ann-2026-welcome",
      title: "Welcome to Apuseni Summer Camp 2026",
      body: "Welcome everyone. Please check the schedule in the announcements tab each morning. Remember to refill your water bottle before every hike.",
      type: "announcement",
      pinned: true,
      whenDaysAgo: 4,
    },
    {
      id: "seed-ann-2026-schedule-scarisoara",
      title: "Trip: Scarisoara Ice Cave",
      body: "Bring a jacket, sturdy shoes and a small backpack with water. The cave is cold even in summer.",
      type: "schedule",
      pinned: false,
      whenDaysAgo: 3,
      startTime: "09:00",
      endTime: "15:00",
      scheduledDaysFromNow: -3,
    },
    {
      id: "seed-ann-2026-schedule-varciorog",
      title: "Trip: Varciorog Waterfall",
      body: "Easy 3 km forest walk. Wear comfortable shoes, the path can be slippery after rain.",
      type: "schedule",
      pinned: false,
      whenDaysAgo: 2,
      startTime: "10:00",
      endTime: "14:00",
      scheduledDaysFromNow: -2,
    },
    {
      id: "seed-ann-2026-rules",
      title: "Camp rules reminder",
      body: "Quiet hours start at 22:00. Please stay inside your cabin after lights out. Guides are available all night in case of an emergency.",
      type: "announcement",
      pinned: false,
      whenDaysAgo: 2,
    },
    {
      id: "seed-ann-2026-schedule-museum",
      title: "Trip: Avram Iancu Memorial Museum",
      body: "Half-day visit in Vidra. Please be ready at the bus by 09:30. Bring a notebook for the guided tour.",
      type: "schedule",
      pinned: false,
      whenDaysAgo: 1,
      startTime: "09:30",
      endTime: "13:00",
      scheduledDaysFromNow: 1,
    },
    {
      id: "seed-ann-2026-campfire",
      title: "Campfire tonight",
      body: "Meet at the main fire pit at 20:30. Each team will perform one song. Marshmallows provided by the kitchen team.",
      type: "schedule",
      pinned: true,
      whenDaysAgo: 0,
      startTime: "20:30",
      endTime: "22:00",
      scheduledDaysFromNow: 0,
    },
  ],
};

// ---------------------------------------------------------------------
// Camp 2: ARCHIVED — finished summer of 2025
// All codes consumed, dates fully in the past, smaller announcement set.
// ---------------------------------------------------------------------

const ARCHIVED_CAMP = {
  id: "seed-apuseni-summer-2025",
  name: "Apuseni Summer Camp 2025",
  startDate: new Date("2025-08-04T08:00:00Z"),
  endDate: new Date("2025-08-17T18:00:00Z"),
  language: "en",
  teamPoints: { red: 215, blue: 240, green: 190, yellow: 175 },
  pointsHistory: [
    { team: "blue", amount: 40, reason: "Won the camp-wide treasure hunt", whenDaysAgo: 285 },
    { team: "red", amount: 35, reason: "First team to summit Piatra Graitoare", whenDaysAgo: 284 },
    { team: "green", amount: 30, reason: "Best ethnographic skit at the Avram Iancu visit", whenDaysAgo: 283 },
    { team: "yellow", amount: 30, reason: "Cleanest cabin inspection of the week", whenDaysAgo: 283 },
    { team: "blue", amount: 35, reason: "First place in the kayak race", whenDaysAgo: 281 },
    { team: "red", amount: 45, reason: "Best Scarisoara Cave photo project", whenDaysAgo: 280 },
    { team: "green", amount: 25, reason: "Helped guides repair the trail signs", whenDaysAgo: 279 },
    { team: "yellow", amount: 40, reason: "Outstanding teamwork during the night hike", whenDaysAgo: 278 },
    { team: "blue", amount: 50, reason: "Closing ceremony winners", whenDaysAgo: 277 },
    { team: "red", amount: 50, reason: "Best overall behaviour of the camp", whenDaysAgo: 277 },
    { team: "green", amount: 60, reason: "Closing ceremony runners-up", whenDaysAgo: 277 },
    { team: "yellow", amount: 35, reason: "Most improved team of the camp", whenDaysAgo: 277 },
    { team: "red", amount: 40, reason: "Group-photo contribution to the camp album", whenDaysAgo: 277 },
    { team: "blue", amount: 50, reason: "Won the final trivia about the Apuseni POIs", whenDaysAgo: 277 },
    { team: "green", amount: 35, reason: "Best Groapa Ruginoasa sketchbook", whenDaysAgo: 277 },
    { team: "yellow", amount: 35, reason: "Helped run the final campfire", whenDaysAgo: 277 },
    { team: "red", amount: 45, reason: "Best end-of-camp presentation", whenDaysAgo: 277 },
    { team: "blue", amount: 65, reason: "Top scorer of the season — winning team", whenDaysAgo: 277 },
    { team: "green", amount: 40, reason: "Top hiking distance of the camp", whenDaysAgo: 277 },
    { team: "yellow", amount: 35, reason: "Best journal entries submitted", whenDaysAgo: 277 },
  ],
  codes: [
    { code: "CAMP-R5HN", team: "red", displayName: "Camper R1", used: true, fakeKidUid: "seed-2025-kid-red-1" },
    { code: "CAMP-R8JM", team: "red", displayName: "Camper R2", used: true, fakeKidUid: "seed-2025-kid-red-2" },
    { code: "CAMP-B2VK", team: "blue", displayName: "Camper B1", used: true, fakeKidUid: "seed-2025-kid-blue-1" },
    { code: "CAMP-B6TQ", team: "blue", displayName: "Camper B2", used: true, fakeKidUid: "seed-2025-kid-blue-2" },
    { code: "CAMP-G4DP", team: "green", displayName: "Camper G1", used: true, fakeKidUid: "seed-2025-kid-green-1" },
    { code: "CAMP-G7WX", team: "green", displayName: "Camper G2", used: true, fakeKidUid: "seed-2025-kid-green-2" },
    { code: "CAMP-Y3FL", team: "yellow", displayName: "Camper Y1", used: true, fakeKidUid: "seed-2025-kid-yellow-1" },
    { code: "CAMP-Y9ZB", team: "yellow", displayName: "Camper Y2", used: true, fakeKidUid: "seed-2025-kid-yellow-2" },
  ],
  sessionLocationIds: [
    "seed-scarisoara-ice-cave",
    "seed-varciorog-waterfall",
    "seed-avram-iancu-museum",
  ],
  announcements: [
    {
      id: "seed-ann-2025-welcome",
      title: "Welcome to Apuseni Summer Camp 2025",
      body: "Welcome to our 2025 edition. Two weeks of hikes, games and stories ahead.",
      type: "announcement",
      pinned: false,
      whenDaysAgo: 285,
    },
    {
      id: "seed-ann-2025-schedule-scarisoara",
      title: "Trip: Scarisoara Ice Cave",
      body: "Pack warm clothes, the cave temperature stays near zero year-round.",
      type: "schedule",
      pinned: false,
      whenDaysAgo: 283,
      startTime: "09:00",
      endTime: "15:00",
      scheduledDaysFromNow: -282,
    },
    {
      id: "seed-ann-2025-closing",
      title: "Closing ceremony tonight",
      body: "Meet at the main hall at 19:00. Awards for every team. Family members are welcome.",
      type: "schedule",
      pinned: true,
      whenDaysAgo: 277,
      startTime: "19:00",
      endTime: "21:30",
      scheduledDaysFromNow: -277,
    },
    {
      id: "seed-ann-2025-thanks",
      title: "Thank you, see you next year",
      body: "Thanks to all the campers and parents for an incredible 2025 edition. See you in 2026.",
      type: "announcement",
      pinned: false,
      whenDaysAgo: 277,
    },
  ],
};

const CAMPS = [ACTIVE_CAMP, ARCHIVED_CAMP];

// ---------------------------------------------------------------------
// Consistency check: per-team sums in pointsHistory must equal teamPoints
// ---------------------------------------------------------------------

function assertCampConsistency(camp) {
  const sums = { red: 0, blue: 0, green: 0, yellow: 0 };
  for (const entry of camp.pointsHistory) sums[entry.team] += entry.amount;
  for (const team of TEAMS) {
    if (sums[team] !== camp.teamPoints[team]) {
      throw new Error(
        `Camp '${camp.id}' inconsistent: history for ${team} sums to ${sums[team]} but team total is ${camp.teamPoints[team]}`
      );
    }
  }
}

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

function tsDaysAgo(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return Timestamp.fromDate(d);
}

function tsDaysFromNow(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  d.setUTCHours(0, 0, 0, 0);
  return Timestamp.fromDate(d);
}

async function commitInChunks(label, ops, chunk = 400) {
  for (let i = 0; i < ops.length; i += chunk) {
    const batch = db.batch();
    for (const op of ops.slice(i, i + chunk)) op(batch);
    await batch.commit();
  }
  console.log(`  ${label}: ${ops.length} operations committed`);
}

// ---------------------------------------------------------------------
// Wipe (only seeded docs — leaves everything else alone)
// ---------------------------------------------------------------------

async function wipeSeeded() {
  console.log("Wiping seeded data...");

  // Master locations
  for (const loc of LOCATIONS) {
    await db.doc(`locations/${loc.id}`).delete().catch(() => {});
  }

  const subcollections = [
    "teams",
    "pointsHistory",
    "codes",
    "announcements",
    "emergencyAlerts",
    "sessionLocation",
  ];

  for (const camp of CAMPS) {
    for (const sub of subcollections) {
      const snap = await db.collection(`camps/${camp.id}/${sub}`).get();
      for (const doc of snap.docs) {
        await doc.ref.delete();
      }
    }
    await db.doc(`camps/${camp.id}`).delete().catch(() => {});
  }

  console.log("Done wiping.");
}

// ---------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------

async function seedMasterLocations() {
  console.log("Master locations:");
  await commitInChunks(
    "  locations",
    LOCATIONS.map((loc) => (batch) => {
      batch.set(db.doc(`locations/${loc.id}`), {
        name: loc.name,
        latitude: loc.latitude,
        longitude: loc.longitude,
        description: loc.description,
        category: loc.category,
        photoUrl: loc.photoUrl ?? null,
        knowledgeBase: loc.knowledgeBase,
        createdBy: GUIDE_UID,
        timestamp: FieldValue.serverTimestamp(),
      });
    })
  );
}

async function seedCamp(camp) {
  console.log(`Camp '${camp.id}' (${camp.name}):`);
  assertCampConsistency(camp);

  // Camp document
  await db.doc(`camps/${camp.id}`).set({
    name: camp.name,
    startDate: Timestamp.fromDate(camp.startDate),
    endDate: Timestamp.fromDate(camp.endDate),
    teams: TEAMS,
    createdBy: GUIDE_UID,
    language: camp.language,
  });
  console.log("  camp document: 1 written");

  // Teams
  await commitInChunks(
    "  teams",
    TEAMS.map((color) => (batch) => {
      batch.set(db.doc(`camps/${camp.id}/teams/${color}`), {
        points: camp.teamPoints[color],
      });
    })
  );

  // Points history
  await commitInChunks(
    "  pointsHistory",
    camp.pointsHistory.map((entry, i) => (batch) => {
      const id = `seed-points-${String(i).padStart(2, "0")}`;
      batch.set(db.doc(`camps/${camp.id}/pointsHistory/${id}`), {
        team: entry.team,
        amount: entry.amount,
        reason: entry.reason,
        addedBy: GUIDE_NAME,
        timestamp: tsDaysAgo(entry.whenDaysAgo),
      });
    })
  );

  // Codes
  await commitInChunks(
    "  codes",
    camp.codes.map((c) => (batch) => {
      batch.set(db.doc(`camps/${camp.id}/codes/${c.code}`), {
        team: c.team,
        displayName: c.displayName,
        used: c.used,
        usedBy: c.used ? c.fakeKidUid : null,
        createdBy: GUIDE_UID,
      });
    })
  );

  // Session locations — references the master locations seeded above.
  // visitedAt is staggered backwards so the list renders in display order.
  await commitInChunks(
    "  sessionLocation",
    camp.sessionLocationIds.map((locId, i) => (batch) => {
      const id = `seed-session-${locId}`;
      const spread = camp.sessionLocationIds.length - i - 1;
      const visitedAt =
        camp === ACTIVE_CAMP ? tsDaysAgo(spread) : tsDaysAgo(280 + spread);
      batch.set(db.doc(`camps/${camp.id}/sessionLocation/${id}`), {
        masterLocationId: locId,
        photoUrl: null,
        addedBy: GUIDE_UID,
        visitedAt,
      });
    })
  );

  // Announcements
  await commitInChunks(
    "  announcements",
    camp.announcements.map((a) => (batch) => {
      const data = {
        title: a.title,
        body: a.body,
        type: a.type,
        pinned: a.pinned,
        createdBy: GUIDE_UID,
        createdByName: GUIDE_NAME,
        timestamp: tsDaysAgo(a.whenDaysAgo),
      };
      if (a.type === "schedule") {
        data.scheduledDate = tsDaysFromNow(a.scheduledDaysFromNow ?? 0);
        if (a.startTime) data.startTime = a.startTime;
        if (a.endTime) data.endTime = a.endTime;
      }
      batch.set(db.doc(`camps/${camp.id}/announcements/${a.id}`), data);
    })
  );
}

async function seed() {
  console.log(`Seeding project ${PROJECT_ID}`);
  console.log(`  Guide:  ${GUIDE_UID}`);
  console.log("");

  await seedMasterLocations();
  for (const camp of CAMPS) {
    console.log("");
    await seedCamp(camp);
  }

  console.log("");
  console.log("Seeding finished.");
  console.log(`Open the app, sign in as ${GUIDE_UID}.`);
  console.log("Active camp:   '" + ACTIVE_CAMP.name + "'");
  console.log("Archived camp: '" + ARCHIVED_CAMP.name + "'");
}

// ---------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------

(async () => {
  try {
    if (WIPE) {
      await wipeSeeded();
    } else {
      await seed();
    }
    process.exit(0);
  } catch (err) {
    console.error("Seed failed:", err);
    process.exit(1);
  }
})();
