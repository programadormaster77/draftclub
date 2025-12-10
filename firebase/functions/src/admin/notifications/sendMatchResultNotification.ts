/**
 * ============================================================================
 * 🔔 sendMatchResultNotification — Notificaciones + Historial + Tarjetas
 * ============================================================================
 * Optimizado y corregido para que SÍ envíe notificaciones push reales.
 * Usa buildPayload + sendToTokens (publisher.ts) con sonido y canal correctos.
 * ============================================================================
 */

import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";

import { buildPayload, sendToTokens } from "../../notifications/publisher.js";
import { getTokensOfUsers } from "../../utils/getTokensOfUsers.js";

import { Request, Response } from "express";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
// Lo dejamos por compatibilidad, aunque no lo usemos directamente
const messaging = admin.messaging();

export const sendMatchResultNotification = onRequest(
  async (req: Request, res: Response): Promise<void> => {
    try {
      const {
        roomId,
        roomName,
        winnerTeamId,
        winnerTeamName,
        winners = [],
        losers = [],
      } = req.body ?? {};

      if (!roomId || !winnerTeamId || !winnerTeamName) {
        res.status(400).json({
          error: "Missing required parameters",
          details: { roomId, winnerTeamId, winnerTeamName },
        });
        return;
      }

      // ------------------------------------------------------------
      // 1️⃣ Obtener tokens reales desde la colección users.fcmTokens
      // ------------------------------------------------------------
      const winnerTokens = await getTokensOfUsers(winners);
      const loserTokens = await getTokensOfUsers(losers);

      console.log("WIN TOKENS:", winnerTokens);
      console.log("LOSE TOKENS:", loserTokens);

      // ------------------------------------------------------------
      // 2️⃣ Crear payloads usando buildPayload (canal + sonido correctos)
      // ------------------------------------------------------------
      const winPayload = buildPayload({
        title: "🏆 ¡Victoria absoluta!",
        body: `Tu equipo ${winnerTeamName} ganó el partido en la sala ${roomName}.`,
        link: `draftclub://victory?roomId=${roomId}`,
        androidChannelId: "draftclub_general",
        data: {
          type: "victory",
          roomId,
          roomName,
          winnerTeamId,
          winnerTeamName,
        },
      });

      const losePayload = buildPayload({
        title: "😔 No fue tu día…",
        body: `Otro equipo ganó el partido en la sala ${roomName}.`,
        link: `draftclub://defeat?roomId=${roomId}`,
        androidChannelId: "draftclub_general",
        data: {
          type: "defeat",
          roomId,
          roomName,
          winnerTeamId,
          winnerTeamName,
        },
      });

      // ------------------------------------------------------------
      // 3️⃣ Enviar notificaciones push reales con sendToTokens
      //     (usa admin.messaging().sendEachForMulticast por dentro)
      // ------------------------------------------------------------
      let winResult: any = null;
      let loseResult: any = null;

      if (winnerTokens.length > 0) {
        winResult = await sendToTokens(winnerTokens, winPayload);
      }

      if (loserTokens.length > 0) {
        loseResult = await sendToTokens(loserTokens, losePayload);
      }

      console.log("WIN RESULT:", winResult);
      console.log("LOSE RESULT:", loseResult);

      // ------------------------------------------------------------
      // 4️⃣ Guardar historial (BATCH)
      // ------------------------------------------------------------
      const batch = db.batch();
      const serverNow = Date.now();

      const matchHistory = {
        roomId,
        roomName,
        winnerTeamId,
        winnerTeamName,
        timestamp: serverNow,
      };

      // Historial global del partido
      batch.set(db.collection("roomsHistory").doc(roomId), matchHistory);

      // Historial por usuario — ganadores
      for (const uid of winners) {
        batch.set(
          db.collection("users").doc(uid).collection("matchResults").doc(roomId),
          { ...matchHistory, result: "victory" }
        );
      }

      // Historial por usuario — perdedores
      for (const uid of losers) {
        batch.set(
          db.collection("users").doc(uid).collection("matchResults").doc(roomId),
          { ...matchHistory, result: "defeat" }
        );
      }

      // ------------------------------------------------------------
      // 5️⃣ Guardar tarjeta pendiente (victoria/derrota)
      // ------------------------------------------------------------
      for (const uid of winners) {
        batch.set(
          db.collection("users").doc(uid),
          {
            pendingMatchResult: {
              type: "victory",
              roomId,
              teamName: winnerTeamName,
              seen: false,
              timestamp: serverNow,
            },
          },
          { merge: true }
        );
      }

      for (const uid of losers) {
        batch.set(
          db.collection("users").doc(uid),
          {
            pendingMatchResult: {
              type: "defeat",
              roomId,
              teamName: winnerTeamName,
              seen: false,
              timestamp: serverNow,
            },
          },
          { merge: true }
        );
      }

      // Commit único
      await batch.commit();

      res.status(200).json({
        message: "Notifications + History saved successfully",
        status: "ok",
        winnersSent: winResult?.successCount ?? 0,
        losersSent: loseResult?.successCount ?? 0,
      });
    } catch (err: any) {
      console.error("❌ ERROR sendMatchResultNotification:", err);
      res.status(500).json({
        error: err?.message ?? "Unknown error",
        details: err,
      });
    }
  }
);
