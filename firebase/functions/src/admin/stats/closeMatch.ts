/**
 * ============================================================================
 * 🏁 closeMatch — Cierra una sala y aplica resultados (notifs + stats + XP)
 * ============================================================================
 * Callable v2 (Node 20 / firebase-functions v2)
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Umbrales de rango
const RANKS: Record<string, number> = {
  Bronce: 0,
  Plata: 500,
  Oro: 2000,
  Esmeralda: 4000,
  Diamante: 8000,
};

function computeRank(xp: number): string {
  let r = "Bronce";
  for (const [name, threshold] of Object.entries(RANKS)) {
    if (xp >= threshold) r = name;
  }
  return r;
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

export const closeMatch = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Usuario no autenticado");

  const { roomId, winnerTeamId } = req.data ?? {};
  if (!roomId || typeof roomId !== "string") {
    throw new HttpsError("invalid-argument", "roomId es requerido");
  }
  if (!winnerTeamId || typeof winnerTeamId !== "string") {
    throw new HttpsError("invalid-argument", "winnerTeamId es requerido");
  }

  const roomRef = db.collection("rooms").doc(roomId);
  const teamsCol = roomRef.collection("teams");

  // Config de XP (ajústalo si quieres)
  const XP_WINNER = 120;
  const XP_LOSER = 80;

  // 1) Transaction de “lock” para evitar doble cierre
  //    (No existe tx.commit: la transacción se confirma sola si no lanza error)
  const lockResult = await db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "La sala no existe");
    }

    const room = roomSnap.data()!;
    if (room.creatorId !== uid) {
      throw new HttpsError("permission-denied", "Solo el creador puede cerrarla");
    }

    if (room.isClosed === true) {
      // Idempotente: ya cerrada → salimos sin re-aplicar
      return { alreadyClosed: true, roomName: room.name ?? "", winnerTeamName: room.winnerTeamName ?? "" };
    }

    // Marcamos cerrada y un flag para saber que stats ya fueron aplicados (idempotencia)
    tx.update(roomRef, {
      isClosed: true,
      winnerTeamId,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      statsApplied: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { alreadyClosed: false, roomName: room.name ?? "" };
  });

  if (lockResult.alreadyClosed) {
    return { ok: true, alreadyClosed: true };
  }

  // 2) Leemos equipos fuera de la transacción
  const teamsSnap = await teamsCol.get();
  if (teamsSnap.empty) {
    throw new HttpsError("failed-precondition", "No hay equipos en esta sala");
  }

  const winnerPlayers = new Set<string>();
  const loserPlayers = new Set<string>();
  let winnerTeamName = "Equipo ganador";

  for (const doc of teamsSnap.docs) {
    const data = doc.data();
    const players = Array.isArray(data.players) ? (data.players as string[]) : [];
    if (doc.id === winnerTeamId) {
      winnerTeamName = (data.name as string) ?? winnerTeamName;
      players.forEach((p) => winnerPlayers.add(p));
    } else {
      players.forEach((p) => loserPlayers.add(p));
    }
  }

  // Por seguridad: quitar duplicados
  for (const w of winnerPlayers) loserPlayers.delete(w);

  const allPlayers = [...winnerPlayers, ...loserPlayers];
  if (allPlayers.length === 0) {
    // Sala cerrada pero sin jugadores en teams
    await roomRef.update({ winnerTeamName });
    return { ok: true, updated: 0 };
  }

  // 3) Batch de notificaciones + stats (con chunk por límite 500 ops)
  //    Cada jugador genera 2 writes aprox: notif + update user
  //    Así que chunk pequeño para no pasarnos.
  const playerChunks = chunk(allPlayers, 150);

  const serverNow = admin.firestore.FieldValue.serverTimestamp();

  for (const group of playerChunks) {
    const batch = db.batch();

    for (const playerId of group) {
      const isWinner = winnerPlayers.has(playerId);
      const xpGain = isWinner ? XP_WINNER : XP_LOSER;

      // Notif en users/{uid}/matchResults/{roomId}
      const notifRef = db
        .collection("users")
        .doc(playerId)
        .collection("matchResults")
        .doc(roomId);

      batch.set(
        notifRef,
        {
          roomId,
          winnerTeamId,
          winnerTeamName,
          isWinner,
          title: isWinner ? "Victoria absoluta ⚽" : "No se dio esta vez... 💔",
          body: isWinner
            ? `Tu equipo ${winnerTeamName} dominó la cancha. ¡Sigue así!`
            : `Hoy no se dio, pero el fútbol siempre da revancha.`,
          type: "match_result",
          createdAt: serverNow,
          seen: false,
        },
        { merge: true }
      );

      // Stats en users/{uid}
      const userRef = db.collection("users").doc(playerId);
      batch.set(
        userRef,
        {
          matches: admin.firestore.FieldValue.increment(1),
          xp: admin.firestore.FieldValue.increment(xpGain),
          ...(isWinner ? { wins: admin.firestore.FieldValue.increment(1) } : {}),
          updatedAt: serverNow,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }

  // 4) Recalcular rank (lectura + update) también en chunks
  const rankChunks = chunk(allPlayers, 200);
  for (const group of rankChunks) {
    const snaps = await Promise.all(group.map((pid) => db.collection("users").doc(pid).get()));

    const batch = db.batch();
    for (const s of snaps) {
      if (!s.exists) continue;
      const data = s.data()!;
      const xp = typeof data.xp === "number" ? data.xp : 0;
      const newRank = computeRank(xp);
      batch.update(s.ref, { rank: newRank });
    }
    await batch.commit();
  }

  // 5) Guardar winnerTeamName en la sala (una sola vez)
  await roomRef.update({
    winnerTeamName,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true, updated: allPlayers.length, winnerTeamName };
});
