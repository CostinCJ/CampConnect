const crypto = require("crypto");

// Excludes visually-ambiguous characters (0/O, 1/I) since a human guide types
// this code once during onboarding.
const CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 10; // 33^10 ≈ 1.8 x 10^15 combinations

function generateOrgInviteCode() {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[crypto.randomInt(CHARSET.length)];
  }
  return code;
}

module.exports = { generateOrgInviteCode, CHARSET, CODE_LENGTH };
