/**
 * ============================================================================
 * ✂️ clampText — Limita el tamaño de un texto sin cortar palabras importantes.
 * ============================================================================
 * Evita que los títulos o descripciones de notificaciones excedan el límite
 * máximo permitido por Firebase Cloud Messaging (FCM).
 *
 * 🔹 Uso:
 *   const shortTitle = clampText("Gran torneo de fútbol en Bogotá 2025 ⚽", 80);
 *
 * 🔹 Resulta en:
 *   "Gran torneo de fútbol en Bogotá 2025 ⚽"
 *
 * 🔹 Si el texto es más largo:
 *   - Recorta en el espacio más cercano antes del límite.
 *   - Agrega "…" (elipsis) al final.
 * ============================================================================
 */

export function clampText(text: string, maxLength: number): string {
  if (!text) return "";
  if (text.length <= maxLength) return text;

  // Recorta sin cortar palabra en mitad
  const trimmed = text.slice(0, maxLength);
  const lastSpace = trimmed.lastIndexOf(" ");

  const result = lastSpace > 0 ? trimmed.slice(0, lastSpace) : trimmed;
  return result.trim() + "…";
}
