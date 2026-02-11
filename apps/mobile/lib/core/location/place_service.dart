// 🌍 Servicio global de autocompletado de ciudades y direcciones (Google Places)
// ===============================================================
// Proporciona sugerencias de CIUDADES y DIRECCIONES con coordenadas
// y país ISO-2 (p. ej. "CO", "ES", "US"), para que DraftClub
// funcione correctamente en TODO EL MUNDO.
//
// ✅ Extensión: búsqueda de CANCHAS cerca del usuario (Nearby Search)
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

/// ✅ Resultado mínimo para “Canchas cerca”
class PitchPlace {
  final String placeId;
  final String name;
  final double lat;
  final double lng;

  /// Puede venir como `vicinity` (legacy) o `formatted_address`
  final String? address;

  final double? rating;
  final int? userRatingsTotal;

  PitchPlace({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
    this.rating,
    this.userRatingsTotal,
  });
}

/// ✅ Detalles de contacto (solo cuando el usuario toca una cancha)
class PlaceContactDetails {
  final String placeId;
  final String? phone; // formatted_phone_number
  final String? internationalPhone; // international_phone_number
  final String? website;
  final bool? openNow;

  PlaceContactDetails({
    required this.placeId,
    this.phone,
    this.internationalPhone,
    this.website,
    this.openNow,
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
      '$_baseUrl/autocomplete/json?input=$query&types=(cities)&language=$_language&key=$_apiKey',
    );

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
      '$_baseUrl/details/json?place_id=$placeId&fields=address_component,geometry/location,formatted_address&language=$_language&key=$_apiKey',
    );

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
      '$_baseUrl/autocomplete/json?input=$query&types=geocode&language=$_language&key=$_apiKey',
    );

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
      '$_baseUrl/details/json?place_id=$placeId&fields=geometry/location,formatted_address&language=$_language&key=$_apiKey',
    );

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
  // ⚽ 6️⃣ CANCHAS CERCA (Nearby Search - legacy)
  // ===============================================================
  /// Busca canchas cerca de una ubicación.
  ///
  /// - radiusMeters: radio en metros (Places legacy permite hasta 50,000)
  /// - keyword: por defecto usamos una combinación para mejor recall
  static Future<List<PitchPlace>> fetchNearbySoccerPitches({
    required double lat,
    required double lng,
    double radiusMeters = 4000,
    String keyword = 'cancha de futbol OR cancha sintética OR soccer field',
  }) async {
    // Guardrails
    if (radiusMeters < 500) radiusMeters = 500;
    if (radiusMeters > 50000) radiusMeters = 50000;

    final encodedKeyword = Uri.encodeComponent(keyword);

    final uri = Uri.parse(
      '$_baseUrl/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=${radiusMeters.toInt()}'
      '&keyword=$encodedKeyword'
      '&language=$_language'
      '&key=$_apiKey',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body) as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();

      // OK | ZERO_RESULTS | OVER_QUERY_LIMIT | REQUEST_DENIED | INVALID_REQUEST
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        print('⚠️ NearbySearch status=$status, error=${data['error_message']}');
        return [];
      }

      final results = (data['results'] as List? ?? []).cast<Map<String, dynamic>>();

      final pitches = <PitchPlace>[];
      for (final r in results) {
        final pid = (r['place_id'] ?? '').toString();
        final name = (r['name'] ?? '').toString();

        final loc = (r['geometry']?['location']) as Map<String, dynamic>?;
        final rlat = (loc?['lat'] as num?)?.toDouble();
        final rlng = (loc?['lng'] as num?)?.toDouble();

        if (pid.isEmpty || name.isEmpty || rlat == null || rlng == null) continue;

        final address = (r['vicinity'] ?? r['formatted_address'])?.toString();
        final rating = (r['rating'] as num?)?.toDouble();
        final userRatingsTotal = (r['user_ratings_total'] as num?)?.toInt();

        pitches.add(PitchPlace(
          placeId: pid,
          name: name,
          lat: rlat,
          lng: rlng,
          address: address,
          rating: rating,
          userRatingsTotal: userRatingsTotal,
        ));
      }

      return pitches;
    } catch (e) {
      print('⚠️ Error en fetchNearbySoccerPitches: $e');
      return [];
    }
  }

  // ===============================================================
  // 📞 7️⃣ Detalles de contacto (solo al tocar una cancha)
  // ===============================================================
  static Future<PlaceContactDetails?> getPlaceContactDetails(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    final uri = Uri.parse(
      '$_baseUrl/details/json'
      '?place_id=$placeId'
      '&fields=formatted_phone_number,international_phone_number,website,opening_hours/open_now'
      '&language=$_language'
      '&key=$_apiKey',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      if (status != 'OK') {
        print('⚠️ PlaceDetails status=$status, error=${data['error_message']}');
        return null;
      }

      final result = (data['result'] as Map<String, dynamic>?);
      if (result == null) return null;

      final phone = result['formatted_phone_number']?.toString();
      final intlPhone = result['international_phone_number']?.toString();
      final website = result['website']?.toString();
      final openNow = (result['opening_hours']?['open_now'] as bool?);

      return PlaceContactDetails(
        placeId: placeId,
        phone: phone,
        internationalPhone: intlPhone,
        website: website,
        openNow: openNow,
      );
    } catch (e) {
      print('⚠️ Error en getPlaceContactDetails: $e');
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
