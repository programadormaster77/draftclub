/**
 * ============================================================================
 * 🔼 updateUserStats — Actualiza XP, nivel y partidos jugados
 * ============================================================================
 * Compatible con Firebase Functions v2 + Node 20
 * ============================================================================
 */
import { onCall } from "firebase-functions/v2/https";
import admin from "firebase-admin";
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
// Configuración de experiencia por nivel
const XP_BASE = 120; // Cada partido dará 120 XP aprox
const XP_SCALE = 1.12; // Cada nivel requiere 12% más XP que el anterior
// Función para obtener XP necesaria por nivel
function xpRequiredForLevel(level) {
    return Math.floor(500 * Math.pow(XP_SCALE, level - 1));
}
export const updateUserStats = onCall(async (request) => {
    try {
        const { userIds, xpGained } = request.data ?? {};
        if (!Array.isArray(userIds) || userIds.length === 0) {
            throw new Error("userIds is required and must be a non-empty array");
        }
        const xpToAdd = Number(xpGained) || XP_BASE;
        const batch = db.batch();
        for (const uid of userIds) {
            const userRef = db.collection("users").doc(uid);
            const snap = await userRef.get();
            if (!snap.exists)
                continue;
            const data = snap.data() || {};
            const oldXp = Number(data.xp || 0);
            const oldLevel = Number(data.level || 1);
            const oldMatches = Number(data.matchesPlayed || 0);
            // Nuevos valores
            let newXp = oldXp + xpToAdd;
            let newLevel = oldLevel;
            // Calcular si sube de nivel
            while (newXp >= xpRequiredForLevel(newLevel + 1)) {
                newLevel++;
            }
            const newMatches = oldMatches + 1;
            batch.update(userRef, {
                xp: newXp,
                level: newLevel,
                matchesPlayed: newMatches,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
        return {
            status: "ok",
            updatedUsers: userIds.length,
            xpAdded: xpToAdd,
        };
    }
    catch (error) {
        console.error("❌ Error en updateUserStats:", error);
        throw new Error(error.message || "Unknown error in updateUserStats");
    }
});
