const { clientIpKey } = require("../lib/clientIp");

const req = (xff, remoteAddress) => ({
  headers: xff === undefined ? {} : { "x-forwarded-for": xff },
  socket: { remoteAddress },
});

test("keys on the LAST X-Forwarded-For hop, which the client can't forge", () => {
  expect(clientIpKey(req("6.6.6.6, 1.2.3.4"))).toBe(clientIpKey(req("1.2.3.4")));
  expect(clientIpKey(req("7.7.7.7, 1.2.3.4"))).toBe(clientIpKey(req("6.6.6.6, 1.2.3.4")));
});

test("different real IPs get different keys", () => {
  expect(clientIpKey(req("1.2.3.4"))).not.toBe(clientIpKey(req("1.2.3.5")));
});

test("falls back to the socket address and never exposes the raw IP", () => {
  const key = clientIpKey(req(undefined, "10.0.0.1"));
  expect(key).toBe(clientIpKey(req("10.0.0.1")));
  expect(key).not.toContain("10.0.0.1");
  expect(key).toMatch(/^[0-9a-f]{32}$/);
});
