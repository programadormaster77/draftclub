import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 🧩 Room Model — Representa una sala (pública o privada)
/// ====================================================================
/// 🔹 Totalmente compatible con Firestore.
/// 🔹 Incluye ubicación completa (ciudad, país, coordenadas, dirección exacta).
/// 🔹 Compatible con filtros inteligentes de cercanía, país y fecha.
/// 🔹 Ideal para integración con RoomService y RoomDetailPage.
/// ====================================================================
class Room {
  final String id;
  final String name;
  final int teams;
  final int playersPerTeam;
  final int substitutes;
  final bool isPublic;
  final String creatorId;
  final String city;
  final double? cityLat; // 🌍 Latitud de la ciudad
  final double? cityLng; // 🌍 Longitud de la ciudad
  final String? countryCode; // 🇨🇴 Código ISO del país
  final String? exactAddress; // 📍 Dirección exacta del partido
  final DateTime createdAt;
  final DateTime? eventAt; // 📅 Fecha/hora del partido
  final List<String> players; // 👥 Lista de jugadores en la sala

  Room({
    required this.id,
    required this.name,
    required this.teams,
    required this.playersPerTeam,
    required this.substitutes,
    required this.isPublic,
    required this.creatorId,
    required this.city,
    required this.createdAt,
    this.cityLat,
    this.cityLng,
    this.countryCode,
    this.exactAddress,
    this.eventAt,
    this.players = const [],
  });

  // ================================================================
  // 🔁 Conversión a mapa (para Firestore)
  // ================================================================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teams': teams,
      'playersPerTeam': playersPerTeam,
      'substitutes': substitutes,
      'isPublic': isPublic,
      'creatorId': creatorId,
      'city': city,
      if (cityLat != null) 'cityLat': cityLat,
      if (cityLng != null) 'cityLng': cityLng,
      if (countryCode != null) 'countryCode': countryCode,
      if (exactAddress != null && exactAddress!.isNotEmpty)
        'exactAddress': exactAddress,
      'createdAt': Timestamp.fromDate(createdAt),
      if (eventAt != null) 'eventAt': Timestamp.fromDate(eventAt!),
      'players': players,
    };
  }

  // ================================================================
  // 🧠 Crear instancia desde Firestore → Room
  // ================================================================
  factory Room.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    final createdField = map['createdAt'];

    if (createdField is Timestamp) {
      createdAt = createdField.toDate();
    } else if (createdField is String) {
      createdAt = DateTime.tryParse(createdField) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    DateTime? eventAt;
    final eventField = map['eventAt'];
    if (eventField is Timestamp) {
      eventAt = eventField.toDate();
    } else if (eventField is String) {
      eventAt = DateTime.tryParse(eventField);
    }

    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Room(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      teams: parseInt(map['teams']),
      playersPerTeam: parseInt(map['playersPerTeam']),
      substitutes: parseInt(map['substitutes']),
      isPublic: map['isPublic'] ?? false,
      creatorId: map['creatorId'] ?? '',
      city: map['city'] ?? 'Desconocido',
      cityLat: parseDouble(map['cityLat']),
      cityLng: parseDouble(map['cityLng']),
      countryCode: map['countryCode'],
      exactAddress: map['exactAddress'],
      createdAt: createdAt,
      eventAt: eventAt,
      players: List<String>.from(map['players'] ?? []),
    );
  }

  // ================================================================
  // 🧾 Copiar instancia con valores modificados
  // ================================================================
  Room copyWith({
    String? id,
    String? name,
    int? teams,
    int? playersPerTeam,
    int? substitutes,
    bool? isPublic,
    String? creatorId,
    String? city,
    double? cityLat,
    double? cityLng,
    String? countryCode,
    String? exactAddress,
    DateTime? createdAt,
    DateTime? eventAt,
    List<String>? players,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      teams: teams ?? this.teams,
      playersPerTeam: playersPerTeam ?? this.playersPerTeam,
      substitutes: substitutes ?? this.substitutes,
      isPublic: isPublic ?? this.isPublic,
      creatorId: creatorId ?? this.creatorId,
      city: city ?? this.city,
      cityLat: cityLat ?? this.cityLat,
      cityLng: cityLng ?? this.cityLng,
      countryCode: countryCode ?? this.countryCode,
      exactAddress: exactAddress ?? this.exactAddress,
      createdAt: createdAt ?? this.createdAt,
      eventAt: eventAt ?? this.eventAt,
      players: players ?? this.players,
    );
  }

  // ================================================================
  // 🧩 Métodos utilitarios (para UI y lógica)
  // ================================================================
  int get maxPlayers => (teams * playersPerTeam) + substitutes;
  bool get isFull => players.length >= maxPlayers;
  bool containsPlayer(String userId) => players.contains(userId);

  /// Devuelve una versión amigable de la fecha del partido
  String get formattedEventDate {
    if (eventAt == null) return 'Sin fecha';
    final e = eventAt!;
    return '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
  }

  /// Retorna `true` si tiene coordenadas válidas
  bool get hasLocation => cityLat != null && cityLng != null;
}
