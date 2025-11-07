import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * ⏱️ Rate limiter básico con Firestore.
 * Guarda un registro "rate_limits/{key}" con lastSent y windowSeconds.
 */
export async function shouldThrottle(key: string, windowSeconds: number): Promise<boolean> {
  const ref = db.collection("rate_limits").doc(key);
  const snap = await ref.get();
  const now = admin.firestore.Timestamp.now();

  if (!snap.exists) {
    await ref.set({ lastSent: now, windowSeconds });
    return false; // no throttled
  }

  const data = snap.data() || {};
  const lastSent = (data.lastSent as admin.firestore.Timestamp) || now;
  const passedSec = (now.seconds - lastSent.seconds);

  if (passedSec < windowSeconds) {
    return true; // throttle
  }

  await ref.set({ lastSent: now, windowSeconds }, { merge: true });
  return false;
}

/**
 * 🧹 (Opcional) Limpia registros antiguos de rate_limits.
 */
export async function purgeOldRateLimits(olderThanHours = 24): Promise<void> {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - olderThanHours * 3600 * 1000);
  const snap = await db.collection("rate_limits").where("lastSent", "<", cutoff).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  if (!snap.empty) await batch.commit();
}
