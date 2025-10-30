// lib/features/rooms/domain/room_filters.dart
import 'package:flutter/foundation.dart';

/// ===============================================================
/// 🎛️ RoomFilters — Objeto de filtros para búsqueda de salas
/// ===============================================================
/// - cityName: etiqueta legible de la ciudad objetivo (ej. "Bogotá, Colombia")
/// - cityLat/cityLng: coordenadas de la ciudad (si están disponibles)
/// - userLat/userLng: coordenadas del usuario (para radio y orden por cercanía)
/// - userCountryCode: ISO-2 del país del usuario (ej. "CO")
/// - userSex: "masculino" | "femenino" | "mixto" (filtro mixto o mismo sexo)
/// - radiusKm: radio máximo en km (por defecto 40)
/// - date: si está presente, filtra por el mismo día (00:00–23:59)
class RoomFilters {
  final String? cityName;
  final double? cityLat;
  final double? cityLng;

  final double? userLat;
  final double? userLng;
  final String? userCountryCode;
  final String? userSex;

  final double radiusKm;
  final DateTime? date;

  const RoomFilters({
    this.cityName,
    this.cityLat,
    this.cityLng,
    this.userLat,
    this.userLng,
    this.userCountryCode,
    this.userSex,
    this.radiusKm = 40.0,
    this.date,
  });

  RoomFilters copyWith({
    String? cityName,
    double? cityLat,
    double? cityLng,
    double? userLat,
    double? userLng,
    String? userCountryCode,
    String? userSex,
    double? radiusKm,
    DateTime? date,
  }) {
    return RoomFilters(
      cityName: cityName ?? this.cityName,
      cityLat: cityLat ?? this.cityLat,
      cityLng: cityLng ?? this.cityLng,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      userCountryCode: userCountryCode ?? this.userCountryCode,
      userSex: userSex ?? this.userSex,
      radiusKm: radiusKm ?? this.radiusKm,
      date: date ?? this.date,
    );
  }

  @override
  String toString() {
    return 'RoomFilters(city=$cityName, userSex=$userSex, radiusKm=$radiusKm, date=$date, userCountry=$userCountryCode)';
  }

  @override
  bool operator ==(Object other) {
    return other is RoomFilters &&
        other.cityName == cityName &&
        other.cityLat == cityLat &&
        other.cityLng == cityLng &&
        other.userLat == userLat &&
        other.userLng == userLng &&
        other.userCountryCode == userCountryCode &&
        other.userSex == userSex &&
        other.radiusKm == radiusKm &&
        _sameDay(other.date, date);
  }

  @override
  int get hashCode => Object.hash(
        cityName,
        cityLat,
        cityLng,
        userLat,
        userLng,
        userCountryCode,
        userSex,
        radiusKm,
        date?.year,
      );

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
