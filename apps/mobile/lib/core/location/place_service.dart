// 🌍 Servicio para obtener ciudades o direcciones con autocompletado (Google Places)
// ===============================================================
// Este archivo usa la API de Google Places para sugerir nombres de
// ciudades o direcciones mientras el usuario escribe.
// Ejemplo: "Bogotá", "Madrid", "Calle 45 #12-30, Medellín".
//
// ⚙️ Requisitos:
// 1️⃣ Habilitar la API "Places API" en Google Cloud.
// 2️⃣ Crear una clave de API y reemplazarla en _googleApiKey.
// 3️⃣ Agregar el paquete http en pubspec.yaml:
//
// dependencies:
//   http: ^1.2.2
// ===============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Clave de la API de Google (⚠️ reemplaza por la tuya)
const String _googleApiKey = "AIzaSyCV9KM9k8rv3rOaG2uPXTCaRlwK2PebtlM";

/// Clase auxiliar para representar una ciudad sugerida.
class CitySuggestion {
  final String description; // Ej: "Bogotá, Colombia"
  final String placeId;
  final double? lat;
  final double? lng;

  CitySuggestion({
    required this.description,
    required this.placeId,
    this.lat,
    this.lng,
  });

  @override
  String toString() => description;
}

/// Servicio para interactuar con la API de Google Places.
class PlaceService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // ===============================================================
  // 🌆 Sugerencias de CIUDADES
  // ===============================================================
  static Future<List<CitySuggestion>> fetchCitySuggestions(String input) async {
    if (input.isEmpty) return [];

    final url =
        '$_baseUrl/autocomplete/json?input=$input&types=(cities)&language=es&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
            'Error al obtener sugerencias (${response.statusCode})');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK' || data['predictions'] == null) return [];

      final predictions = data['predictions'] as List;
      return predictions
          .map((p) => CitySuggestion(
                description: (p['description'] ?? '') as String,
                placeId: (p['place_id'] ?? '') as String,
              ))
          .where((p) => p.placeId.isNotEmpty)
          .toList();
    } catch (e) {
      print('⚠️ Error en fetchCitySuggestions: $e');
      return [];
    }
  }

  // ===============================================================
  // 📍 Detalles de una CIUDAD seleccionada
  // ===============================================================
  static Future<CitySuggestion?> getCityDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    final url =
        '$_baseUrl/details/json?place_id=$placeId&language=es&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error al obtener detalles (${response.statusCode})');
      }

      final data = json.decode(response.body);
      final result = data['result'];
      if (result == null ||
          result['geometry'] == null ||
          result['geometry']['location'] == null) {
        return null;
      }

      final location = result['geometry']['location'];
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();

      return CitySuggestion(
        description:
            (result['formatted_address'] ?? result['name'] ?? '') as String,
        placeId: placeId,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      print('⚠️ Error en getCityDetails: $e');
      return null;
    }
  }

  // ===============================================================
  // 🏠 Sugerencias de DIRECCIONES EXACTAS
  // ===============================================================
  static Future<List<Map<String, dynamic>>> fetchAddressSuggestions(
      String input) async {
    if (input.isEmpty) return [];

    // 🔄 Se usa 'geocode' en lugar de 'address' para mayor compatibilidad
    final url =
        '$_baseUrl/autocomplete/json?input=$input&types=geocode&language=es&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
            'Error al obtener direcciones (${response.statusCode})');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK' || data['predictions'] == null) return [];

      final predictions = data['predictions'] as List;
      final List<Map<String, dynamic>> addresses = [];

      for (final p in predictions) {
        final placeId = (p['place_id'] ?? '') as String;
        if (placeId.isEmpty) continue;

        final details = await getAddressDetails(placeId);
        if (details != null) addresses.add(details);
      }

      return addresses;
    } catch (e) {
      print('⚠️ Error en fetchAddressSuggestions: $e');
      return [];
    }
  }

  // ===============================================================
  // 🧭 Detalles de una DIRECCIÓN (coordenadas y texto completo)
  // ===============================================================
  static Future<Map<String, dynamic>?> getAddressDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    final url =
        '$_baseUrl/details/json?place_id=$placeId&language=es&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error al obtener detalles (${response.statusCode})');
      }

      final data = json.decode(response.body);
      final result = data['result'];

      if (result == null ||
          result['geometry'] == null ||
          result['geometry']['location'] == null) {
        return null;
      }

      final location = result['geometry']['location'];
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();

      return {
        'address':
            (result['formatted_address'] ?? result['name'] ?? '') as String,
        'lat': lat,
        'lng': lng,
      };
    } catch (e) {
      print('⚠️ Error en getAddressDetails: $e');
      return null;
    }
  }

  // ===============================================================
  // 🔄 Método compatible con formularios antiguos
  // ===============================================================
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final suggestions = await fetchCitySuggestions(query);
    final List<Map<String, dynamic>> results = [];

    for (final s in suggestions) {
      final details = await getCityDetails(s.placeId);
      results.add({
        'name': s.description,
        'placeId': s.placeId,
        'lat': details?.lat,
        'lng': details?.lng,
      });
    }

    return results;
  }
}
