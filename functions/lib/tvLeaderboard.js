const CODE_RE = /^[A-Z0-9]{6}$/;

// The shared rateLimiter (functions/lib/rateLimiter.js) defaults to 5
// attempts per hour, tuned for login-style abuse prevention. The TV page
// polls every 15s (4/min per device), so reusing that limiter would lock a
// TV out almost immediately. This is a purpose-specific, more generous
// window: 30 requests per minute per IP, which comfortably covers a couple
// of TVs behind the same NAT/IP while still bounding abuse of this public,
// unauthenticated endpoint.
const TV_WINDOW_MS = 60 * 1000; // 1 minute
const TV_MAX_REQUESTS = 30;

async function checkTvRateLimit(db, ip) {
  const ref = db.doc(`rateLimits/tvLeaderboard:${ip}`);
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart = data && data.windowStart ? data.windowStart : now;
    const windowExpired = now - windowStart > TV_WINDOW_MS;

    if (!data || windowExpired) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }
    if (data.count >= TV_MAX_REQUESTS) {
      return false;
    }
    tx.update(ref, { count: data.count + 1 });
    return true;
  });
}

/**
 * Public read-only leaderboard for the TV page. Input: ?code=XXXXXX (the
 * camp's tvCode). Output: team aggregates only (name, colorHex, points),
 * never personal data, so the endpoint is GDPR-safe to expose. Rate
 * limited per IP; responses are edge-cacheable for 10s to absorb the TV's
 * polling.
 */
async function tvLeaderboardHandler(db, req, res) {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }
  const ip = req.ip || "unknown";
  const allowed = await checkTvRateLimit(db, ip);
  if (!allowed) {
    res.status(429).json({ error: "too-many-requests" });
    return;
  }
  const code = String((req.query && req.query.code) || "")
      .trim().toUpperCase();
  if (!CODE_RE.test(code)) {
    res.status(400).json({ error: "bad-code" });
    return;
  }
  const match = await db.collection("camps")
      .where("tvCode", "==", code).limit(1).get();
  if (match.empty) {
    res.status(404).json({ error: "not-found" });
    return;
  }
  const campDoc = match.docs[0];
  const camp = campDoc.data();
  const teamsSnap = await campDoc.ref.collection("teams").get();
  const teams = teamsSnap.docs.map((d) => ({
    name: d.data().name || d.id,
    colorHex: d.data().colorHex || "#9E9E9E",
    points: d.data().points || 0,
  })).sort((a, b) => b.points - a.points);

  res.set("Cache-Control", "public, max-age=10");
  res.status(200).json({
    campName: camp.name || "",
    language: camp.language || "ro",
    updatedAt: new Date().toISOString(),
    teams,
  });
}

module.exports = { tvLeaderboardHandler };
