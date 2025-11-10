import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { buildDeepLink, cityTopic, clampText, getFollowersOfUser, getRoomMembers, getUserDoc, getUserTokensIfAllowed, isInDndWindow } from "./utils.js";
import { buildPayload, sendToTokens, sendToTopic } from "./publisher.js";
import { shouldThrottle } from "./rateLimiter.js";
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
// 🌎 Ajusta región si lo deseas
setGlobalOptions({ region: "us-central1", maxInstances: 20 });
/**
 * 1) 🔔 Nuevo POST → notificar a seguidores del autor
 * Ruta esperada: posts/{postId} con campos: authorId, city, caption, createdAt
 */
export const onCreatePost = onDocumentCreated("posts/{postId}", async (event) => {
    const post = event.data?.data();
    if (!post)
        return;
    const authorId = post.authorId;
    const postId = event.params.postId;
    const caption = clampText(post.caption || "Nueva publicación");
    const link = buildDeepLink({ kind: "post", id: postId });
    // Rate limit por post para no duplicar
    const rlKey = `post_${postId}`;
    if (await shouldThrottle(rlKey, 30))
        return;
    // Seguidores del autor
    const followers = await getFollowersOfUser(authorId);
    if (!followers.length)
        return;
    // Recolecta tokens respetando prefs (global)
    const allTokens = [];
    for (const uid of followers) {
        const userData = await getUserDoc(uid);
        if (!userData)
            continue;
        if (isInDndWindow(userData?.notifPrefs))
            continue;
        const tokens = await getUserTokensIfAllowed(uid, { requireGlobal: true });
        allTokens.push(...tokens);
    }
    const payload = buildPayload({
        title: "Nueva publicación",
        body: caption,
        link,
        data: { type: "post", postId },
    });
    await sendToTokens(Array.from(new Set(allTokens)), payload);
});
/**
 * 2) 🏟️ Nueva SALA → notificar por TÓPICO de ciudad
 * Ruta esperada: rooms/{roomId} con campos: city, title, createdAt
 */
export const onCreateRoom = onDocumentCreated("rooms/{roomId}", async (event) => {
    const room = event.data?.data();
    if (!room)
        return;
    const roomId = event.params.roomId;
    const city = room.city || null;
    const title = clampText(room.title || "Nueva sala cerca de ti");
    const link = buildDeepLink({ kind: "room", id: roomId });
    // Rate limit por ciudad y por room
    const topic = cityTopic(city);
    if (!topic)
        return;
    const rlKey = `room_city_${topic}_${roomId}`;
    if (await shouldThrottle(rlKey, 30))
        return;
    const payload = buildPayload({
        title: "Se creó una sala en tu ciudad",
        body: title,
        link,
        data: { type: "roomCreated", roomId },
    });
    await sendToTopic(topic, payload);
});
/**
 * 3) 💬 Mensaje en chat GLOBAL de sala → notificar a miembros
 * Ruta esperada: roomChats/{roomId}/messages/{msgId} con fields: authorId, text, createdAt
 */
export const onCreateRoomMessage = onDocumentCreated("roomChats/{roomId}/messages/{msgId}", async (event) => {
    const msg = event.data?.data();
    if (!msg)
        return;
    const roomId = event.params.roomId;
    const authorId = msg.authorId || "alguien";
    const text = clampText(msg.text || "Nuevo mensaje");
    const link = buildDeepLink({ kind: "room", id: roomId });
    // Rate limit por room para bursts
    const rlKey = `room_msg_${roomId}`;
    if (await shouldThrottle(rlKey, 5))
        return;
    // Tokens de miembros, respetando prefs.messages + DND
    const members = await getRoomMembers(roomId);
    const allTokens = [];
    for (const uid of members) {
        const userData = await getUserDoc(uid);
        if (!userData)
            continue;
        if (isInDndWindow(userData?.notifPrefs))
            continue;
        const tokens = await getUserTokensIfAllowed(uid, { requireGlobal: true, requireMessages: true });
        allTokens.push(...tokens);
    }
    const payload = buildPayload({
        title: "Nuevo mensaje en tu sala",
        body: `${authorId}: ${text}`,
        link,
        data: { type: "roomMessage", roomId },
    });
    await sendToTokens(Array.from(new Set(allTokens)), payload);
});
/**
 * 4) 💬 Mensaje en chat de EQUIPO → notificar a miembros de ese equipo
 * Ruta esperada: teamChats/{roomTeamId}/messages/{msgId}
 * - roomTeamId puede ser: `${roomId}_${teamId}`
 * - Mensaje: { authorId, text, createdAt }
 */
export const onCreateTeamMessage = onDocumentCreated("teamChats/{roomTeamId}/messages/{msgId}", async (event) => {
    const msg = event.data?.data();
    if (!msg)
        return;
    const roomTeamId = event.params.roomTeamId;
    const [roomId] = roomTeamId.split("_"); // asumiendo convención `${roomId}_${teamId}`
    const authorId = msg.authorId || "alguien";
    const text = clampText(msg.text || "Nuevo mensaje de equipo");
    const link = buildDeepLink({ kind: "room", id: roomId });
    // Rate limit por equipo
    const rlKey = `team_msg_${roomTeamId}`;
    if (await shouldThrottle(rlKey, 5))
        return;
    // Estrategia: tópico por equipo (si lo usas) o tokens por miembros de la sala filtrando por team
    // Aquí: enviamos por tokens de miembros de la sala (puedes cambiar a tópico 'team_${roomTeamId}')
    const members = await getRoomMembers(roomId);
    const allTokens = [];
    for (const uid of members) {
        const userData = await getUserDoc(uid);
        if (!userData)
            continue;
        if (isInDndWindow(userData?.notifPrefs))
            continue;
        const tokens = await getUserTokensIfAllowed(uid, { requireGlobal: true, requireMessages: true });
        allTokens.push(...tokens);
    }
    const payload = buildPayload({
        title: "Mensaje en tu equipo",
        body: `${authorId}: ${text}`,
        link,
        data: { type: "teamMessage", roomId, roomTeamId },
    });
    await sendToTokens(Array.from(new Set(allTokens)), payload);
});
