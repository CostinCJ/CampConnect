const crypto = require("crypto");

/**
 * Rate-limit key for the caller's IP address.
 *
 * `req.ip` can't be trusted here: with Express's `trust proxy` it resolves to
 * the LEFTMOST X-Forwarded-For entry, which the client can set to anything,
 * so an attacker could rotate it to dodge per-IP limits. Google's front end
 * APPENDS the address it actually saw, so the LAST entry is the only one a
 * client can't forge. Falls back to the socket address when the header is
 * absent (emulator, tests).
 *
 * The IP is hashed before use: it becomes a Firestore doc id in rateLimits/,
 * and a hash keeps raw IP addresses (personal data) out of the database while
 * still bucketing the same caller together.
 */
function clientIpKey(req) {
  const header = (req && req.headers && req.headers["x-forwarded-for"]) || "";
  const hops = String(header).split(",").map((h) => h.trim()).filter(Boolean);
  const ip = hops.length > 0
    ? hops[hops.length - 1]
    : (req && req.socket && req.socket.remoteAddress) || "unknown";
  return crypto.createHash("sha256").update(ip).digest("hex").slice(0, 32);
}

module.exports = { clientIpKey };
