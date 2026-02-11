// lib/features/rooms/presentation/room_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../rooms/data/room_service.dart';
import '../../rooms/data/team_service.dart';
import '../../rooms/models/room_model.dart';

/// ===============================================================
/// 🎮 RoomController — Gestor lógico de salas (vincula UI ↔ Servicios)
/// ===============================================================
/// ✅ Usa Riverpod para gestionar estado reactivo.
/// ✅ Llama internamente a RoomService y TeamService.
/// ✅ Simplifica el uso desde la UI: rooms_page, create_room_page, etc.
/// ===============================================================

final roomControllerProvider = StateNotifierProvider<RoomController, RoomState>(
  (ref) => RoomController(
    roomService: RoomService(),
    teamService: TeamService(),
  ),
);

/// ===============================================================
/// 🧩 Estado reactivo del controlador
/// ===============================================================
class RoomState {
  final bool isLoading;
  final String? error;
  final List<Room> rooms;
  final Room? selectedRoom;

  const RoomState({
    this.isLoading = false,
    this.error,
    this.rooms = const [],
    this.selectedRoom,
  });

  RoomState copyWith({
    bool? isLoading,
    String? error,
    List<Room>? rooms,
    Room? selectedRoom,
  }) {
    return RoomState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      rooms: rooms ?? this.rooms,
      selectedRoom: selectedRoom ?? this.selectedRoom,
    );
  }
}

/// ===============================================================
/// 🧭 Controlador principal de Salas
/// ===============================================================
class RoomController extends StateNotifier<RoomState> {
  final RoomService roomService;
  final TeamService teamService;

  RoomController({
    required this.roomService,
    required this.teamService,
  }) : super(const RoomState());

  /// =============================================================
  /// 🔄 Cargar salas públicas cercanas
  /// =============================================================
  Future<void> loadPublicRooms({
    double radiusKm = 40,
    DateTime? targetDate,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final rooms = await roomService.getFilteredPublicRoomsAuto(
        radiusKm: radiusKm,
        targetDate: targetDate,
      );
      state = state.copyWith(isLoading: false, rooms: rooms);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar salas: $e',
      );
    }
  }

  /// =============================================================
  /// 🏗️ Crear una nueva sala
  /// =============================================================
  Future<void> createRoom({
    required String name,
    required int teams,
    required int playersPerTeam,
    required int substitutes,
    required bool isPublic,
    String? manualCity,
    double? cityLat,
    double? cityLng,
    double? lat,
    double? lng,
    String? countryCode,
    DateTime? eventAt,
    String? exactAddress,
    String? sex,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final roomId = await roomService.createRoom(
        name: name,
        teams: teams,
        playersPerTeam: playersPerTeam,
        substitutes: substitutes,
        isPublic: isPublic,
        manualCity: manualCity,
        cityLat: cityLat,
        cityLng: cityLng,
        lat: lat,
        lng: lng,
        countryCode: countryCode,
        eventAt: eventAt,
        exactAddress: exactAddress,
        sex: sex,
      );

      final room = await roomService.getRoomById(roomId);
      if (room != null) {
        final updatedRooms = [room, ...state.rooms];
        state = state.copyWith(
          isLoading: false,
          rooms: updatedRooms,
          selectedRoom: room,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al crear la sala: $e',
      );
    }
  }

  /// =============================================================
  /// 👥 Unirse a una sala
  /// =============================================================
  Future<String> joinRoom(String roomId) async {
    try {
      final result = await roomService.joinRoom(roomId);
      await refreshRoom(roomId);
      return result;
    } catch (e) {
      return 'Error al unirse: $e';
    }
  }

  /// =============================================================
  /// 🚪 Salir de una sala
  /// =============================================================
  Future<String> leaveRoom(String roomId) async {
    try {
      final result = await roomService.leaveRoom(roomId);
      await refreshRoom(roomId);
      return result;
    } catch (e) {
      return 'Error al salir: $e';
    }
  }

  /// =============================================================
  /// ✏️ Actualizar datos de una sala
  /// =============================================================
  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    try {
      await roomService.updateRoom(roomId, updates);
      await refreshRoom(roomId);
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar sala: $e');
    }
  }

  /// =============================================================
  /// ❌ Eliminar una sala
  /// =============================================================
  Future<void> deleteRoom(String roomId) async {
    try {
      await roomService.deleteRoom(roomId);
      final updated = state.rooms.where((r) => r.id != roomId).toList();
      state = state.copyWith(rooms: updated);
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar sala: $e');
    }
  }

  /// =============================================================
  /// 🔁 Refrescar sala individual
  /// =============================================================
  Future<void> refreshRoom(String roomId) async {
    try {
      final updated = await roomService.getRoomById(roomId);
      if (updated != null) {
        final updatedList = state.rooms.map((r) {
          return r.id == updated.id ? updated : r;
        }).toList();

        state = state.copyWith(
          rooms: updatedList,
          selectedRoom: updated,
        );
      }
    } catch (e) {
      // no rompe la UI
    }
  }

  /// =============================================================
  /// 🔥 Stream en tiempo real de una sala
  /// =============================================================
  Stream<Room?> streamRoom(String roomId) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((snap) => snap.exists ? Room.fromMap(snap.data()!) : null);
  }

  /// =============================================================
  /// 🔥 Stream de todas las salas públicas
  /// =============================================================
  Stream<List<Room>> streamPublicRooms() {
    return FirebaseFirestore.instance
        .collection('rooms')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) =>
            query.docs.map((doc) => Room.fromMap(doc.data())).toList());
  }

  Future<void> setRooms(List<Room> rooms) async {}
}
