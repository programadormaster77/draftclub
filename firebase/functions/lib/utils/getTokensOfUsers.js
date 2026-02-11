import admin from "firebase-admin";
const db = admin.firestore();
/**
 * Obtiene todos los tokens FCM de una lista de UIDs.
 * @param userIds string[]
 * @returns Promise<string[]> tokens
 */
export async function getTokensOfUsers(userIds) {
    if (!userIds || userIds.length === 0)
        return [];
    const tokens = [];
    for (const uid of userIds) {
        try {
            const snap = await db.collection("users").doc(uid).get();
            if (!snap.exists)
                continue;
            const data = snap.data();
            const userTokens = data?.fcmTokens ?? [];
            if (Array.isArray(userTokens)) {
                tokens.push(...userTokens);
            }
        }
        catch (e) {
            console.error("Error obteniendo tokens de usuario:", uid, e);
        }
    }
    return tokens;
}
