import * as admin from "firebase-admin";
import { clampText } from "./utils";

if (!admin.apps.length) {
  admin.initializeApp();
}

const messaging = admin.messaging();

/**
 * 🧰 Construye payload unificado (Android/iOS) con canal y sonido de árbitro.
 * link: deep link "draftclub://..."
 */
export function buildPayload(params: {
  title: string;
  body: string;
  link?: string;
  data?: Record<string, string | number | boolean>;
  androidChannelId?: string; // por defecto 'draftclub_general'
}): admin.messaging.MessagingPayload {
  const title = clampText(params.title, 80);
  const body = clampText(params.body, 160);
  const link = params.link || "draftclub://home";
  const androidChannel = params.androidChannelId || "draftclub_general";

  // Todos los valores en data deben ser string
  const data: Record<string, string> = {
    link: String(link),
    ...(Object.fromEntries(
      Object.entries(params.data || {}).map(([k, v]) => [k, String(v)])
    )),
  };

  return {
    notification: {
      title,
      body,
    },
    data,
    android: {
      notification: {
        channelId: androidChannel,
        sound: "referee_whistle",
        priority: "high",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          sound: "referee_whistle.caf",
          contentAvailable: true,
        },
      },
      headers: {
        "apns-priority": "10",
      },
    },
  };
}

/**
 * 🎯 Envía a tokens específicos (multicast).
 */
export async function sendToTokens(tokens: string[], payload: admin.messaging.MessagingPayload) {
  if (!tokens.length) return { successCount: 0, failureCount: 0 };
  const res = await messaging.sendEachForMulticast({ tokens, ...payload });
  return { successCount: res.successCount, failureCount: res.failureCount, responses: res.responses };
}

/**
 * 🌍 Envía a un tópico (suscripción previa requerida).
 */
export async function sendToTopic(topic: string, payload: admin.messaging.MessagingPayload) {
  return messaging.sendToTopic(topic, payload);
}
