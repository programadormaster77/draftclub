/**
 * ============================================================================
 * 🧠 DraftClub — Cloud Functions Index (Node.js 20 / ESM / Firebase v6+)
 * ============================================================================
 */
import admin from "firebase-admin";
// Inicializar Firebase una sola vez
if (!admin.apps.length) {
    admin.initializeApp();
}
// IMPORTS 100% SEGUROS
import * as sendAdminNotification from "./admin/notifications/sendAdminNotification.js";
import { sendMatchResultNotification } from "./admin/notifications/sendMatchResultNotification.js";
import * as updateUserStats from "./admin/stats/updateUserStats.js";
// EXPORTS 100% SEGUROS
export { sendAdminNotification, sendMatchResultNotification, updateUserStats, };
