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
exports.buildPayload = buildPayload;
exports.sendToTokens = sendToTokens;
exports.sendToTopic = sendToTopic;
const admin = __importStar(require("firebase-admin"));
const utils_1 = require("./utils");
if (!admin.apps.length) {
    admin.initializeApp();
}
const messaging = admin.messaging();
/**
 * 🧰 Construye payload unificado (Android/iOS) con canal y sonido de árbitro.
 * link: deep link "draftclub://..."
 */
function buildPayload(params) {
    const title = (0, utils_1.clampText)(params.title, 80);
    const body = (0, utils_1.clampText)(params.body, 160);
    const link = params.link || "draftclub://home";
    const androidChannel = params.androidChannelId || "draftclub_general";
    // Todos los valores en data deben ser string
    const data = {
        link: String(link),
        ...(Object.fromEntries(Object.entries(params.data || {}).map(([k, v]) => [k, String(v)]))),
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
async function sendToTokens(tokens, payload) {
    if (!tokens.length)
        return { successCount: 0, failureCount: 0 };
    const res = await messaging.sendEachForMulticast({ tokens, ...payload });
    return { successCount: res.successCount, failureCount: res.failureCount, responses: res.responses };
}
/**
 * 🌍 Envía a un tópico (suscripción previa requerida).
 */
async function sendToTopic(topic, payload) {
    return messaging.sendToTopic(topic, payload);
}
