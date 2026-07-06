const WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_ATTEMPTS = 5;

// Note: this deliberately avoids FieldValue.increment(). The transaction
// already reads the current count via tx.get(), so computing the next count
// in JS and writing a plain number is just as transactionally safe (Firestore
// re-runs the whole transaction on contention) and keeps this module usable
// against both the admin SDK (production, via getFirestore()) and the client
// SDK (emulator test harness), whose FieldValue.increment() transform objects
// are not interchangeable.
async function checkRateLimit(db, key, maxAttempts = MAX_ATTEMPTS) {
  const ref = db.doc(`rateLimits/${key}`);
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const windowStart = data && data.windowStart ? data.windowStart : now;
    const windowExpired = now - windowStart > WINDOW_MS;

    if (!data || windowExpired) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }
    if (data.count >= maxAttempts) {
      return false;
    }
    tx.update(ref, { count: data.count + 1 });
    return true;
  });
}

module.exports = { checkRateLimit, WINDOW_MS, MAX_ATTEMPTS };
