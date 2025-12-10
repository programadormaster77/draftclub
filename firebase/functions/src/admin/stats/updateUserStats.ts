/**
 * ============================================================================
 * 🏆 updateUserStats — Actualiza partidos jugados, XP y nivel del usuario
 * ============================================================================
 */

import { onCall } from "firebase-functions/v2/https";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Rangos y XP necesarios
const RANKS: Record<string, number> = {
  Bronce: 0,
  Plata: 500,
  Oro: 2000,
  Esmeralda: 4000,
  Diamante: 8000,
};

export const updateUserStats = onCall(async (req) => {
  const { userIds, xpGained = 120 } = req.data ?? {};

  if (!userIds || !Array.isArray(userIds)) {
    throw new Error("userIds must be an array");
  }

  // ===========================
  // 🔥 1) Actualizar XP y partidos
  // ===========================
  const batch = db.batch();

  for (const uid of userIds) {
    const ref = db.collection("users").doc(uid);

    batch.update(ref, {
      matches: admin.firestore.FieldValue.increment(1),
      xp: admin.firestore.FieldValue.increment(xpGained),
    });
  }

  await batch.commit();

  // ===========================
  // 🔥 2) Recalcular rangos (sin bloquear la función)
  // ===========================
  const updates = userIds.map(async (uid) => {
    const ref = db.collection("users").doc(uid);
    const snap = await ref.get();
    if (!snap.exists) return;

    const data = snap.data()!;
    const xp = data.xp ?? 0;

    let newRank = "Bronce";
    for (const rank of Object.keys(RANKS)) {
      if (xp >= RANKS[rank]) newRank = rank;
    }

    await ref.update({ rank: newRank });
  });

  // Ejecutar todo sin bloquear retorno
  await Promise.all(updates);

  return { ok: true, updated: userIds.length };
});
