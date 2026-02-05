/**
 * ============================================================================
 * 🧠 DraftClub — Cloud Functions Index (Node.js 20 / ESM / Firebase v6+)
 * ============================================================================
 */

import admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

// ✅ ESM: en TypeScript debes importar con ".js"
// porque esto se ejecuta luego en lib/*.js
import * as sendAdminNotification from "./admin/notifications/sendAdminNotification.js";
import { sendMatchResultNotification } from "./admin/notifications/sendMatchResultNotification.js";

import { updateUserStats } from "./admin/stats/updateUserStats.js";
import { closeMatch } from "./admin/stats/closeMatch.js";

export {
  sendAdminNotification,
  sendMatchResultNotification,
  updateUserStats,
  closeMatch,
};

