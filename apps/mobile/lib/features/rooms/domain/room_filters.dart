// lib/features/rooms/domain/room_filters.dart
import 'package:flutter/foundation.dart';

/// ===============================================================
/// 🎛️ RoomFilters — Objeto de filtros para búsqueda de salas
/// ===============================================================
/// - cityName: etiqueta legible de la ciudad objetivo (ej. "Bogotá, Colombia")
/// - cityLat / cityLng: coordenadas de la ciudad seleccionada
/// - cityCountryCode: país ISO-2 de la ciudad (ej. "CO", "ES", "FR")
/// - userLat / userLng: coordenadas del usuario (para radio o distancia)
/// - userCountryCode: país ISO-2 del usuario (para búsquedas locales)
/// - userSex: "masculino" | "femenino" | "mixto"
/// - radiusKm: radio máximo en km (por defecto 40)
/// - date: si está presente, filtra por el mismo día (00:00–23:59)
class RoomFilters {
  final String? cityName;
  final double? cityLat;
  final double? cityLng;
  final String? cityCountryCode; // 👈 nuevo campo global

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
    this.cityCountryCode,
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
    String? cityCountryCode,
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
      cityCountryCode: cityCountryCode ?? this.cityCountryCode,
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
    return 'RoomFilters(city=$cityName, cityCountry=$cityCountryCode, '
        'userCountry=$userCountryCode, userSex=$userSex, radiusKm=$radiusKm, date=$date)';
  }

  @override
  bool operator ==(Object other) {
    return other is RoomFilters &&
        other.cityName == cityName &&
        other.cityLat == cityLat &&
        other.cityLng == cityLng &&
        other.cityCountryCode == cityCountryCode &&
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
        cityCountryCode,
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
