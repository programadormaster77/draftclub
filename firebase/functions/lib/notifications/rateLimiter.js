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
exports.shouldThrottle = shouldThrottle;
exports.purgeOldRateLimits = purgeOldRateLimits;
const admin = __importStar(require("firebase-admin"));
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * ⏱️ Rate limiter básico con Firestore.
 * Guarda un registro "rate_limits/{key}" con lastSent y windowSeconds.
 */
async function shouldThrottle(key, windowSeconds) {
    const ref = db.collection("rate_limits").doc(key);
    const snap = await ref.get();
    const now = admin.firestore.Timestamp.now();
    if (!snap.exists) {
        await ref.set({ lastSent: now, windowSeconds });
        return false; // no throttled
    }
    const data = snap.data() || {};
    const lastSent = data.lastSent || now;
    const passedSec = (now.seconds - lastSent.seconds);
    if (passedSec < windowSeconds) {
        return true; // throttle
    }
    await ref.set({ lastSent: now, windowSeconds }, { merge: true });
    return false;
}
/**
 * 🧹 (Opcional) Limpia registros antiguos de rate_limits.
 */
async function purgeOldRateLimits(olderThanHours = 24) {
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - olderThanHours * 3600 * 1000);
    const snap = await db.collection("rate_limits").where("lastSent", "<", cutoff).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    if (!snap.empty)
        await batch.commit();
}
