import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../room_detail_page.dart';
import 'package:intl/intl.dart';

/// ====================================================================
/// 💠 RoomCard — Tarjeta reutilizable para mostrar una sala
/// ====================================================================
/// 🔹 Compatible con RoomModel (Firestore)
/// 🔹 Muestra: nombre, ciudad, fecha, distancia, género, cupos
/// 🔹 Navega a RoomDetailPage al tocarla
/// 🔹 Usa colores e íconos coherentes con el resto del sistema
/// ====================================================================
class RoomCard extends StatelessWidget {
  final Room room;
  final double? userLat;
  final double? userLng;
  final VoidCallback? onTap; // opcional, por si se usa fuera del listado

  const RoomCard({
    super.key,
    required this.room,
    this.userLat,
    this.userLng,
    this.onTap,
  });

  // ===============================================================
  // 📏 Calcular distancia (Haversine)
  // ===============================================================
  double? get distanceKm {
    if (userLat == null || userLng == null) return null;
    final lat = room.lat ?? room.cityLat;
    final lng = room.lng ?? room.cityLng;
    if (lat == null || lng == null) return null;

    const R = 6371.0;
    final dLat = _deg2rad(lat - userLat!);
    final dLon = _deg2rad(lng - userLng!);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_deg2rad(userLat!)) *
            cos(_deg2rad(lat)) *
            sin(dLon / 2) *
            sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (3.141592653589793 / 180);

  // ===============================================================
  // 🎨 Color según tipo de partido (sexo)
  // ===============================================================
  Color get sexColor {
    switch (room.sex?.toLowerCase()) {
      case 'masculino':
        return Colors.blueAccent;
      case 'femenino':
        return Colors.pinkAccent;
      default:
        return Colors.greenAccent;
    }
  }

  // ===============================================================
  // 📅 Fecha legible
  // ===============================================================
  String get formattedDate {
    if (room.eventAt == null) return 'Sin fecha';
    final df = DateFormat('dd/MM/yyyy – HH:mm');
    return df.format(room.eventAt!);
  }

  // ===============================================================
  // 💾 Cupos y estado
  // ===============================================================
  String get capacityLabel => '${room.players.length}/${room.maxPlayers} cupos';
  bool get isFull => room.isFull;

  // ===============================================================
  // 🧩 Construcción visual
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    final dist =
        distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : null;

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
            );
          },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -----------------------------------------------------
              // 🏷️ Título y distancia
              // -----------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (dist != null)
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 16, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(dist,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // -----------------------------------------------------
              // 📍 Ciudad + Fecha
              // -----------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.location_city,
                      size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      room.city,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // -----------------------------------------------------
              // 🚻 Género y visibilidad
              // -----------------------------------------------------
              Row(
                children: [
                  Icon(
                    room.isPublic ? Icons.public : Icons.lock,
                    size: 16,
                    color:
                        room.isPublic ? Colors.blueAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    room.isPublic ? 'Pública' : 'Privada',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.people, size: 16, color: sexColor),
                  const SizedBox(width: 6),
                  Text(
                    room.sex?.isNotEmpty == true
                        ? room.sex!.toUpperCase()
                        : 'MIXTO',
                    style: TextStyle(
                        color: sexColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // -----------------------------------------------------
              // 👥 Equipos y jugadores
              // -----------------------------------------------------
              Text(
                'Equipos: ${room.teams} | Jugadores/Equipo: ${room.playersPerTeam} | Cambios: ${room.substitutes}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 10),

              // -----------------------------------------------------
              // 📊 Cupos disponibles o lleno
              // -----------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    capacityLabel,
                    style: TextStyle(
                      color: isFull ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onTap ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RoomDetailPage(room: room)),
                          );
                        },
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Colors.blueAccent, size: 16),
                    label: const Text(
                      'Ver sala',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
