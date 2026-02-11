import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 🧩 Room Model — Representa una sala (pública o privada)
/// ====================================================================
/// 🔹 Compatible con Firestore.
/// 🔹 Incluye ubicación completa (ciudad, país, coordenadas, dirección exacta).
/// 🔹 Añadido campo `sex` (Masculino / Femenino / Mixto).
/// 🔹 Ahora incluye soporte para cierre de partido y ganador.
/// 🔹 TOTALMENTE compatible con tu base de datos actual.
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

  // 🌍 Coordenadas de la ciudad
  final double? cityLat;
  final double? cityLng;

  // 📍 Coordenadas exactas
  final double? lat;
  final double? lng;

  final String? countryCode;
  final String? exactAddress;
  final String? sex;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? eventAt;
  final List<String> players;

  // 🆕 NUEVOS CAMPOS (para sistema de cierre y resultados)
  final bool isClosed; // partido ya cerrado
  final String? winnerTeamId; // id del equipo ganador
  final String? winnerTeamName; // nombre visible del equipo ganador
  final DateTime? closedAt; // fecha/hora de cierre

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
    this.lat,
    this.lng,
    this.countryCode,
    this.exactAddress,
    this.sex,
    this.eventAt,
    this.updatedAt,
    this.players = const [],
    this.isClosed = false, // por defecto NO está cerrada
    this.winnerTeamId,
    this.winnerTeamName,
    this.closedAt,
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
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (countryCode != null) 'countryCode': countryCode,
      if (exactAddress != null && exactAddress!.isNotEmpty)
        'exactAddress': exactAddress,
      if (sex != null && sex!.isNotEmpty) 'sex': sex,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (eventAt != null) 'eventAt': Timestamp.fromDate(eventAt!),
      'players': players,

      // 🆕 NUEVOS CAMPOS
      'isClosed': isClosed,
      if (winnerTeamId != null) 'winnerTeamId': winnerTeamId,
      if (winnerTeamName != null) 'winnerTeamName': winnerTeamName,
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
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

    DateTime? updatedAt;
    final updatedField = map['updatedAt'];
    if (updatedField is Timestamp) {
      updatedAt = updatedField.toDate();
    } else if (updatedField is String) {
      updatedAt = DateTime.tryParse(updatedField);
    }

    DateTime? eventAt;
    final eventField = map['eventAt'];
    if (eventField is Timestamp) {
      eventAt = eventField.toDate();
    } else if (eventField is String) {
      eventAt = DateTime.tryParse(eventField);
    }

    DateTime? closedAt;
    final closedField = map['closedAt'];
    if (closedField is Timestamp) {
      closedAt = closedField.toDate();
    } else if (closedField is String) {
      closedAt = DateTime.tryParse(closedField);
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
      id: (map['id'] ?? '').toString(),
      name: map['name'] ?? '',
      teams: parseInt(map['teams']),
      playersPerTeam: parseInt(map['playersPerTeam']),
      substitutes: parseInt(map['substitutes']),
      isPublic: map['isPublic'] ?? false,
      creatorId: map['creatorId'] ?? '',
      city: map['city'] ?? map['ciudad'] ?? 'Desconocido',
      cityLat: parseDouble(map['cityLat']),
      cityLng: parseDouble(map['cityLng']),
      lat: parseDouble(map['lat']),
      lng: parseDouble(map['lng']),
      countryCode: (map['countryCode'] ?? map['country'])?.toString(),
      exactAddress: map['exactAddress'],
      sex: (map['sex'] ?? 'Mixto').toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      eventAt: eventAt,
      players: List<String>.from(map['players'] ?? []),

      // 🆕 NUEVOS CAMPOS
      isClosed: map['isClosed'] ?? false,
      winnerTeamId: map['winnerTeamId'],
      winnerTeamName: map['winnerTeamName'],
      closedAt: closedAt,
    );
  }

    /// ================================================================
  /// 📌 Factory seguro: usa doc.id como id real del documento
  /// ================================================================
  factory Room.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Room.fromMap({
      ...data,
      'id': doc.id,
    });
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
    double? lat,
    double? lng,
    String? countryCode,
    String? exactAddress,
    String? sex,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? eventAt,
    List<String>? players,

    // nuevos
    bool? isClosed,
    String? winnerTeamId,
    String? winnerTeamName,
    DateTime? closedAt,
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
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      countryCode: countryCode ?? this.countryCode,
      exactAddress: exactAddress ?? this.exactAddress,
      sex: sex ?? this.sex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      eventAt: eventAt ?? this.eventAt,
      players: players ?? this.players,

      // nuevos
      isClosed: isClosed ?? this.isClosed,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      winnerTeamName: winnerTeamName ?? this.winnerTeamName,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  // ================================================================
  // 🧩 Métodos utilitarios
  // ================================================================
  int get maxPlayers => (teams * playersPerTeam) + substitutes;
  bool get isFull => players.length >= maxPlayers;
  bool containsPlayer(String userId) => players.contains(userId);

  bool get hasResult => isClosed && winnerTeamId != null;

  String get formattedEventDate {
    if (eventAt == null) return 'Sin fecha';
    final e = eventAt!;
    return '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}';
  }

  bool get hasLocation =>
      (lat != null && lng != null) || (cityLat != null && cityLng != null);

  @override
  String toString() =>
      'Room($name, ciudad: $city, sexo: $sex, pública: $isPublic, cerrada: $isClosed)';
}
