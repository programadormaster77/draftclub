/**
 * ============================================================================
 * 🚀 sendAdminNotification — Envío inteligente de notificaciones administradas
 * ============================================================================
 * Compatible con Node 20 / Firebase Functions v6+
 * ============================================================================
 */

import { onRequest } from "firebase-functions/v2/https";
import admin from "firebase-admin";
import { buildAudience } from "../../utils/buildAudience.js";
import { buildPayload, sendToTokens } from "../../notifications/publisher.js";
import { Request, Response } from "express";

// ✅ Inicialización segura (solo una vez)
if (!admin.apps || admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// ============================================================================
// 📩 Función principal (HTTP Request compatible con Flutter http.post())
// ============================================================================
export const sendAdminNotification = onRequest(
  async (req: Request, res: Response): Promise<void> => {
    try {
      // ----------------------------------------------------------------------
      // 🧠 Registro de datos recibidos
      // ----------------------------------------------------------------------
      const data = (req.body || {}) as Record<string, any>;
      console.log("📦 Datos recibidos en sendAdminNotification:");
      console.log(JSON.stringify(data, null, 2));

      // ----------------------------------------------------------------------
      // 🔍 Normalización segura de campos
      // ----------------------------------------------------------------------
      const title =
        data?.title && typeof data.title === "string"
          ? data.title.trim()
          : "";
      const body =
        data?.body && typeof data.body === "string"
          ? data.body.trim()
          : "";
      const imageUrl =
        data?.imageUrl && typeof data.imageUrl === "string"
          ? data.imageUrl.trim()
          : null;
      const deepLink =
        data?.deepLink && typeof data.deepLink === "string"
          ? data.deepLink.trim()
          : null;

      // ✅ Conversión segura (sin undefined ni null directos)
      const country =
        data?.country !== undefined && data.country !== null
          ? String(data.country).trim()
          : "";
      const city =
        data?.city !== undefined && data.city !== null
          ? String(data.city).trim()
          : "";
      const role =
        data?.role !== undefined && data.role !== null
          ? String(data.role).trim()
          : "";
      const marketing = !!data?.marketing;

      console.log("🧩 Campos normalizados:", {
        title,
        body,
        imageUrl,
        deepLink,
        country,
        city,
        role,
        marketing,
      });

      // ----------------------------------------------------------------------
      // ⚠️ Validación básica
      // ----------------------------------------------------------------------
      if (!title || !body) {
        console.warn("⚠️ Faltan campos obligatorios:", { title, body });
        res.status(400).json({
          error: {
            message: "Faltan campos obligatorios: title y body.",
            status: "INVALID_ARGUMENT",
          },
        });
        return;
      }

      // ----------------------------------------------------------------------
      // 🎯 Construcción de audiencia
      // ----------------------------------------------------------------------
      console.log("🎯 Iniciando búsqueda de audiencia...");
      const tokens = await buildAudience({
        country: country || undefined,
        city: city || undefined,
        role: role || undefined,
        marketing,
      });

      console.log(`📊 Tokens encontrados: ${tokens?.length || 0}`);

      if (!tokens || tokens.length === 0) {
        console.log("⚠️ No se encontraron destinatarios.");
        res.status(200).json({
          message: "No se encontraron destinatarios con esos filtros.",
          metrics: { tokens: 0, success: 0, failed: 0 },
          status: "no_tokens",
        });
        return;
      }

      // ----------------------------------------------------------------------
      // 🧩 Construcción del payload FCM
      // ----------------------------------------------------------------------
      const payload = buildPayload({
        title,
        body,
        link: deepLink || "draftclub://home",
        ...(imageUrl ? { imageUrl } : {}),
      });

      console.log("📨 Payload listo para enviar:", payload);

      // ----------------------------------------------------------------------
      // 🚀 Envío a tokens
      // ----------------------------------------------------------------------
      const result = await sendToTokens(tokens, payload);

      console.log(
        `✅ Notificación enviada correctamente — Éxitos: ${result.successCount}, Fallos: ${result.failureCount}`
      );

      // ----------------------------------------------------------------------
      // 📦 Respuesta final al cliente
      // ----------------------------------------------------------------------
      res.status(200).json({
        message: "Notificación enviada exitosamente.",
        metrics: {
          tokens: tokens.length,
          success: result.successCount,
          failed: result.failureCount,
        },
        status: "sent",
      });
    } catch (error: any) {
      console.error("❌ Error enviando notificación:", error);

      res.status(500).json({
        error: {
          message:
            error?.message || "Error desconocido en sendAdminNotification.",
          status: "INTERNAL",
        },
      });
    }
  }
);
