const { makeTestEnv, makeAdminDb, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { tvLeaderboardHandler } = require("../lib/tvLeaderboard");

let testEnv, db;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-tvleaderboard-test"));
  db = makeAdminDb("campconnect-tvleaderboard-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await db.collection("camps").doc("c1").set({
    name: "Camp One", orgId: "o1", tvCode: "ABC234",
    language: "ro",
    startDate: new Date(), endDate: new Date(Date.now() + 86400000),
    teams: [], createdBy: "g1",
  });
  await db.doc("camps/c1/teams/t1").set(
      { name: "Red", colorHex: "#E53935", points: 40 });
  await db.doc("camps/c1/teams/t2").set(
      { name: "Blue", colorHex: "#1E88E5", points: 90 });
});

function fakeRes() {
  const res = {
    statusCode: 200, headers: {}, body: undefined,
    set(k, v) { this.headers[k] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
  return res;
}

describe("tvLeaderboard", () => {
  test("returns teams sorted by points for a valid code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "abc234" }, ip: "9.9.9.9" }, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.campName).toBe("Camp One");
    expect(res.body.teams.map((t) => t.name)).toEqual(["Blue", "Red"]);
    expect(res.body.teams[0]).toEqual(
        { name: "Blue", colorHex: "#1E88E5", points: 90 });
  });

  test("404 for an unknown code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "ZZZZZZ" }, ip: "9.9.9.8" }, res);
    expect(res.statusCode).toBe(404);
  });

  test("400 for a malformed code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "x" }, ip: "9.9.9.7" }, res);
    expect(res.statusCode).toBe(400);
  });

  test("405 for a non-GET method", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "POST", query: { code: "ABC234" }, ip: "9.9.9.6" }, res);
    expect(res.statusCode).toBe(405);
  });

  test("429 once the per-IP polling budget is exhausted", async () => {
    const ip = "9.9.9.5";
    let last;
    // The TV polls every 15s; the limiter allows a generous 30 requests per
    // minute per IP (see lib/tvLeaderboard.js), so the 31st request in the
    // same window should be rejected.
    for (let i = 0; i < 31; i++) {
      last = fakeRes();
      // eslint-disable-next-line no-await-in-loop
      await tvLeaderboardHandler(db, { method: "GET", query: { code: "ABC234" }, ip }, last);
    }
    expect(last.statusCode).toBe(429);
  });
});
