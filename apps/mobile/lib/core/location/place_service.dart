// 🌍 Servicio para obtener ciudades con autocompletado (Google Places)
// ===============================================================
// Este archivo usa la API de Google Places para sugerir nombres de ciudades
// mientras el usuario escribe (por ejemplo: "Bogotá", "Madrid", "Buenos Aires").
//
// ⚙️ Requisitos:
// 1️⃣ Habilitar la API "Places API" en Google Cloud.
// 2️⃣ Crear una clave de API y reemplazarla en la variable _googleApiKey.
// 3️⃣ Agregar el paquete http en pubspec.yaml:
//
// dependencies:
//   http: ^1.2.2
//
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

  /// Obtiene una lista de ciudades sugeridas a partir del texto ingresado.
  static Future<List<CitySuggestion>> fetchCitySuggestions(String input) async {
    if (input.isEmpty) return [];

    final url =
        '$_baseUrl/autocomplete/json?input=$input&types=(cities)&language=es&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener sugerencias (${response.statusCode})');
    }

    final data = json.decode(response.body);

    if (data['status'] != 'OK') {
      return [];
    }

    final predictions = data['predictions'] as List;
    return predictions
        .map((p) => CitySuggestion(
              description: p['description'],
              placeId: p['place_id'],
            ))
        .toList();
  }

  /// Obtiene las coordenadas (lat, lng) de una ciudad seleccionada.
  static Future<CitySuggestion?> getCityDetails(String placeId) async {
    final url = '$_baseUrl/details/json?place_id=$placeId&key=$_googleApiKey';
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
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();

    return CitySuggestion(
      description: result['formatted_address'] ?? '',
      placeId: placeId,
      lat: lat,
      lng: lng,
    );
  }

  // ===============================================================
  // ✅ NUEVO MÉTODO COMPATIBLE CON create_room_page Y edit_profile_page
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
