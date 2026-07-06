const { generateOrgInviteCode, CHARSET, CODE_LENGTH } = require("../lib/inviteCode");

test("generates a code of the expected length using only charset characters", () => {
  const code = generateOrgInviteCode();
  expect(code.length).toBe(CODE_LENGTH);
  for (const ch of code) {
    expect(CHARSET.includes(ch)).toBe(true);
  }
});

test("code length gives at least 10^12 combinations (vs. the old ~10^6)", () => {
  const combinations = Math.pow(CHARSET.length, CODE_LENGTH);
  expect(combinations).toBeGreaterThan(1e12);
});

test("1000 generated codes are all unique (sanity check, not a formal randomness proof)", () => {
  const codes = new Set(Array.from({ length: 1000 }, () => generateOrgInviteCode()));
  expect(codes.size).toBe(1000);
});
