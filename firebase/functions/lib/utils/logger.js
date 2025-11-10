/**
 * ============================================================================
 * 🧾 logger — Sistema simple de logging con niveles y timestamps.
 * ============================================================================
 * Mejora la legibilidad de los logs en Cloud Functions y consola local.
 *
 * 🔹 Soporta:
 *   - info()     → mensajes informativos
 *   - warn()     → advertencias
 *   - error()    → errores con detalles
 *   - success()  → operaciones completadas correctamente
 *
 * 🔹 Agrega automáticamente:
 *   - Hora local (HH:mm:ss)
 *   - Etiqueta visual por nivel
 * ============================================================================
 */
export class Logger {
    static formatTime() {
        const now = new Date();
        return now.toLocaleTimeString("es-CO", { hour12: false });
    }
    static info(message, data) {
        console.log(`ℹ️ [${this.formatTime()}] INFO: ${message}`);
        if (data)
            console.log("   ➜", JSON.stringify(data, null, 2));
    }
    static success(message, data) {
        console.log(`✅ [${this.formatTime()}] SUCCESS: ${message}`);
        if (data)
            console.log("   ➜", JSON.stringify(data, null, 2));
    }
    static warn(message, data) {
        console.warn(`⚠️ [${this.formatTime()}] WARN: ${message}`);
        if (data)
            console.warn("   ➜", JSON.stringify(data, null, 2));
    }
    static error(message, error) {
        console.error(`❌ [${this.formatTime()}] ERROR: ${message}`);
        if (error)
            console.error("   ➜", error);
    }
}
