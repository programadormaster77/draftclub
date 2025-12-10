import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/room_model.dart';
import 'team_service.dart';

// ✅ Helpers centralizados (manténlos si existen)
import '../../../core/utils/string_utils.dart'
    show normalizeText, toIso2OrGuess;

/// ====================================================================
/// ⚙️ RoomService — Gestión central de salas en Firestore (GLOBAL)
/// ====================================================================
class RoomService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RoomService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ===================================================================
  // 🧩 Encapsulados de colecciones / docs
  // ===================================================================
  CollectionReference<Map<String, dynamic>> get _roomsCol =>
      _firestore.collection('rooms');

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _roomsCol.doc(roomId);

  /// ============================================================
  /// 🧩 Sincronizar cantidad de equipos tras editar la sala
  /// ============================================================
  Future<void> syncTeamsCount({
    required String roomId,
    required int newTeams,
  }) async {
    final col = _firestore.collection('rooms').doc(roomId).collection('teams');

    // Traemos los equipos actuales
    final snap = await col.orderBy('index', descending: false).get();
    final existing = snap.docs;
    final currentCount = existing.length;

    // 👉 Si el número no cambió, no hacemos nada
    if (currentCount == newTeams) return;

    // 🟩 CASO 1: necesitamos MÁS equipos (añadir)
    if (newTeams > currentCount) {
      for (int i = currentCount + 1; i <= newTeams; i++) {
        await col.add({
          'name': 'Equipo $i',
          'index': i,
          'createdAt': FieldValue.serverTimestamp(),
          // si ya usas players en tus docs, dejamos la lista vacía
          'players': <String>[],
        });
      }
      return;
    }

    // 🟥 CASO 2: hay equipos de MÁS (opcional: eliminar los últimos vacíos)
    if (newTeams < currentCount) {
      // Ordenamos por index y borramos solo los que estén "sobrando" y sin jugadores
      for (final doc in existing.reversed) {
        final data = doc.data();
        final idx = (data['index'] ?? 0) as int;
        final players = (data['players'] as List?) ?? const [];

        if (idx > newTeams && players.isEmpty) {
          await doc.reference.delete();
        }
      }
    }
  }

  // ===================================================================
  // 🏗️ Crear una nueva sala + equipos automáticos
  // ===================================================================
  Future<String> createRoom({
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final roomId = const Uuid().v4();

    // Ciudad base
    String city = (manualCity ?? '').trim();
    if (city.contains(',')) city = city.split(',').first.trim();
    if (city.isEmpty) city = 'Desconocido';

    // Coordenadas base
    double? finalLat = lat ?? cityLat;
    double? finalLng = lng ?? cityLng;

    // País ISO-2
    String? country = _toIsoFromName(countryCode);

    // Sexo
    String finalSex = (sex ?? '').trim().toLowerCase();
    if (finalSex.isEmpty) finalSex = 'mixto';

    // 1️⃣ Enriquecer con perfil del usuario
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        finalSex = (data['sex'] ?? finalSex).toString().toLowerCase();

        // Si no viene ciudad manual, usa la del perfil
        if (manualCity == null || manualCity.isEmpty) {
          final userCity = data['city'] ?? data['ciudad'];
          if (userCity != null && userCity.toString().isNotEmpty) {
            city = userCity.toString().split(',').first.trim();
          }
        }

        country ??= _toIsoFromName(data['countryCode']);
        finalLat ??= (data['lat'] as num?)?.toDouble();
        finalLng ??= (data['lng'] as num?)?.toDouble();
      }
    } catch (_) {}

    // 2️⃣ Si faltan datos, intenta geolocalizar
    if ((manualCity == null || manualCity.isEmpty) ||
        (finalLat == null || finalLng == null)) {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
            );
            final placemarks =
                await placemarkFromCoordinates(pos.latitude, pos.longitude);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              city = (p.locality ?? city).toString();
              country ??= _toIsoFromName(p.isoCountryCode);
            }
            finalLat ??= pos.latitude;
            finalLng ??= pos.longitude;
          }
        }
      } catch (_) {}
    }

    // 3️⃣ Construir modelo
    final now = DateTime.now();
    final room = Room(
      id: roomId,
      name: name.trim(),
      teams: teams,
      playersPerTeam: playersPerTeam,
      substitutes: substitutes,
      isPublic: isPublic,
      creatorId: uid,
      city: city,
      createdAt: now,
      updatedAt: now,
      eventAt: eventAt,
      cityLat: cityLat ?? finalLat,
      cityLng: cityLng ?? finalLng,
      lat: finalLat,
      lng: finalLng,
      countryCode: country,
      exactAddress: exactAddress,
      sex: finalSex,
      players: const [],
    );

    // 4️⃣ Persistir sala y crear equipos base
    await _roomsCol.doc(roomId).set({
      ...room.toMap(),
      'players': [uid],
      if (eventAt != null) 'eventAt': Timestamp.fromDate(eventAt),
      if (exactAddress != null && exactAddress.isNotEmpty)
        'exactAddress': exactAddress,
      if (finalLat != null && finalLng != null) ...{
        'lat': finalLat,
        'lng': finalLng,
        'cityLat': cityLat ?? finalLat,
        'cityLng': cityLng ?? finalLng,
      },
      if (country != null && country.isNotEmpty) 'countryCode': country,
      'sex': finalSex,
    });

    // 5️⃣ Crear equipos
    final teamService = TeamService();
    await teamService.initDefaultTeams(
      roomId: roomId,
      teams: teams,
      playersPerTeam: playersPerTeam,
    );

    return roomId;
  }

  // ===================================================================
  // 🔁 Cambiar visibilidad
  // ===================================================================
  Future<void> toggleVisibility(String roomId, bool isPublic) async {
    try {
      await _roomRef(roomId).update({
        'isPublic': isPublic,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al cambiar visibilidad: $e');
    }
  }

  // ===================================================================
  // 🔧 Asegurar ciudad/país/coords del usuario (perfil geo)
  // ===================================================================
  Future<
      ({
        String? city,
        String? countryCode,
        double? lat,
        double? lng,
        String? sex
      })> _ensureUserGeoProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    String? city;
    String? country;
    double? lat;
    double? lng;
    String? sex;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final d = userDoc.data()!;
        city = d['city'] ?? d['ciudad'];
        country = _toIsoFromName(d['countryCode']);
        lat = (d['lat'] as num?)?.toDouble();
        lng = (d['lng'] as num?)?.toDouble();
        sex = (d['sex'] ?? 'mixto').toString().toLowerCase();
      }
    } catch (_) {}

    if (lat == null || lng == null) {
      try {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) {
          var perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
            );
            lat = pos.latitude;
            lng = pos.longitude;

            try {
              final ps = await placemarkFromCoordinates(lat!, lng!);
              if (ps.isNotEmpty) {
                final p = ps.first;
                city ??= p.locality;
                country ??= _toIsoFromName(p.isoCountryCode);
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    return (city: city, countryCode: country, lat: lat, lng: lng, sex: sex);
  }

  // ===================================================================
  // 📍 Listado automático de salas cerca del usuario
  // ===================================================================
  Future<List<Room>> getFilteredPublicRoomsAuto({
    double radiusKm = 40,
    DateTime? targetDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    try {
      final profile = await _ensureUserGeoProfile();
      if (profile.lat == null || profile.lng == null) return [];

      final rooms = await getFilteredPublicRooms(
        cityName: profile.city,
        userLat: profile.lat,
        userLng: profile.lng,
        userCountryCode: profile.countryCode,
        userSex: profile.sex,
        radiusKm: radiusKm,
        targetDate: targetDate,
      );

      // Orden por distancia y fecha
      rooms.sort((a, b) {
        final da = _distanceKm(
          profile.lat!,
          profile.lng!,
          (a.lat ?? a.cityLat ?? 0),
          (a.lng ?? a.cityLng ?? 0),
        );
        final db = _distanceKm(
          profile.lat!,
          profile.lng!,
          (b.lat ?? b.cityLat ?? 0),
          (b.lng ?? b.cityLng ?? 0),
        );
        if (da != db) return da.compareTo(db);
        if (a.eventAt != null && b.eventAt != null) {
          final cmp = a.eventAt!.compareTo(b.eventAt!);
          if (cmp != 0) return cmp;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return rooms;
    } catch (_) {
      return [];
    }
  }

  // ===================================================================
  // 📍 Filtro global (país/ciudad/radio)
  // ===================================================================
  Future<List<Room>> getFilteredPublicRooms({
    String? cityName,
    double? cityLat,
    double? cityLng,
    double? userLat,
    double? userLng,
    String? userCountryCode,
    String? userSex,
    double radiusKm = 40,
    DateTime? targetDate,
    String? cityCountryCode,
  }) async {
    try {
      final snap = await _roomsCol
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      List<Room> rooms =
          snap.docs.map((doc) => Room.fromMap(doc.data())).toList();

      // 1️⃣ Filtro por fecha
      if (targetDate != null) {
        final start =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        final end = start.add(const Duration(days: 1));
        rooms = rooms
            .where((r) =>
                r.eventAt != null &&
                r.eventAt!.isAfter(start) &&
                r.eventAt!.isBefore(end))
            .toList();
      }

      // 2️⃣ Filtro por país
      String? isoForFilter;
      if ((cityName != null && cityName.trim().isNotEmpty) &&
          (cityCountryCode != null && cityCountryCode.isNotEmpty)) {
        isoForFilter = _toIsoFromName(cityCountryCode);
      } else if (cityName == null || cityName.trim().isEmpty) {
        isoForFilter = _toIsoFromName(userCountryCode);
      }

      if (isoForFilter != null && isoForFilter.isNotEmpty) {
        final iso = isoForFilter.toUpperCase();
        rooms = rooms.where((r) {
          final rc = _toIsoFromName(r.countryCode ?? '');
          if (rc == null || rc.isEmpty) return true;
          return rc.toUpperCase() == iso;
        }).toList();
      }

      // 3️⃣ Filtro por ciudad / radio
      if (cityName != null && cityName.trim().isNotEmpty) {
        final wanted = normalizeText(cityName.split(',').first);
        rooms = rooms.where((r) {
          final roomCity = normalizeText(r.city.split(',').first);
          final sameCity = roomCity == wanted;

          final hasCoords = (r.cityLat != null &&
              r.cityLng != null &&
              cityLat != null &&
              cityLng != null);
          final nearby = hasCoords
              ? _distanceKm(cityLat!, cityLng!, r.cityLat!, r.cityLng!) <=
                  radiusKm
              : false;

          final sameCountry = (cityCountryCode != null && r.countryCode != null)
              ? (r.countryCode!.toUpperCase() == cityCountryCode.toUpperCase())
              : true;

          return sameCountry && (sameCity || nearby);
        }).toList();
      } else if (userLat != null && userLng != null) {
        rooms = rooms.where((r) {
          final lat = r.lat ?? r.cityLat;
          final lng = r.lng ?? r.cityLng;
          if (lat == null || lng == null) return false;
          return _distanceKm(userLat, userLng, lat, lng) <= radiusKm;
        }).toList();
      }

      // 4️⃣ Sexo
      if (userSex != null && userSex.isNotEmpty) {
        final u = userSex.toLowerCase();
        rooms = rooms.where((r) {
          final s = (r.sex ?? 'mixto').toLowerCase();
          return s == 'mixto' || s == u;
        }).toList();
      }

      // 5️⃣ Orden
      if (userLat != null && userLng != null) {
        rooms.sort((a, b) {
          final da = _distanceKm(
            userLat,
            userLng,
            (a.lat ?? a.cityLat ?? 0),
            (a.lng ?? a.cityLng ?? 0),
          );
          final db = _distanceKm(
            userLat,
            userLng,
            (b.lat ?? b.cityLat ?? 0),
            (b.lng ?? b.cityLng ?? 0),
          );
          if (da != db) return da.compareTo(db);
          return b.createdAt.compareTo(a.createdAt);
        });
      } else {
        rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return rooms;
    } catch (_) {
      return [];
    }
  }

  // ===================================================================
  // 👥 Unirse / salir
  // ===================================================================
  Future<String> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final ref = _roomRef(roomId);

    return _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('La sala no existe');

      final data = doc.data()!;
      final players = List<String>.from(data['players'] ?? <String>[]);
      final teams = (data['teams'] ?? 0) as int;
      final playersPerTeam = (data['playersPerTeam'] ?? 0) as int;
      final substitutes = (data['substitutes'] ?? 0) as int;
      final maxPlayers = (teams * playersPerTeam) + substitutes;

      if (players.contains(uid)) return 'Ya estás en esta sala.';
      if (players.length >= maxPlayers) return 'La sala ya está llena.';

      players.add(uid);
      tx.update(ref, {
        'players': players,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return 'Te uniste correctamente.';
    });
  }

  Future<String> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final ref = _roomRef(roomId);

    return _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('La sala no existe');

      final data = doc.data()!;
      final players = List<String>.from(data['players'] ?? <String>[]);

      if (!players.contains(uid)) return 'No estás en esta sala.';

      players.remove(uid);
      tx.update(ref, {
        'players': players,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return 'Saliste correctamente de la sala.';
    });
  }

  // ===================================================================
  // ✏️ Actualizar / eliminar / obtener
  // ===================================================================
  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    final sanitized = Map<String, dynamic>.from(updates)
      ..remove('id')
      ..remove('creatorId');

    if (sanitized.containsKey('city')) {
      final v = sanitized['city'];
      if (v is String && v.contains(',')) {
        sanitized['city'] = v.split(',').first.trim();
      }
    }
    if (sanitized.containsKey('sex')) {
      sanitized['sex'] =
          (sanitized['sex']?.toString().toLowerCase() ?? 'mixto');
    }
    if (sanitized.containsKey('eventAt') && sanitized['eventAt'] is DateTime) {
      sanitized['eventAt'] = Timestamp.fromDate(sanitized['eventAt']);
    }

    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    await _roomRef(roomId).update(sanitized);
  }

  Future<Room?> getRoomById(String roomId) async {
    final doc = await _roomRef(roomId).get();
    if (!doc.exists) return null;
    return Room.fromMap(doc.data()!);
  }

  Future<void> deleteRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final d = await _roomRef(roomId).get();
    if (!d.exists) throw Exception('La sala no existe');

    final data = d.data()!;
    if (data['creatorId'] != uid) {
      throw Exception('Solo el creador puede eliminar la sala.');
    }

    final batch = _firestore.batch();
    final teamsCol = _roomRef(roomId).collection('teams');
    final logsCol = _roomRef(roomId).collection('system_logs');

    try {
      final teams = await teamsCol.get();
      for (final t in teams.docs) {
        batch.delete(t.reference);
      }
    } catch (_) {}

    try {
      final logs = await logsCol.get();
      for (final l in logs.docs) {
        batch.delete(l.reference);
      }
    } catch (_) {}

    batch.delete(_roomRef(roomId));
    await batch.commit();
  }

  // ===================================================================
  // 🏁 Cerrar partido + crear notificaciones de resultado por jugador
  // ===================================================================
  Future<void> closeMatchAndCreateResultNotifications({
    required String roomId,
    required String winnerTeamId,
    required String winnerTeamName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    // 1️⃣ Traer la sala
    final roomSnap = await _roomRef(roomId).get();
    if (!roomSnap.exists) {
      throw Exception('La sala no existe');
    }

    final room = Room.fromMap(roomSnap.data()!);

    // 2️⃣ Validar permisos (solo creador por ahora)
    if (room.creatorId != uid) {
      throw Exception('Solo el creador de la sala puede cerrarla.');
    }

    // 3️⃣ Evitar doble cierre
    if (room.isClosed) {
      throw Exception('Esta sala ya está cerrada.');
    }

    // 4️⃣ Cargar equipos y jugadores de la sala
    final teamsSnap = await _roomRef(roomId).collection('teams').get();

    if (teamsSnap.docs.isEmpty) {
      throw Exception('No hay equipos registrados en esta sala.');
    }

    final Set<String> winnerPlayerIds = {};
    final Set<String> loserPlayerIds = {};

    for (final doc in teamsSnap.docs) {
      final data = doc.data();
      final teamId = doc.id;
      final players = List<String>.from(data['players'] ?? const <String>[]);

      if (teamId == winnerTeamId) {
        winnerPlayerIds.addAll(players);
      } else {
        loserPlayerIds.addAll(players);
      }
    }

    // Por seguridad, no queremos jugadores duplicados en ambas listas
    loserPlayerIds.removeWhere(winnerPlayerIds.contains);

    // 5️⃣ Mensajes de resultado
    const String winnerTitle = 'Victoria absoluta ⚽';
    final String winnerBody =
        'Tu equipo $winnerTeamName dominó la cancha en "${room.name}". '
        '¡Sigue así, crack, esto apenas comienza!';

    const String loserTitle = 'No se dio esta vez... 💔';
    final String loserBody =
        'La victoria no llegó hoy en "${room.name}", pero el fútbol siempre da revancha. '
        'No bajes la cabeza, sigan luchando.';

    // 6️⃣ Escribir todo en un batch:
    //     - sala cerrada
    //     - notificaciones de resultado por usuario
    final batch = _firestore.batch();
    final serverNow = FieldValue.serverTimestamp();

    // ✅ Actualizar sala como cerrada
    batch.update(_roomRef(roomId), {
      'isClosed': true,
      'winnerTeamId': winnerTeamId,
      'winnerTeamName': winnerTeamName,
      'closedAt': serverNow,
    });

    // ✅ Notificaciones para GANADORES
    for (final playerId in winnerPlayerIds) {
      final notifRef = _firestore
          .collection('users')
          .doc(playerId)
          .collection('matchResults')
          .doc(roomId); // usamos roomId como id único

      batch.set(notifRef, {
        'roomId': roomId,
        'winnerTeamId': winnerTeamId,
        'winnerTeamName': winnerTeamName,
        'isWinner': true,
        'title': winnerTitle,
        'body': winnerBody,
        'type': 'match_result',
        'createdAt': serverNow,
        'seen': false,
      });
    }

    // ✅ Notificaciones para PERDEDORES
    for (final playerId in loserPlayerIds) {
      final notifRef = _firestore
          .collection('users')
          .doc(playerId)
          .collection('matchResults')
          .doc(roomId); // mismo id: el resultado es el mismo partido

      batch.set(notifRef, {
        'roomId': roomId,
        'winnerTeamId': winnerTeamId,
        'winnerTeamName': winnerTeamName,
        'isWinner': false,
        'title': loserTitle,
        'body': loserBody,
        'type': 'match_result',
        'createdAt': serverNow,
        'seen': false,
      });
    }

    await batch.commit();

    // 7️⃣ Actualizar estadísticas de usuarios (partidos + XP + rango)
    try {
      final Set<String> allPlayers = {
        ...winnerPlayerIds,
        ...loserPlayerIds,
      };

      if (allPlayers.isNotEmpty) {
        final function = FirebaseFunctions.instance.httpsCallable(
          'updateUserStats',
          options: HttpsCallableOptions(timeout: Duration(seconds: 20)),
        );

        await function.call({
          'userIds': allPlayers.toList(),
          'xpGained': 100, // XP que definimos
        });

        print(
            "✓ Estadísticas actualizadas con éxito para ${allPlayers.length} jugadores.");
      }
    } catch (e) {
      print("❌ Error llamando función updateUserStats: $e");
    }
  }

  // ===================================================================
  // 🌎 Normalizador
  // ===================================================================
  String? _toIsoFromName(String? name) {
    if (name == null) return null;
    final n = normalizeText(name);
    if (n.length == 2) return n.toUpperCase();
    final viaHelper = toIso2OrGuess(name);
    if (viaHelper != null && viaHelper.trim().isNotEmpty) {
      return viaHelper.toUpperCase();
    }

    const map = {
      'colom': 'CO',
      'mex': 'MX',
      'arg': 'AR',
      'chile': 'CL',
      'per': 'PE',
      'esp': 'ES',
      'ecuad': 'EC',
      'boliv': 'BO',
      'uru': 'UY',
      'para': 'PY',
      'venez': 'VE',
      'bra': 'BR',
      'us': 'US',
      'eeuu': 'US',
      'canad': 'CA',
      'ingl': 'GB',
      'reino unido': 'GB',
      'fran': 'FR',
      'ital': 'IT',
      'alem': 'DE',
      'jap': 'JP',
      'chin': 'CN',
      'corea': 'KR',
      'india': 'IN',
      'austral': 'AU',
      'nueva zel': 'NZ',
      'portug': 'PT',
      'sui': 'CH',
      'turq': 'TR',
      'rusi': 'RU',
      'arab': 'SA',
      'sudaf': 'ZA',
    };

    for (final key in map.keys) {
      if (n.contains(key)) return map[key];
    }
    return name.toUpperCase();
  }

  // ===============================================================
  // 🧮 Cálculo de distancia Haversine (seguro)
  // ===============================================================
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
