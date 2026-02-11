/**
 * ============================================================================
 * 🏆 updateUserStats — Actualiza partidos, XP y rank (wins solo si árbitro)
 * ============================================================================
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const RANKS: Record<string, number> = {
  Bronce: 0,
  Plata: 500,
  Oro: 2000,
  Esmeralda: 4000,
  Diamante: 8000,
};

function computeRank(xp: number): string {
  let r = "Bronce";
  for (const k of Object.keys(RANKS)) {
    if (xp >= RANKS[k]) r = k;
  }
  return r;
}

export const updateUserStats = onCall(async (req) => {
  const data = req.data ?? {};

  const roomId = data.roomId;

  const winnerUserIds: string[] = Array.isArray(data.winnerUserIds)
    ? data.winnerUserIds
    : [];
  const loserUserIds: string[] = Array.isArray(data.loserUserIds)
    ? data.loserUserIds
    : [];

  const xpWinner =
    Number.isFinite(data.xpWinner) ? Number(data.xpWinner) : 120;
  const xpLoser = Number.isFinite(data.xpLoser) ? Number(data.xpLoser) : 60;

  // ✅ NUEVO: solo sumar wins cuando árbitro lo confirme
  const applyWins = data.applyWins === true; // por defecto false

  if (!roomId || typeof roomId !== "string") {
    throw new HttpsError("invalid-argument", "roomId is required (string)");
  }

  if (winnerUserIds.length === 0 && loserUserIds.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "winnerUserIds or loserUserIds must be provided"
    );
  }

  // Normalizar sets (evitar duplicados y solapamientos)
  const winnerSet = new Set<string>(winnerUserIds.filter(Boolean));
  const loserSet = new Set<string>(loserUserIds.filter(Boolean));
  for (const w of winnerSet) loserSet.delete(w);

  const allUserIds = [...winnerSet, ...loserSet];
  if (allUserIds.length === 0) {
    throw new HttpsError("invalid-argument", "No valid userIds after cleanup");
  }

  // ============================================================
  // ✅ 1) LOCK idempotente
  //    rooms/{roomId}/_locks/statsApplied
  // ============================================================
  const lockRef = db
    .collection("rooms")
    .doc(roomId)
    .collection("_locks")
    .doc("statsApplied");

  let acquiredLock = false;

  await db.runTransaction(async (tx) => {
    const lockSnap = await tx.get(lockRef);
    if (lockSnap.exists) {
      acquiredLock = false;
      return;
    }

    tx.set(lockRef, {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      userCount: allUserIds.length,
      // útil para debug: saber si en esta corrida se permitían wins
      applyWins,
    });

    tx.set(
      db.collection("rooms").doc(roomId),
      {
        statsApplied: true,
        statsAppliedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    acquiredLock = true;
  });

  if (!acquiredLock) {
    return { ok: true, skipped: true, reason: "already_applied" };
  }

  // ============================================================
  // ✅ 2) Updates masivos con batch
  // ============================================================
  const batch = db.batch();

  for (const uid of allUserIds) {
    const userRef = db.collection("users").doc(uid);
    const isWinner = winnerSet.has(uid);
    const xpGain = isWinner ? xpWinner : xpLoser;

    const applyWins = data.applyWins === true; // ✅ solo árbitro lo activa

batch.set(
  userRef,
  {
    matches: admin.firestore.FieldValue.increment(1),
    xp: admin.firestore.FieldValue.increment(xpGain),

    // 🚫 NO sumar wins aquí. Wins será SOLO por árbitro (otra función).
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  { merge: true }
);


  }

  await batch.commit();

  // ============================================================
  // ✅ 3) Recalcular rank (paralelo)
  // ============================================================
  await Promise.all(
    allUserIds.map(async (uid) => {
      const ref = db.collection("users").doc(uid);
      const snap = await ref.get();
      if (!snap.exists) return;

      const xp = Number((snap.data() as any)?.xp ?? 0);
      const newRank = computeRank(xp);

      await ref.set(
        {
          rank: newRank,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    })
  );

  return { ok: true, updated: allUserIds.length, applyWins };
});
