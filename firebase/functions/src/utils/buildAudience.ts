/**
 * ============================================================================
 * 🎯 buildAudience — Genera lista de tokens FCM según filtros (versión DRAFTCLUB FINAL)
 * ============================================================================
 * ✅ 100 % compatible con Node.js 20 / Firebase Functions 2ª generación
 * ✅ Envío GLOBAL si no se especifican filtros
 * ✅ Compatible con city / ciudad / role / vipFlag / marketing
 * ✅ Manejo seguro de tokens fcmToken, fcmTokens[] y tokens:{}
 * ============================================================================
 */

import admin from "firebase-admin";

// ✅ Inicialización segura (solo una vez)
if (!admin.apps || admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================================================
// 🧩 buildAudience principal
// ============================================================================
export async function buildAudience(filters?: {
  country?: string;
  city?: string;
  role?: string;
  vip?: boolean;
  inactiveDays?: number;
  marketing?: boolean;
}): Promise<string[]> {
  const safe: Record<string, any> =
    filters && typeof filters === "object" ? filters : {};

  // Normalizar
  const country =
    typeof safe.country === "string" ? safe.country.trim() : "";
  const city =
    typeof safe.city === "string" ? safe.city.trim() : "";
  const role =
    typeof safe.role === "string" ? safe.role.trim() : "";
  const vip =
    typeof safe.vip === "boolean" ? safe.vip : undefined;
  const marketing =
    safe.marketing === true ? true : undefined; // ✅ solo filtra si es true
  const inactiveDays =
    typeof safe.inactiveDays === "number" && safe.inactiveDays > 0
      ? safe.inactiveDays
      : 0;

  // Detectar si hay filtros activos
  const useCity = city !== "";
  const useCountry = country !== "";
  const useRole = role !== "";
  const useVip = vip !== undefined;
  const useMarketing = marketing === true;
  const useInactive = inactiveDays > 0;

  // ============================================================================
  // 🌎 CASO 1: Sin filtros => Global
  // ============================================================================
  if (
    !useCity &&
    !useCountry &&
    !useRole &&
    !useVip &&
    !useMarketing &&
    !useInactive
  ) {
    const snap = await db.collection("users").get();
    console.log(`🌍 Envío GLOBAL: ${snap.size} usuarios encontrados.`);
    return extractTokens(snap);
  }

  // ============================================================================
  // 🌆 CASO 2: Con filtros activos
  // ============================================================================
  async function runQuery(field: "" | "city" | "ciudad") {
    let query: FirebaseFirestore.Query = db.collection("users");

    if (useCountry) query = query.where("country", "==", country);
    if (useRole) query = query.where("role", "==", role);
    if (useVip) query = query.where("vipFlag", "==", vip);
    if (useMarketing) query = query.where("notifPrefs.marketing", "==", true);

    if (useInactive) {
      const threshold = new Date();
      threshold.setDate(threshold.getDate() - inactiveDays);
      query = query.where("lastActive", "<", threshold);
    }

    if (field === "city") query = query.where("city", "==", city);
    if (field === "ciudad") query = query.where("ciudad", "==", city);

    const snap = await query.get();
    return extractTokens(snap);
  }

  // Si filtras por ciudad, combinar ambas variantes
  if (useCity) {
    const [byCity, byCiudad] = await Promise.all([
      runQuery("city"),
      runQuery("ciudad"),
    ]);
    const merged = new Set([...byCity, ...byCiudad]);
    console.log(`🏙️ ${merged.size} usuarios encontrados por ciudad.`);
    return Array.from(merged);
  }

  // Si no hay ciudad pero sí otros filtros
  const result = await runQuery("");
  console.log(`🎯 ${result.length} usuarios encontrados con filtros.`);
  return result;
}

// ============================================================================
// 🧩 extractTokens — extrae tokens válidos de los documentos
// ============================================================================
function extractTokens(
  snap: FirebaseFirestore.QuerySnapshot
): string[] {
  if (!snap || snap.empty) {
    console.log("⚠️ No se encontraron usuarios con los filtros aplicados.");
    return [];
  }

  const tokenSet = new Set<string>();

  snap.forEach((doc) => {
    const data: any = doc.data() || {};

    // fcmToken simple
    if (typeof data.fcmToken === "string" && data.fcmToken.trim()) {
      tokenSet.add(data.fcmToken.trim());
    }

    // fcmTokens (array)
    if (Array.isArray(data.fcmTokens)) {
      for (const t of data.fcmTokens) {
        if (typeof t === "string" && t.trim()) tokenSet.add(t.trim());
      }
    }

    // tokens (objeto)
    if (data.tokens && typeof data.tokens === "object") {
      for (const t of Object.values(data.tokens)) {
        if (typeof t === "string" && t.trim()) tokenSet.add(t.trim());
      }
    }
  });

  console.log(`📦 ${tokenSet.size} tokens válidos extraídos.`);
  return Array.from(tokenSet);
}
