import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';

/// ====================================================================
/// ⚙️ TeamService — Gestión completa de equipos por sala
/// ====================================================================
/// - Crea equipos automáticos al generar una sala.
/// - Permite unirse, cambiarse o salir de equipos.
/// - Mantiene consistencia entre equipos y la sala global.
/// - Asigna roles dinámicos (titular / suplente) según disponibilidad.
/// - Streams optimizados en tiempo real para la UI.
/// - Registra eventos del sistema para auditoría.
/// ====================================================================
class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔗 Colección de equipos dentro de una sala
  CollectionReference<Map<String, dynamic>> _teamsCol(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('teams');

  // ------------------------------------------------------------------
  // 🏗️ Crear equipos iniciales (Equipo 1..N)
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
        roles: const {}, // ✅ Nuevo campo requerido
        maxPlayers: playersPerTeam,
        color: _pickColor(i),
        createdAt: DateTime.now(),
      );
      batch.set(doc, team.toMap());
    }
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // 🔄 Stream en tiempo real de equipos
  // ------------------------------------------------------------------
  Stream<List<Team>> streamTeams(String roomId) {
    return _teamsCol(roomId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Team.fromMap(doc.data())).toList());
  }

  // ------------------------------------------------------------------
  // 🔍 Obtener el equipo actual del usuario
  // ------------------------------------------------------------------
  Future<String?> getUserTeamId(String roomId, String uid) async {
    final snap = await _teamsCol(roomId).get();
    for (final doc in snap.docs) {
      final team = Team.fromMap(doc.data());
      if (team.roles.containsKey(uid)) return team.id;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 🔁 Unirse o cambiar de equipo con rol automático
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
      // 🧹 1. Eliminar al usuario de todos los equipos previos
      final allTeams = await teamsRef.get();
      final batchRemove = _db.batch();
      for (final doc in allTeams.docs) {
        batchRemove.update(doc.reference, {
          'players': FieldValue.arrayRemove([uid]),
          'roles.$uid': FieldValue.delete(),
        });
      }
      await batchRemove.commit();

      // 🔍 2. Leer equipo destino
      final targetSnap = await targetRef.get();
      if (!targetSnap.exists) return 'El equipo no existe.';

      final team = Team.fromMap(targetSnap.data()!);

      if (team.hasPlayer(uid)) return 'Ya perteneces a este equipo.';
      final isFull = team.titulares.length >= team.maxPlayers;

      // ✅ 3. Determinar rol del jugador (titular o suplente)
      final role = isFull ? 'suplente' : 'titular';

      // ✅ 4. Agregar jugador y su rol
      await targetRef.update({
        'players': FieldValue.arrayUnion([uid]),
        'roles.$uid': role,
      });

      // 🧾 5. Actualizar lista global de jugadores en la sala
      await roomRef.update({
        'players': FieldValue.arrayUnion([uid]),
      });

      // 💬 6. Registrar log del sistema
      await _registerSystemLog(
        roomId: roomId,
        message:
            'El jugador $uid se unió a ${team.name} como ${role.toUpperCase()}.',
      );

      return 'Te uniste correctamente al ${team.name} como ${role.toUpperCase()}.';
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
    for (final doc in teams.docs) {
      batch.update(doc.reference, {
        'players': FieldValue.arrayRemove([uid]),
        'roles.$uid': FieldValue.delete(),
      });
    }
    await batch.commit();

    await _registerSystemLog(
      roomId: roomId,
      message: 'El jugador $uid salió de su equipo.',
    );
  }

  // ------------------------------------------------------------------
  // 🧼 Eliminar manualmente un usuario de todos los equipos
  // ------------------------------------------------------------------
  Future<void> removeUserFromAllTeams(String roomId, String uid) async {
    final teams = await _teamsCol(roomId).get();
    final batch = _db.batch();
    for (final doc in teams.docs) {
      batch.update(doc.reference, {
        'players': FieldValue.arrayRemove([uid]),
        'roles.$uid': FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  // ------------------------------------------------------------------
  // 💬 Registrar logs del sistema
  // ------------------------------------------------------------------
  Future<void> _registerSystemLog({
    required String roomId,
    required String message,
  }) async {
    final roomLogsRef =
        _db.collection('rooms').doc(roomId).collection('system_logs');
    await roomLogsRef.add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'team_event',
    });
  }

  // ------------------------------------------------------------------
  // 🎨 Paleta de colores para equipos
  // ------------------------------------------------------------------
  String _pickColor(int i) {
    const palette = [
      '#3A86FF', // Azul
      '#FF006E', // Magenta
      '#FB5607', // Naranja
      '#8338EC', // Morado
      '#2EC4B6', // Turquesa
      '#FFBE0B', // Amarillo
      '#8AC926', // Verde lima
      '#FF595E', // Rojo coral
    ];
    return palette[(i - 1) % palette.length];
  }

// ------------------------------------------------------------------
// 🎮 ACCIONES ADMINISTRATIVAS (solo para el dueño de la sala)
// ------------------------------------------------------------------

  /// ✅ Mover jugador a TITULAR
  Future<String> promoteToStarter({
    required String roomId,
    required String teamId,
    required String uid,
  }) async {
    try {
      final teamRef = _teamsCol(roomId).doc(teamId);
      final teamSnap = await teamRef.get();
      if (!teamSnap.exists) return 'Equipo no encontrado.';

      final team = Team.fromMap(teamSnap.data()!);

      // Si ya es titular, no hacer nada
      if (team.roles[uid] == 'titular') return 'Ya es titular.';

      // Revisar si hay espacio disponible
      final titulares = team.roles.values.where((r) => r == 'titular').length;
      if (titulares >= team.maxPlayers) {
        return 'El equipo ya tiene todos los titulares.';
      }

      await teamRef.update({'roles.$uid': 'titular'});
      await _registerSystemLog(
        roomId: roomId,
        message: 'El jugador $uid fue promovido a TITULAR en ${team.name}.',
      );

      return 'Jugador promovido a TITULAR.';
    } catch (e) {
      return 'Error al promover: $e';
    }
  }

  /// 🔄 Mover jugador a SUPLENTE
  Future<String> demoteToBench({
    required String roomId,
    required String teamId,
    required String uid,
  }) async {
    try {
      final teamRef = _teamsCol(roomId).doc(teamId);
      final teamSnap = await teamRef.get();
      if (!teamSnap.exists) return 'Equipo no encontrado.';

      final team = Team.fromMap(teamSnap.data()!);

      if (team.roles[uid] == 'suplente') return 'Ya es suplente.';

      await teamRef.update({'roles.$uid': 'suplente'});
      await _registerSystemLog(
        roomId: roomId,
        message: 'El jugador $uid fue movido a SUPLENTE en ${team.name}.',
      );

      return 'Jugador movido a SUPLENTE.';
    } catch (e) {
      return 'Error al mover: $e';
    }
  }

  /// ❌ Expulsar jugador del equipo
  Future<String> removePlayerFromTeam({
    required String roomId,
    required String teamId,
    required String uid,
  }) async {
    try {
      final teamRef = _teamsCol(roomId).doc(teamId);
      final teamSnap = await teamRef.get();
      if (!teamSnap.exists) return 'Equipo no encontrado.';

      await teamRef.update({
        'players': FieldValue.arrayRemove([uid]),
        'roles.$uid': FieldValue.delete(),
      });

      await _registerSystemLog(
        roomId: roomId,
        message: 'El jugador $uid fue expulsado del equipo.',
      );

      return 'Jugador expulsado del equipo.';
    } catch (e) {
      return 'Error al expulsar: $e';
    }
  }
}
