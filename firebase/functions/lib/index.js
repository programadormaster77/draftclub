/**
 * ============================================================================
 * 🧠 DraftClub — Cloud Functions Index (Node.js 20 / ESM / Firebase v6+)
 * ============================================================================
 * Centraliza todas las funciones backend de DraftClub.
 * ============================================================================
 */
import admin from "firebase-admin";
import { sendAdminNotification } from "./admin/notifications/sendAdminNotification.js";
// ✅ Inicialización segura (una sola vez)
if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp();
}
// 🚀 Exportar las funciones activas
export { sendAdminNotification };
