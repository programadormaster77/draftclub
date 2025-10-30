// 🌍 Servicio global de autocompletado de ciudades y direcciones (Google Places)
// ===============================================================
// Proporciona sugerencias de CIUDADES y DIRECCIONES con coordenadas
// y país ISO-2 (p. ej. "CO", "ES", "US"), para que DraftClub
// funcione correctamente en TODO EL MUNDO.
//
// ⚙️ Requisitos:
// 1️⃣ Habilitar "Places API" en Google Cloud.
// 2️⃣ Crear una API Key y reemplazarla en [_apiKey].
// 3️⃣ Agregar el paquete http en pubspec.yaml:
//     dependencies:
//       http: ^1.2.2
// ===============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

/// ===============================================================
/// 🔑 Clave API (reemplázala por la tuya propia)
/// ===============================================================
const String _apiKey = "AIzaSyCV9KM9k8rv3rOaG2uPXTCaRlwK2PebtlM";

/// ===============================================================
/// 🧩 MODELOS
/// ===============================================================
class CitySuggestion {
  final String description; // Ej: "Barcelona, Cataluña, España"
  final String placeId;

  CitySuggestion({required this.description, required this.placeId});
}

class CityDetails {
  final String description; // Texto completo ("Barcelona, España")
  final double lat;
  final double lng;
  final String countryCode; // ISO-2: "ES", "CO", "US"...

  CityDetails({
    required this.description,
    required this.lat,
    required this.lng,
    required this.countryCode,
  });
}

/// ===============================================================
/// 🧠 Clase principal
/// ===============================================================
class PlaceService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _language = 'es';

  // ===============================================================
  // 🌆 1️⃣ Autocompletar CIUDADES
  // ===============================================================
  static Future<List<CitySuggestion>> fetchCitySuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$query&types=(cities)&language=$_language&key=$_apiKey');

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      final preds = (data['predictions'] as List? ?? []);
      return preds
          .map((p) => CitySuggestion(
                description: (p['description'] ?? '').toString(),
                placeId: (p['place_id'] ?? '').toString(),
              ))
          .where((c) => c.description.isNotEmpty && c.placeId.isNotEmpty)
          .toList();
    } catch (e) {
      print('⚠️ Error en fetchCitySuggestions: $e');
      return [];
    }
  }

  // ===============================================================
  // 📍 2️⃣ Detalles de una CIUDAD seleccionada
  // ===============================================================
  static Future<CityDetails?> getCityDetails(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    final uri = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&fields=address_component,geometry/location,formatted_address&language=$_language&key=$_apiKey');

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      final result = data['result'];
      if (result == null) return null;

      final formatted = (result['formatted_address'] ?? '').toString();
      final loc = (result['geometry']?['location']) as Map<String, dynamic>?;
      if (loc == null) return null;

      final lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;

      // 🔹 Buscar el código de país ISO-2 real
      final comps = (result['address_components'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      String countryCode = 'XX';
      for (final c in comps) {
        final types = (c['types'] as List? ?? []).cast<String>();
        if (types.contains('country')) {
          countryCode = (c['short_name'] ?? '').toString().toUpperCase();
          break;
        }
      }

      return CityDetails(
        description: formatted.isNotEmpty ? formatted : 'Desconocido',
        lat: lat,
        lng: lng,
        countryCode: countryCode,
      );
    } catch (e) {
      print('⚠️ Error en getCityDetails: $e');
      return null;
    }
  }

  // ===============================================================
  // 🏠 3️⃣ Autocompletar DIRECCIONES
  // ===============================================================
  static Future<List<Map<String, dynamic>>> fetchAddressSuggestions(
      String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$query&types=geocode&language=$_language&key=$_apiKey');

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      final preds = (data['predictions'] as List? ?? []);

      final List<Map<String, dynamic>> addresses = [];
      for (final p in preds.take(8)) {
        final pid = (p['place_id'] ?? '').toString();
        final desc = (p['description'] ?? '').toString();
        if (pid.isEmpty || desc.isEmpty) continue;

        final details = await getAddressDetails(pid);
        if (details != null) addresses.add(details);
      }

      return addresses;
    } catch (e) {
      print('⚠️ Error en fetchAddressSuggestions: $e');
      return [];
    }
  }

  // ===============================================================
  // 🧭 4️⃣ Detalles de una DIRECCIÓN (lat/lng + texto completo)
  // ===============================================================
  static Future<Map<String, dynamic>?> getAddressDetails(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    final uri = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&fields=geometry/location,formatted_address&language=$_language&key=$_apiKey');

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      final result = data['result'];
      if (result == null) return null;

      final address = (result['formatted_address'] ?? '').toString();
      final loc = (result['geometry']?['location']) as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (loc?['lng'] as num?)?.toDouble() ?? 0.0;

      return {'address': address, 'lat': lat, 'lng': lng};
    } catch (e) {
      print('⚠️ Error en getAddressDetails: $e');
      return null;
    }
  }

  // ===============================================================
  // 🔄 5️⃣ Método auxiliar compatible con formularios antiguos
  // ===============================================================
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final suggestions = await fetchCitySuggestions(query);
    final List<Map<String, dynamic>> results = [];

    for (final s in suggestions) {
      final details = await getCityDetails(s.placeId);
      if (details == null) continue;
      results.add({
        'name': s.description,
        'placeId': s.placeId,
        'lat': details.lat,
        'lng': details.lng,
        'countryCode': details.countryCode,
      });
    }

    return results;
  }
}
