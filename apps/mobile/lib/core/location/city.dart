// lib/core/location/city.dart

/// Representa una ciudad seleccionada por el usuario, con nombre y coordenadas.
class City {
  final String name; // Ej: "Bogotá, Colombia"
  final double? lat; // Latitud
  final double? lng; // Longitud
  final String? placeId; // ID del lugar en Google Places

  const City({
    required this.name,
    this.lat,
    this.lng,
    this.placeId,
  });

  String get display => name;

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'placeId': placeId,
      };

  factory City.fromMap(Map<String, dynamic> map) => City(
        name: (map['name'] ?? '') as String,
        lat: (map['lat'] is num) ? (map['lat'] as num).toDouble() : null,
        lng: (map['lng'] is num) ? (map['lng'] as num).toDouble() : null,
        placeId: map['placeId'] as String?,
      );
}
