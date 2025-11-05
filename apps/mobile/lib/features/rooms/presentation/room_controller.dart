// TODO Implement this library.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/room_service.dart';
import '../models/room_model.dart';

/// ===============================================================
/// 🎯 RoomController — Estado reactivo de las salas
/// ===============================================================
/// - Centraliza las salas públicas y su estado de carga.
/// - Reacciona automáticamente cuando se actualizan filtros o recargas.
/// - Integra RoomService.
/// ===============================================================

final roomControllerProvider =
    StateNotifierProvider<RoomController, RoomState>((ref) {
  return RoomController(RoomService());
});

/// ===============================================================
/// 🧱 RoomState — estructura del estado
/// ===============================================================
class RoomState {
  final bool isLoading;
  final List<Room> rooms;
  final String? error;

  const RoomState({
    this.isLoading = false,
    this.rooms = const [],
    this.error,
  });

  RoomState copyWith({
    bool? isLoading,
    List<Room>? rooms,
    String? error,
  }) {
    return RoomState(
      isLoading: isLoading ?? this.isLoading,
      rooms: rooms ?? this.rooms,
      error: error ?? this.error,
    );
  }
}

/// ===============================================================
/// ⚙️ RoomController — lógica de negocio reactiva
/// ===============================================================
class RoomController extends StateNotifier<RoomState> {
  final RoomService _service;

  RoomController(this._service) : super(const RoomState());

  /// 🔄 Carga o recarga las salas públicas
  Future<void> load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final rooms = await _service.getFilteredPublicRoomsAuto();
      state = state.copyWith(isLoading: false, rooms: rooms);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 🧹 Limpia estado (opcional)
  void clear() => state = const RoomState();
}
