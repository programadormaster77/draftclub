import 'package:cloud_firestore/cloud_firestore.dart';
import '../presentation/widgets/formation_field.dart';

/// ===============================================================
/// ⚙️ FormationService — Lógica de formación y asignación visual
/// ===============================================================
/// Este servicio convierte los datos de Firestore (jugadores,
/// equipos, suplentes) en una lista de `PlayerSlotData` para
/// mostrar en la cancha.
///
/// Se adapta automáticamente según el tipo de sala (5, 7, 9, 11)
/// y separa los jugadores titulares de los suplentes.
/// ===============================================================
class FormationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ============================================================
  /// 🔹 Genera las listas de jugadores titulares y suplentes
  /// ============================================================
  Future<FormationData> buildFormationFromRoom(
      String roomId, String teamId) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) {
      throw Exception('No se encontró la sala con ID $roomId');
    }

    final data = doc.data()!;
    final type = (data['type'] ?? 'futbol7').toString().toLowerCase();
    final int playersPerTeam = _parseTypeToNumber(type);

    final List<dynamic> playersRaw = (data['teams']?[teamId]?['players'] ?? []);
    final List<dynamic> substitutesRaw =
        (data['teams']?[teamId]?['substitutes'] ?? []);

    final players = await _mapPlayers(playersRaw);
    final substitutes = await _mapPlayers(substitutesRaw);

    return FormationData(
      playersPerTeam: playersPerTeam,
      players: players,
      substitutes: substitutes,
    );
  }

  /// ============================================================
  /// 🧭 Convierte el tipo de partido en número de jugadores
  /// ============================================================
  int _parseTypeToNumber(String type) {
    if (type.contains('5')) return 5;
    if (type.contains('7')) return 7;
    if (type.contains('9')) return 9;
    return 11;
  }

  /// ============================================================
  /// 🧠 Mapea documentos de usuarios a PlayerSlotData
  /// ============================================================
  Future<List<PlayerSlotData>> _mapPlayers(List<dynamic> rawList) async {
    if (rawList.isEmpty) return [];

    final List<PlayerSlotData> players = [];

    for (final uid in rawList) {
      try {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (!userDoc.exists) continue;

        final user = userDoc.data()!;
        players.add(
          PlayerSlotData(
            name: user['name'] ?? 'Jugador',
            photoUrl: user['photoUrl'],
            position: user['position'] ?? user['mainPosition'] ?? '',
          ),
        );
      } catch (e) {
        print('⚠️ Error al mapear jugador $uid: $e');
      }
    }

    return players;
  }
}

/// ===============================================================
/// 🧩 FormationData — Resultado combinado para renderizar
/// ===============================================================
class FormationData {
  final int playersPerTeam;
  final List<PlayerSlotData> players;
  final List<PlayerSlotData> substitutes;

  FormationData({
    required this.playersPerTeam,
    required this.players,
    required this.substitutes,
  });
}
