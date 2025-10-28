import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';

/// ====================================================================
/// ⚙️ TeamService — Gestión completa de equipos por sala
/// ====================================================================
/// - Crea equipos automáticos al generar una sala.
/// - Permite unirse, cambiarse o salir de equipos.
/// - Actualiza la lista global de jugadores de la sala.
/// - Streams en tiempo real para la UI.
/// - **Sin** transacciones problemáticas: lecturas antes de escrituras,
///   usando updates atómicos con FieldValue para evitar duplicados.
/// ====================================================================
class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Colección de equipos dentro de una sala
  CollectionReference<Map<String, dynamic>> _teamsCol(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('teams');

  // ------------------------------------------------------------------
  // 🏗️ Crear equipos por defecto (Equipo 1..N)
  // ------------------------------------------------------------------
  Future<void> initDefaultTeams({
    required String roomId,
    required int teams,
    required int playersPerTeam,
  }) async {
    final batch = _db.batch();
    for (int i = 1; i <= teams; i++) {
      final doc = _teamsCol(roomId).doc();
      final team = Team(
        id: doc.id,
        roomId: roomId,
        name: 'Equipo $i',
        players: const [],
        maxPlayers: playersPerTeam,
        color: _pickColor(i),
        createdAt: DateTime.now(),
      );
      batch.set(doc, team.toMap());
    }
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // 🔄 Stream en tiempo real de los equipos
  // ------------------------------------------------------------------
  Stream<List<Team>> streamTeams(String roomId) {
    return _teamsCol(roomId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Team.fromMap(d.data())).toList());
  }

  // ------------------------------------------------------------------
  // 🔍 Equipo actual de un usuario en la sala
  // ------------------------------------------------------------------
  Future<String?> getUserTeamId(String roomId, String uid) async {
    final snap = await _teamsCol(roomId).get();
    for (final d in snap.docs) {
      final players = List<String>.from(d.data()['players'] ?? []);
      if (players.contains(uid)) return d.id;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 🔁 Unirse o cambiar de equipo
  //   - Evita el error: "Transactions require all reads before writes"
  //   - Hace lecturas previas y luego escribe con updates atómicos.
  // ------------------------------------------------------------------
  Future<String> joinTeam({
    required String roomId,
    required String teamId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Usuario no autenticado';

    final roomRef = _db.collection('rooms').doc(roomId);
    final teamsRef = _teamsCol(roomId);
    final targetRef = teamsRef.doc(teamId);

    try {
      // 1) Quitar al usuario de cualquier equipo actual (lectura + writes simples)
      final allTeams = await teamsRef.get();
      final batch = _db.batch();
      for (final t in allTeams.docs) {
        batch.update(t.reference, {
          'players': FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();

      // 2) Leer estado del equipo destino
      final targetSnap = await targetRef.get();
      if (!targetSnap.exists) return 'El equipo no existe.';

      final data = targetSnap.data()!;
      final players = List<String>.from(data['players'] ?? []);
      final maxPlayers = (data['maxPlayers'] as int?) ?? 0;

      if (players.contains(uid)) return 'Ya perteneces a este equipo.';
      if (maxPlayers > 0 && players.length >= maxPlayers) {
        return 'Este equipo está lleno.';
      }

      // 3) Agregar al equipo destino (update atómico)
      await targetRef.update({
        'players': FieldValue.arrayUnion([uid]),
      });

      // 4) Mantener lista global de jugadores de la sala
      await roomRef.update({
        'players': FieldValue.arrayUnion([uid]),
      });

      return 'Te uniste correctamente al ${data['name'] ?? 'equipo'}.';
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message ?? e.code}';
    } catch (e) {
      return 'Error al unirse: $e';
    }
  }

  // ------------------------------------------------------------------
  // 🚪 Salir del equipo actual
  // ------------------------------------------------------------------
  Future<void> leaveCurrentTeam(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final teams = await _teamsCol(roomId).get();
    final batch = _db.batch();
    for (final d in teams.docs) {
      batch.update(d.reference, {
        'players': FieldValue.arrayRemove([uid]),
      });
    }
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // 🧼 Utilidad: limpiar al usuario de todos los equipos (para reasignación)
  // ------------------------------------------------------------------
  Future<void> removeUserFromAllTeams(String roomId, String uid) async {
    final teams = await _teamsCol(roomId).get();
    final batch = _db.batch();
    for (final d in teams.docs) {
      batch.update(d.reference, {
        'players': FieldValue.arrayRemove([uid]),
      });
    }
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // 🎨 Paleta de colores para equipos
  // ------------------------------------------------------------------
  String _pickColor(int i) {
    const palette = [
      '#3A86FF', // azul
      '#FF006E', // magenta
      '#FB5607', // naranja
      '#8338EC', // morado
      '#2EC4B6', // turquesa
      '#FFBE0B', // amarillo
    ];
    return palette[(i - 1) % palette.length];
  }
}
