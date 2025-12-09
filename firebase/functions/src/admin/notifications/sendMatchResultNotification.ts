/**
 * ============================================================================
 * 🔔 sendMatchResultNotification — Notificaciones + Historial + Tarjetas
 * ============================================================================
 * Compatible con Firebase Functions v2 + Node 20
 * PASOS ACTIVOS:
 * 1. Guardar historial del partido por usuario
 * 2. Dejar pendingMatchResult para mostrar tarjeta al abrir app
 * ============================================================================
 */

import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";

import { buildPayload, sendToTokens } from "../../notifications/publisher.js";
import { getTokensOfUsers } from "../../utils/getTokensOfUsers.js";

import { Request, Response } from "express";

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

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

      console.log("📩 Datos recibidos:", JSON.stringify(req.body, null, 2));

      // ------------------------------------------------------------
      // VALIDACIÓN
      // ------------------------------------------------------------
      if (!roomId || !winnerTeamId || !winnerTeamName) {
        res.status(400).json({
          error: "Missing required parameters",
          details: { roomId, winnerTeamId, winnerTeamName },
        });
        return;
      }

      // ------------------------------------------------------------
      // TOKENS
      // ------------------------------------------------------------
      const winnerTokens = await getTokensOfUsers(winners);
      const loserTokens = await getTokensOfUsers(losers);

      // ------------------------------------------------------------
      // PAYLOADS
      // ------------------------------------------------------------
      const winPayload = buildPayload({
        title: "🏆 ¡Victoria absoluta!",
        body: `Tu equipo ${winnerTeamName} ganó el partido en la sala ${roomName}.`,
        link: `draftclub://victory?roomId=${roomId}`,
      });

      const losePayload = buildPayload({
        title: "😔 No fue tu día...",
        body: `Otro equipo ganó el partido en la sala ${roomName}.`,
        link: `draftclub://defeat?roomId=${roomId}`,
      });

      // ------------------------------------------------------------
      // ENVIAR NOTIFICACIONES
      // ------------------------------------------------------------
      const winResult = await sendToTokens(winnerTokens, winPayload);
      const loseResult = await sendToTokens(loserTokens, losePayload);

      console.log("WIN RESULT:", winResult);
      console.log("LOSE RESULT:", loseResult);

      // ------------------------------------------------------------
      // PASO 1: GUARDAR HISTORIAL EN FIRESTORE
      // ------------------------------------------------------------
      const matchHistory = {
        roomId,
        roomName,
        winnerTeamId,
        winnerTeamName,
        timestamp: Date.now(),
      };

      await db.collection("roomsHistory").doc(roomId).set(matchHistory);

      // Guardar historial para cada jugador
      for (const uid of winners) {
        await db
          .collection("users")
          .doc(uid)
          .collection("matchResults")
          .doc(roomId)
          .set({
            ...matchHistory,
            result: "victory",
          });
      }

      for (const uid of losers) {
        await db
          .collection("users")
          .doc(uid)
          .collection("matchResults")
          .doc(roomId)
          .set({
            ...matchHistory,
            result: "defeat",
          });
      }

      // ------------------------------------------------------------
      // PASO 2: MARCAR TARJETA PENDIENTE PARA MOSTRAR AL ABRIR LA APP
      // ------------------------------------------------------------
      for (const uid of winners) {
        await db.collection("users").doc(uid).set(
          {
            pendingMatchResult: {
              type: "victory",
              roomId,
              teamName: winnerTeamName,
              seen: false,
              timestamp: Date.now(),
            },
          },
          { merge: true }
        );
      }

      for (const uid of losers) {
        await db.collection("users").doc(uid).set(
          {
            pendingMatchResult: {
              type: "defeat",
              roomId,
              teamName: winnerTeamName,
              seen: false,
              timestamp: Date.now(),
            },
          },
          { merge: true }
        );
      }

      // ------------------------------------------------------------
      // RESPUESTA FINAL
      // ------------------------------------------------------------
      res.status(200).json({
        message: "Notifications + History saved successfully",
        status: "ok",
        winnersSent: winResult.successCount,
        losersSent: loseResult.successCount,
      });
    } catch (err: any) {
      console.error("❌ ERROR:", err);
      res.status(500).json({
        error: err?.message ?? "Unknown error",
        details: err,
      });
    }
  }
);
