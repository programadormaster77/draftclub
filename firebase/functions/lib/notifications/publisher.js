/**
 * ============================================================================
 * 🛰️ publisher.ts — Utilidad central para enviar notificaciones push
 * ============================================================================
 * - Soporta envío a múltiples tokens (Multicast)
 * - Soporta envío por tópico (global, marketing, torneos, etc.)
 * ============================================================================
 */
import admin from "firebase-admin";
import { clampText } from "../utils/clampText.js";
if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp();
}
const messaging = admin.messaging();
/**
 * 🧩 buildPayload — Crea un mensaje unificado (Android/iOS/Web)
 */
export function buildPayload(params) {
    const title = clampText(params.title, 80);
    const body = clampText(params.body, 160);
    const link = params.link || "draftclub://home";
    const androidChannel = params.androidChannelId || "draftclub_general";
    // 🔄 Convierte todos los valores a string
    const data = {
        link: String(link),
        ...(Object.fromEntries(Object.entries(params.data || {}).map(([k, v]) => [k, String(v)]))),
    };
    // ⚙️ Creamos un mensaje base (tipo “TopicMessage” genérico)
    const message = {
        topic: "general", // evita el error "condition missing"
        notification: { title, body },
        data,
        android: {
            priority: "high",
            notification: {
                channelId: androidChannel,
                sound: "referee_whistle",
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
        },
        apns: {
            headers: { "apns-priority": "10" },
            payload: {
                aps: {
                    alert: { title, body },
                    sound: "referee_whistle.caf",
                    contentAvailable: true,
                },
            },
        },
    };
    return message;
}
/**
 * 🚀 sendToTokens — Envía notificación a varios dispositivos
 * Soporta hasta 500 tokens simultáneamente (MulticastMessage)
 */
export async function sendToTokens(tokens, payload) {
    if (!tokens.length)
        return { successCount: 0, failureCount: 0, responses: [] };
    const multicastMessage = {
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
    };
    const response = await messaging.sendEachForMulticast(multicastMessage);
    return {
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
    };
}
/**
 * 🌎 sendToTopic — Envía una notificación a un tópico global
 */
export async function sendToTopic(topic, payload) {
    const message = {
        topic,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
    };
    const response = await messaging.send(message);
    console.log(`📢 Notificación enviada al tópico "${topic}"`);
    return response;
}
