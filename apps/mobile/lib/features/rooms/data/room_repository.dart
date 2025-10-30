// lib/features/rooms/data/room_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/room_filters.dart';
import '../models/room_model.dart';
import 'room_service.dart';

/// =====================================================================
/// 🧠 RoomRepository — Capa intermedia entre UI y RoomService
/// =====================================================================
/// Encargada de:
/// - Coordinar lecturas/escrituras de Firestore.
/// - Aplicar RoomFilters coherentemente.
/// - Unificar resultados de varias fuentes (ej: Firestore + APIs futuras).
/// - Servir como punto único para el manejo de salas.
///
/// Esto deja `RoomService` como capa de bajo nivel
/// y `RoomsPage` como capa de presentación ligera.
/// =====================================================================
class RoomRepository {
  final RoomService _service = RoomService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene las salas públicas según filtros dinámicos.
  /// Incluye lógica para restringir por país, sexo, distancia, etc.
  Future<List<Room>> getPublicRooms(RoomFilters filters) async {
    final rooms = await _service.getFilteredPublicRooms(
      cityName: filters.cityName,
      userLat: filters.userLat,
      userLng: filters.userLng,
      userCountryCode: filters.userCountryCode,
      userSex: filters.userSex,
      radiusKm: filters.radiusKm,
      targetDate: filters.date,
    );

    // Filtra por sexo: mixto o mismo sexo
    final userSex = (filters.userSex ?? 'mixto').toLowerCase();
    final filtered = rooms.where((r) {
      final s = (r.sex ?? 'mixto').toLowerCase();
      return s == 'mixto' || s == userSex;
    }).toList();

    return filtered;
  }

  /// Obtiene las salas en las que el usuario está unido o ha creado.
  Stream<List<Room>> getMyRooms() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('rooms')
        .where('players', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Room.fromMap(d.data())).toList());
  }

  /// Crea o actualiza una sala
  Future<void> saveRoom(Room room) async {
    await _db.collection('rooms').doc(room.id).set(room.toMap());
  }

  /// Elimina una sala
  Future<void> deleteRoom(String roomId) async {
    await _db.collection('rooms').doc(roomId).delete();
  }
}
