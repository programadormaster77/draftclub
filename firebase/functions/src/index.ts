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

// IMPORTS
import * as sendAdminNotification from "./admin/notifications/sendAdminNotification.js";
import { sendMatchResultNotification } from "./admin/notifications/sendMatchResultNotification.js";

// ✅ Importa la FUNCIÓN (no el módulo) para nombre exacto
import { updateUserStats } from "./admin/stats/updateUserStats.js";
import { closeMatch } from "./admin/stats/closeMatch.js";

// EXPORTS
export {
  sendAdminNotification,
  sendMatchResultNotification,
  updateUserStats,
  closeMatch,
};
