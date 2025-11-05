// lib/core/utils/geo_utils.dart
// ===============================================================
// 🌍 GeoUtils — Utilidades geográficas globales
// ===============================================================
// - Cálculo de distancia (Haversine)
// - Conversión de grados a radianes
// - Validaciones de coordenadas
// ===============================================================

import 'dart:math' as math;

/// 📏 Calcula la distancia en kilómetros entre dos coordenadas geográficas.
/// Usa la fórmula de Haversine, precisa y segura.
///
/// Ejemplo:
/// ```dart
/// final km = distanceKm(4.6097, -74.0817, 6.2442, -75.5812); // Bogotá–Medellín
/// print(km); // ≈ 215.7 km
/// ```
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371.0; // Radio medio de la Tierra en km
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLon = _deg2rad(lon2 - lon1);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

/// 🔄 Convierte grados a radianes.
double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// ✅ Verifica si una coordenada geográfica es válida.
/// Devuelve `true` si latitud ∈ [-90,90] y longitud ∈ [-180,180].
bool isValidCoordinate(double? lat, double? lon) {
  if (lat == null || lon == null) return false;
  return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}

/// 🧭 Calcula un punto intermedio entre dos coordenadas.
/// Muy útil para centrar mapas o rutas entre dos ubicaciones.
Map<String, double> midpoint(
    double lat1, double lon1, double lat2, double lon2) {
  final midLat = (lat1 + lat2) / 2;
  final midLon = (lon1 + lon2) / 2;
  return {'lat': midLat, 'lng': midLon};
}
