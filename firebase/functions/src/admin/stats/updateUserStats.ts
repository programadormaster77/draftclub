/**
 * ============================================================================
 * 🏆 updateUserStats — Actualiza partidos, wins, XP y rank (idempotente)
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
  // ✅ 1) LOCK idempotente: si ya se aplicó, salimos sin duplicar
  //    Creamos un doc único por sala: rooms/{roomId}/_locks/statsApplied
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
      acquiredLock = false; // ya aplicado
      return;
    }

    tx.set(lockRef, {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      userCount: allUserIds.length,
    });

    // (Opcional) marcar la sala también, para debug/UI
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
    // Ya estaba aplicado: respuesta OK sin cambios
    return { ok: true, skipped: true, reason: "already_applied" };
  }

  // ============================================================
  // ✅ 2) Updates masivos (FUERA de la transacción) con batch
  //    Usamos set({merge:true}) para NO fallar si el user doc no existe
  // ============================================================
  const batch = db.batch();

  for (const uid of allUserIds) {
    const userRef = db.collection("users").doc(uid);
    const isWinner = winnerSet.has(uid);
    const xpGain = isWinner ? xpWinner : xpLoser;

    batch.set(
      userRef,
      {
        matches: admin.firestore.FieldValue.increment(1),
        xp: admin.firestore.FieldValue.increment(xpGain),
        ...(isWinner
          ? { wins: admin.firestore.FieldValue.increment(1) }
          : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await batch.commit();

  // ============================================================
  // ✅ 3) Recalcular rank (paralelo) — lectura + update por usuario
  // ============================================================
  await Promise.all(
    allUserIds.map(async (uid) => {
      const ref = db.collection("users").doc(uid);
      const snap = await ref.get();
      if (!snap.exists) return;

      const xp = Number((snap.data() as any)?.xp ?? 0);
      const newRank = computeRank(xp);

      await ref.set(
        { rank: newRank, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    })
  );

  return { ok: true, updated: allUserIds.length };
});
