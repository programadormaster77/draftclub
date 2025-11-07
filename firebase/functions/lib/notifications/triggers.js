"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onCreateTeamMessage = exports.onCreateRoomMessage = exports.onCreateRoom = exports.onCreatePost = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const admin = __importStar(require("firebase-admin"));
const utils_1 = require("./utils");
const publisher_1 = require("./publisher");
const rateLimiter_1 = require("./rateLimiter");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
// 🌎 Ajusta región si lo deseas
(0, v2_1.setGlobalOptions)({ region: "us-central1", maxInstances: 20 });
/**
 * 1) 🔔 Nuevo POST → notificar a seguidores del autor
 * Ruta esperada: posts/{postId} con campos: authorId, city, caption, createdAt
 */
exports.onCreatePost = (0, firestore_1.onDocumentCreated)("posts/{postId}", async (event) => {
    const post = event.data?.data();
    if (!post)
        return;
    const authorId = post.authorId;
    const postId = event.params.postId;
    const caption = (0, utils_1.clampText)(post.caption || "Nueva publicación");
    const link = (0, utils_1.buildDeepLink)({ kind: "post", id: postId });
    // Rate limit por post para no duplicar
    const rlKey = `post_${postId}`;
    if (await (0, rateLimiter_1.shouldThrottle)(rlKey, 30))
        return;
    // Seguidores del autor
    const followers = await (0, utils_1.getFollowersOfUser)(authorId);
    if (!followers.length)
        return;
    // Recolecta tokens respetando prefs (global)
    const allTokens = [];
    for (const uid of followers) {
        const userData = await (0, utils_1.getUserDoc)(uid);
        if (!userData)
            continue;
        if ((0, utils_1.isInDndWindow)(userData?.notifPrefs))
            continue;
        const tokens = await (0, utils_1.getUserTokensIfAllowed)(uid, { requireGlobal: true });
        allTokens.push(...tokens);
    }
    const payload = (0, publisher_1.buildPayload)({
        title: "Nueva publicación",
        body: caption,
        link,
        data: { type: "post", postId },
    });
    await (0, publisher_1.sendToTokens)(Array.from(new Set(allTokens)), payload);
});
/**
 * 2) 🏟️ Nueva SALA → notificar por TÓPICO de ciudad
 * Ruta esperada: rooms/{roomId} con campos: city, title, createdAt
 */
exports.onCreateRoom = (0, firestore_1.onDocumentCreated)("rooms/{roomId}", async (event) => {
    const room = event.data?.data();
    if (!room)
        return;
    const roomId = event.params.roomId;
    const city = room.city || null;
    const title = (0, utils_1.clampText)(room.title || "Nueva sala cerca de ti");
    const link = (0, utils_1.buildDeepLink)({ kind: "room", id: roomId });
    // Rate limit por ciudad y por room
    const topic = (0, utils_1.cityTopic)(city);
    if (!topic)
        return;
    const rlKey = `room_city_${topic}_${roomId}`;
    if (await (0, rateLimiter_1.shouldThrottle)(rlKey, 30))
        return;
    const payload = (0, publisher_1.buildPayload)({
        title: "Se creó una sala en tu ciudad",
        body: title,
        link,
        data: { type: "roomCreated", roomId },
    });
    await (0, publisher_1.sendToTopic)(topic, payload);
});
/**
 * 3) 💬 Mensaje en chat GLOBAL de sala → notificar a miembros
 * Ruta esperada: roomChats/{roomId}/messages/{msgId} con fields: authorId, text, createdAt
 */
exports.onCreateRoomMessage = (0, firestore_1.onDocumentCreated)("roomChats/{roomId}/messages/{msgId}", async (event) => {
    const msg = event.data?.data();
    if (!msg)
        return;
    const roomId = event.params.roomId;
    const authorId = msg.authorId || "alguien";
    const text = (0, utils_1.clampText)(msg.text || "Nuevo mensaje");
    const link = (0, utils_1.buildDeepLink)({ kind: "room", id: roomId });
    // Rate limit por room para bursts
    const rlKey = `room_msg_${roomId}`;
    if (await (0, rateLimiter_1.shouldThrottle)(rlKey, 5))
        return;
    // Tokens de miembros, respetando prefs.messages + DND
    const members = await (0, utils_1.getRoomMembers)(roomId);
    const allTokens = [];
    for (const uid of members) {
        const userData = await (0, utils_1.getUserDoc)(uid);
        if (!userData)
            continue;
        if ((0, utils_1.isInDndWindow)(userData?.notifPrefs))
            continue;
        const tokens = await (0, utils_1.getUserTokensIfAllowed)(uid, { requireGlobal: true, requireMessages: true });
        allTokens.push(...tokens);
    }
    const payload = (0, publisher_1.buildPayload)({
        title: "Nuevo mensaje en tu sala",
        body: `${authorId}: ${text}`,
        link,
        data: { type: "roomMessage", roomId },
    });
    await (0, publisher_1.sendToTokens)(Array.from(new Set(allTokens)), payload);
});
/**
 * 4) 💬 Mensaje en chat de EQUIPO → notificar a miembros de ese equipo
 * Ruta esperada: teamChats/{roomTeamId}/messages/{msgId}
 * - roomTeamId puede ser: `${roomId}_${teamId}`
 * - Mensaje: { authorId, text, createdAt }
 */
exports.onCreateTeamMessage = (0, firestore_1.onDocumentCreated)("teamChats/{roomTeamId}/messages/{msgId}", async (event) => {
    const msg = event.data?.data();
    if (!msg)
        return;
    const roomTeamId = event.params.roomTeamId;
    const [roomId] = roomTeamId.split("_"); // asumiendo convención `${roomId}_${teamId}`
    const authorId = msg.authorId || "alguien";
    const text = (0, utils_1.clampText)(msg.text || "Nuevo mensaje de equipo");
    const link = (0, utils_1.buildDeepLink)({ kind: "room", id: roomId });
    // Rate limit por equipo
    const rlKey = `team_msg_${roomTeamId}`;
    if (await (0, rateLimiter_1.shouldThrottle)(rlKey, 5))
        return;
    // Estrategia: tópico por equipo (si lo usas) o tokens por miembros de la sala filtrando por team
    // Aquí: enviamos por tokens de miembros de la sala (puedes cambiar a tópico 'team_${roomTeamId}')
    const members = await (0, utils_1.getRoomMembers)(roomId);
    const allTokens = [];
    for (const uid of members) {
        const userData = await (0, utils_1.getUserDoc)(uid);
        if (!userData)
            continue;
        if ((0, utils_1.isInDndWindow)(userData?.notifPrefs))
            continue;
        const tokens = await (0, utils_1.getUserTokensIfAllowed)(uid, { requireGlobal: true, requireMessages: true });
        allTokens.push(...tokens);
    }
    const payload = (0, publisher_1.buildPayload)({
        title: "Mensaje en tu equipo",
        body: `${authorId}: ${text}`,
        link,
        data: { type: "teamMessage", roomId, roomTeamId },
    });
    await (0, publisher_1.sendToTokens)(Array.from(new Set(allTokens)), payload);
});
