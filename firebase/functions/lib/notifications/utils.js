import * as admin from "firebase-admin";
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * 🔗 Construye deep links estándar usados por el cliente móvil.
 */
export function buildDeepLink(params) {
    const { kind, id } = params;
    if (kind === "room" && id)
        return `draftclub://room/${id}`;
    if (kind === "post" && id)
        return `draftclub://post/${id}`;
    if (kind === "user" && id)
        return `draftclub://user/${id}`;
    return "draftclub://home";
}
/**
 * 🧹 Limpia y limita un texto a N caracteres.
 */
export function clampText(s, max = 120) {
    if (!s)
        return "";
    const clean = s.replace(/\s+/g, " ").trim();
    return clean.length > max ? clean.slice(0, max - 1) + "…" : clean;
}
/**
 * 👥 Obtiene UIDs de seguidores de un autor.
 * Estructura esperada: follows/{uid}/followers/{followerUid}: { createdAt }
 */
export async function getFollowersOfUser(uid) {
    // Si tu estructura es follows/{author}/following/{target}, cambia esta consulta.
    // Aquí asumimos subcolección "followers".
    const snap = await db.collection("follows").doc(uid).collection("followers").get().catch(() => null);
    if (!snap || snap.empty)
        return [];
    return snap.docs.map((d) => d.id);
}
/**
 * 🔐 Obtiene tokens FCM válidos del usuario si sus prefs lo permiten.
 * Guarda solo tokens útiles (filtra nulos/duplicados).
 */
export async function getUserTokensIfAllowed(uid, opts) {
    const doc = await db.collection("users").doc(uid).get();
    if (!doc.exists)
        return [];
    const data = doc.data() || {};
    const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens.filter(Boolean) : [];
    const prefs = data.notifPrefs || {};
    const global = prefs.global ?? true;
    const messages = prefs.messages ?? true;
    const rooms = prefs.rooms ?? true;
    const marketing = prefs.marketing ?? false;
    if (opts?.requireGlobal && !global)
        return [];
    if (opts?.requireMessages && !messages)
        return [];
    if (opts?.requireRooms && !rooms)
        return [];
    if (opts?.requireMarketing && !marketing)
        return [];
    return Array.from(new Set(tokens));
}
/**
 * 🌙 Comprueba si el usuario está en ventana DND (No molestar).
 * prefs.dnd: { enabled: boolean, from: "22:00", to: "08:00" }
 * Nota: sin timezone del usuario, se evalúa en hora del servidor.
 */
export function isInDndWindow(prefs, now = new Date()) {
    const dnd = prefs?.dnd;
    if (!dnd?.enabled)
        return false;
    const parseHM = (s) => {
        const [h, m] = (s || "00:00").split(":").map((x) => parseInt(x, 10) || 0);
        return { h, m };
    };
    const f = parseHM(dnd.from || "22:00");
    const t = parseHM(dnd.to || "08:00");
    const minutes = now.getHours() * 60 + now.getMinutes();
    const fromMin = f.h * 60 + f.m;
    const toMin = t.h * 60 + t.m;
    // Ventana que cruza medianoche (ej: 22:00 → 08:00)
    if (fromMin > toMin) {
        return minutes >= fromMin || minutes < toMin;
    }
    // Ventana normal
    return minutes >= fromMin && minutes < toMin;
}
/**
 * 📌 Devuelve el tópico normalizado de ciudad.
 */
export function cityTopic(city) {
    if (!city || typeof city !== "string")
        return null;
    const norm = city.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().replace(/\s+/g, "_");
    return `city_${norm}`;
}
/**
 * 🔎 Obtiene documento de usuario (útil para leer prefs completas).
 */
export async function getUserDoc(uid) {
    const doc = await db.collection("users").doc(uid).get();
    return doc.exists ? doc.data() || null : null;
}
/**
 * 🧩 Obtiene miembros de una sala (si tu modelo los guarda en 'members' string[])
 */
export async function getRoomMembers(roomId) {
    const doc = await db.collection("rooms").doc(roomId).get();
    if (!doc.exists)
        return [];
    const data = doc.data() || {};
    const members = Array.isArray(data.members) ? data.members.filter(Boolean) : [];
    return members;
}
