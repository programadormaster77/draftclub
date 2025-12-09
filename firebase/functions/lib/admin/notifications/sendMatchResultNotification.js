/**
 * ============================================================================
 * 🔔 sendMatchResultNotification — Notificaciones de resultados (GANAR / PERDER)
 * ============================================================================
 * Compatible con Firebase Functions v2 + Node 20
 */
import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";
import { buildPayload, sendToTokens } from "../../notifications/publisher.js";
import { getTokensOfUsers } from "../../utils/getTokensOfUsers.js";
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
export const sendMatchResultNotification = onRequest(async (req, res) => {
    try {
        const { roomId, roomName, winnerTeamId, winnerTeamName, winners = [], losers = [], } = req.body ?? {};
        console.log("📩 Datos recibidos:", JSON.stringify(req.body, null, 2));
        // ------------------ VALIDACIÓN ------------------
        if (!roomId || !winnerTeamId || !winnerTeamName) {
            res.status(400).json({
                error: "Missing required parameters",
                details: { roomId, winnerTeamId, winnerTeamName },
            });
            return;
        }
        // ------------------ TOKENS ------------------
        const winnerTokens = await getTokensOfUsers(winners);
        const loserTokens = await getTokensOfUsers(losers);
        // ------------------ PAYLOADS ------------------
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
        // ------------------ ENVÍO ------------------
        const winResult = await sendToTokens(winnerTokens, winPayload);
        const loseResult = await sendToTokens(loserTokens, losePayload);
        console.log("WIN RESULT:", winResult);
        console.log("LOSE RESULT:", loseResult);
        res.status(200).json({
            message: "Notifications sent successfully",
            status: "ok",
            winnersSent: winResult.successCount,
            losersSent: loseResult.successCount,
        });
    }
    catch (err) {
        console.error("❌ ERROR:", err);
        res.status(500).json({
            error: err?.message ?? "Unknown error",
            details: err,
        });
    }
});
