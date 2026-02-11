import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';

/// ====================================================================
/// ⚙️ TeamService — Gestión completa de equipos por sala (Versión PRO++)
/// ====================================================================
/// - Crea equipos automáticos al generar una sala.
/// - Permite unirse, cambiarse o salir de equipos.
/// - Mantiene consistencia entre equipos, jugadores y sala global.
/// - Actualiza automáticamente `rooms/{roomId}/players/{uid}` con su teamId.
/// - Sincroniza lista `players[]` dentro del equipo.
/// - Registra logs detallados para auditoría y diagnóstico.
/// ====================================================================
class TeamService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔗 Colección de equipos dentro de una sala
  CollectionReference<Map<String, dynamic>> _teamsCol(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('teams');

  /// 🔗 Colección global de jugadores dentro de la sala
  CollectionReference<Map<String, dynamic>> _playersCol(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('players');

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
        roles: const {},
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
  // 🔁 Unirse o cambiar de equipo (sincronizado automáticamente)
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
    final playerRef = _playersCol(roomId).doc(uid);

    try {
      // 🧹 1. Eliminar usuario de todos los equipos previos
      final allTeams = await teamsRef.get();
      final batchRemove = _db.batch();
      for (final doc in allTeams.docs) {
        batchRemove.update(doc.reference, {
          'players': FieldValue.arrayRemove([uid]),
          'roles.$uid': FieldValue.delete(),
        });
      }
      await batchRemove.commit();

      // 🔍 2. Verificar existencia del equipo destino
      final targetSnap = await targetRef.get();
      if (!targetSnap.exists) return 'El equipo no existe.';
      final team = Team.fromMap(targetSnap.data()!);

      // ⚖️ 3. Validar capacidad
      if (team.hasPlayer(uid)) return 'Ya perteneces a este equipo.';
      final titulares = team.roles.values.where((r) => r == 'titular').length;
      final isFull = titulares >= team.maxPlayers;

      // ✅ 4. Determinar rol
      final role = isFull ? 'suplente' : 'titular';

      // ✅ 5. Agregar jugador al equipo
      await targetRef.update({
        'players': FieldValue.arrayUnion([uid]),
        'roles.$uid': role,
      });

      // ✅ 6. Crear o actualizar documento del jugador en subcolección "players"
      final userSnap = await _db.collection('users').doc(uid).get();
      final userData = userSnap.data() ?? {};

      await playerRef.set({
        'uid': uid,
        'teamId': teamId,
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
        // 👇 Datos visuales del perfil (para mostrar en la cancha)
        'name': userData['name'] ?? 'Jugador',
        'rank': userData['rank'] ?? 'Bronce',
        'avatar': userData['photoUrl'] ??
            userData['avatar'] ??
            'https://cdn-icons-png.flaticon.com/512/1077/1077012.png',
        'x': 0.5, // posición inicial genérica (centrada)
        'y': 0.5,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ 7. Actualizar lista global de jugadores en sala
      await roomRef.update({
        'players': FieldValue.arrayUnion([uid]),
      });

      // 💬 8. Registrar log del sistema
      await _registerSystemLog(
        roomId: roomId,
        message:
            'El jugador $uid se unió a ${team.name} como ${role.toUpperCase()}.',
      );

      return 'Te uniste correctamente al ${team.name} como ${role.toUpperCase()}';
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message ?? e.code}';
    } catch (e) {
      return 'Error al unirse: $e';
    }
  }

  // ------------------------------------------------------------------
  // 🚪 Salir del equipo actual (actualiza todo)
  // ------------------------------------------------------------------
  Future<void> leaveCurrentTeam(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final teams = await _teamsCol(roomId).get();
    final batch = _db.batch();

    // 🔹 1. Eliminar usuario de todos los equipos
    for (final doc in teams.docs) {
      batch.update(doc.reference, {
        'players': FieldValue.arrayRemove([uid]),
        'roles.$uid': FieldValue.delete(),
      });
    }

    // 🔹 2. Limpiar su documento en subcolección players
    final playerRef = _playersCol(roomId).doc(uid);
    batch.set(
        playerRef,
        {
          'teamId': null,
          'role': null,
          'leftAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    await batch.commit();

    // 💬 3. Log del sistema
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

    final playerRef = _playersCol(roomId).doc(uid);
    batch.set(
        playerRef,
        {
          'teamId': null,
          'role': null,
        },
        SetOptions(merge: true));

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
  // 🎮 ACCIONES ADMINISTRATIVAS (solo dueño de la sala)
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
      if (team.roles[uid] == 'titular') return 'Ya es titular.';

      final titulares = team.roles.values.where((r) => r == 'titular').length;
      if (titulares >= team.maxPlayers) {
        return 'El equipo ya tiene todos los titulares.';
      }

      await teamRef.update({'roles.$uid': 'titular'});
      await _playersCol(roomId)
          .doc(uid)
          .set({'role': 'titular'}, SetOptions(merge: true));

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
      await _playersCol(roomId)
          .doc(uid)
          .set({'role': 'suplente'}, SetOptions(merge: true));

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

      await _playersCol(roomId)
          .doc(uid)
          .set({'teamId': null, 'role': null}, SetOptions(merge: true));

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
