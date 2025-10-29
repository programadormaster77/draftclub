// lib/features/rooms/data/room_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/room_model.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'team_service.dart';
import 'dart:math' as math;

/// ====================================================================
/// ⚙️ RoomService — Gestión central de salas en Firestore
/// ====================================================================
/// 🔹 Crear, actualizar, eliminar, unir y salir de salas.
/// 🔹 Soporta ubicación completa (ciudad, país, coordenadas, dirección exacta).
/// 🔹 Filtrado avanzado (cercanía, país, fecha, sexo, dirección).
/// 🔹 Crea equipos automáticos al generar una sala.
/// ====================================================================
class RoomService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// ================================================================
  /// 🏗️ Crear una nueva sala + equipos automáticos
  /// ================================================================
  Future<String> createRoom({
    required String name,
    required int teams,
    required int playersPerTeam,
    required int substitutes,
    required bool isPublic,
    String? manualCity, // Ciudad escrita o seleccionada
    double? cityLat,
    double? cityLng,
    double? lat,
    double? lng,
    String? countryCode,
    DateTime? eventAt,
    String? exactAddress, // Dirección exacta del partido
    String? sex, // 🚻 Tipo de partido (Masculino, Femenino, Mixto)
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final roomId = const Uuid().v4();

    String city = manualCity ?? 'Desconocido';
    double? finalLat = lat ?? cityLat;
    double? finalLng = lng ?? cityLng;
    String? country = countryCode;
    String? finalSex = sex;

    // 👤 Intentar obtener datos del perfil del usuario
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        // Si no se pasa sexo, tomarlo del perfil
        finalSex ??= data['sex'] ?? 'Mixto';
        // Si no se pasa ciudad, tomarla del perfil
        if (manualCity == null || manualCity.isEmpty) {
          city = data['city'] ?? city;
        }
        // Si no se pasa país, tomarlo del perfil
        country ??= data['countryCode'];
        // Si no se pasan coordenadas, usar las del perfil
        finalLat ??=
            (data['lat'] is num) ? (data['lat'] as num).toDouble() : null;
        finalLng ??=
            (data['lng'] is num) ? (data['lng'] as num).toDouble() : null;
      }
    } catch (e) {
      // no bloquear creación
      // print('⚠️ Error obteniendo perfil del usuario: $e');
    }

    // 🌍 Intento de ubicación automática si no se proporcionó manualmente
    if ((manualCity == null || manualCity.isEmpty) ||
        (finalLat == null || finalLng == null)) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.low);
            final placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );
            final p = placemarks.first;
            city = p.locality ?? 'Desconocido';
            finalLat = position.latitude;
            finalLng = position.longitude;
            country ??= p.isoCountryCode;
          }
        }
      } catch (e) {
        // print('⚠️ Error al obtener ubicación automática: $e');
      }
    }

    // 🧱 Crear objeto Room
    final room = Room(
      id: roomId,
      name: name.trim(),
      teams: teams,
      playersPerTeam: playersPerTeam,
      substitutes: substitutes,
      isPublic: isPublic,
      creatorId: uid,
      city: city,
      createdAt: DateTime.now(),
      eventAt: eventAt,
      cityLat: cityLat,
      cityLng: cityLng,
      lat: finalLat,
      lng: finalLng,
      countryCode: country,
      exactAddress: exactAddress,
      sex: finalSex ?? 'Mixto',
    );

    // 💾 Guardar en Firestore
    await _firestore.collection('rooms').doc(roomId).set({
      ...room.toMap(),
      'players': [uid],
      if (eventAt != null) 'eventAt': Timestamp.fromDate(eventAt),
      if (exactAddress != null && exactAddress.isNotEmpty)
        'exactAddress': exactAddress,
      if (finalLat != null && finalLng != null) ...{
        'lat': finalLat,
        'lng': finalLng,
      },
      if (country != null) 'countryCode': country,
      if (finalSex != null) 'sex': finalSex,
      'updatedAt': Timestamp.now(),
    });

    // ✅ Crear equipos predeterminados
    final teamService = TeamService();
    await teamService.initDefaultTeams(
      roomId: roomId,
      teams: teams,
      playersPerTeam: playersPerTeam,
    );

    return roomId;
  }

  /// ================================================================
  /// 🔁 Cambiar visibilidad de una sala
  /// ================================================================
  Future<void> toggleVisibility(String roomId, bool isPublic) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'isPublic': isPublic,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error al cambiar visibilidad: $e');
    }
  }

  // ----------------------------------------------------------------
  // 🔧 Utilidad interna: asegurar ciudad/país/coords del usuario
  //    - Si faltan lat/lng en perfil, intenta Geolocator y actualiza.
  // ----------------------------------------------------------------
  Future<
      ({
        String? city,
        String? countryCode,
        double? lat,
        double? lng,
        String? sex,
      })> _ensureUserGeoProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    String? userCity;
    String? userCountryCode;
    double? userLat;
    double? userLng;
    String? userSex;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        userCity = data['city'];
        userCountryCode = data['countryCode'];
        userLat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : null;
        userLng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : null;
        userSex = data['sex'];
      }
    } catch (_) {}

    // Si faltan coords, intentar geolocalizar
    if (userLat == null || userLng == null) {
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
                desiredAccuracy: LocationAccuracy.low);
            userLat = pos.latitude;
            userLng = pos.longitude;

            try {
              final ps = await placemarkFromCoordinates(userLat!, userLng!);
              final p = ps.first;
              userCity ??= p.locality;
              userCountryCode ??= p.isoCountryCode;
            } catch (_) {}

            // guardar en perfil para próximas veces
            try {
              await _firestore.collection('users').doc(uid).update({
                if (userCity != null) 'city': userCity,
                if (userCountryCode != null) 'countryCode': userCountryCode,
                'lat': userLat,
                'lng': userLng,
              });
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    return (
      city: userCity,
      countryCode: userCountryCode,
      lat: userLat,
      lng: userLng,
      sex: userSex
    );
  }

  /// ================================================================
  /// 📍 Obtener salas públicas filtradas automáticamente según ubicación real
  /// ================================================================
  Future<List<Room>> getFilteredPublicRoomsAuto({
    double radiusKm = 40,
    DateTime? targetDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    try {
      final profile = await _ensureUserGeoProfile();

      // Si seguimos sin coords → no devolvemos todas; devolvemos vacío para evitar ruido
      if (profile.lat == null || profile.lng == null) {
        // print('⚠️ Usuario sin coordenadas — devolviendo lista vacía');
        return [];
      }

      final rooms = await getFilteredPublicRooms(
        cityName: profile.city,
        userLat: profile.lat,
        userLng: profile.lng,
        userCountryCode: profile.countryCode,
        userSex: profile.sex,
        radiusKm: radiusKm,
        targetDate: targetDate,
      );

      // Orden final: distancia -> fecha -> createdAt
      rooms.sort((a, b) {
        final da = (a.lat != null && a.lng != null)
            ? _distanceKm(profile.lat!, profile.lng!, a.lat!, a.lng!)
            : (a.cityLat != null && a.cityLng != null)
                ? _distanceKm(
                    profile.lat!, profile.lng!, a.cityLat!, a.cityLng!)
                : 99999;
        final db = (b.lat != null && b.lng != null)
            ? _distanceKm(profile.lat!, profile.lng!, b.lat!, b.lng!)
            : (b.cityLat != null && b.cityLng != null)
                ? _distanceKm(
                    profile.lat!, profile.lng!, b.cityLat!, b.cityLng!)
                : 99999;
        if (da != db) return da.compareTo(db);
        if (a.eventAt != null && b.eventAt != null) {
          return a.eventAt!.compareTo(b.eventAt!);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return rooms;
    } catch (e) {
      // print('⚠️ Error en getFilteredPublicRoomsAuto: $e');
      return [];
    }
  }

  /// ================================================================
  /// 📍 Obtener salas públicas filtradas (modo manual/general)
  ///    Regla importante:
  ///    - Si NO hay ciudad seleccionada por el usuario:
  ///        ➜ Filtrar SIEMPRE por proximidad (<= radiusKm) usando userLat/Lng.
  ///        ➜ Además exigir mismo país cuando esté disponible.
  ///    - Si HAY ciudad seleccionada:
  ///        ➜ Aceptar salas de esa ciudad (o a ~radiusKm de sus coords)
  ///          respetando país cuando esté disponible.
  /// ================================================================
  Future<List<Room>> getFilteredPublicRooms({
    String? cityName,
    double? userLat,
    double? userLng,
    String? userCountryCode,
    String? userSex,
    double radiusKm = 40,
    DateTime? targetDate,
  }) async {
    try {
      final query = _firestore
          .collection('rooms')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(200);

      final snap = await query.get();
      List<Room> rooms =
          snap.docs.map((doc) => Room.fromMap(doc.data())).toList();

      // 🌎 Filtro país (si el usuario tiene país, nunca mostrar de otro país)
      if (userCountryCode != null && userCountryCode.isNotEmpty) {
        rooms = rooms.where((r) {
          final rc = r.countryCode;
          if (rc == null || rc.isEmpty) return true; // permitir si no se guardó
          return rc.toUpperCase() == userCountryCode.toUpperCase();
        }).toList();
      }

      // 📅 Filtro de fecha (mismo día)
      if (targetDate != null) {
        final start =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        final end = start.add(const Duration(days: 1)).subtract(
              const Duration(milliseconds: 1),
            );
        rooms = rooms.where((r) {
          if (r.eventAt == null) return false;
          final e = r.eventAt!;
          return (e.isAfter(start) || e.isAtSameMomentAs(start)) &&
              (e.isBefore(end) || e.isAtSameMomentAs(end));
        }).toList();
      }

      // 🏙️ Ciudad manual seleccionada
      if (cityName != null && cityName.trim().isNotEmpty) {
        final cityLc = cityName.trim().toLowerCase();
        rooms = rooms.where((r) {
          // match por nombre de ciudad
          final matchName = (r.city).toLowerCase() == cityLc;

          // match por proximidad al centro de la ciudad guardado en la sala
          final hasCoords = r.cityLat != null && r.cityLng != null;
          final nearCity = (hasCoords && userLat != null && userLng != null)
              ? _distanceKm(userLat, userLng, r.cityLat!, r.cityLng!) <=
                  radiusKm
              : false;

          // Si conocemos el país del usuario, respetarlo
          final sameCountry = (userCountryCode == null ||
              r.countryCode == null ||
              r.countryCode!.toUpperCase() == userCountryCode.toUpperCase());

          return sameCountry && (matchName || nearCity);
        }).toList();
      } else {
        // 🚫 No hay ciudad seleccionada → SIEMPRE filtrar por cercanía real
        //     (así evitamos que aparezcan salas de Barcelona cuando estás en Bogotá).
        if (userLat != null && userLng != null) {
          rooms = rooms.where((r) {
            // Preferir lat/lng exactos; si no hay, usar cityLat/cityLng
            final lat = r.lat ?? r.cityLat;
            final lng = r.lng ?? r.cityLng;
            if (lat == null || lng == null) {
              // como fallback, permitir si coincide por texto de ciudad EXACTO
              return r.city.trim().isNotEmpty &&
                  // si el usuario no tiene ciudad text, no podemos comparar
                  false;
            }
            final d = _distanceKm(userLat, userLng, lat, lng);
            // país ya se filtró arriba
            return d <= radiusKm;
          }).toList();

          // Si después de proximidad no queda nada, NO devolvemos todas;
          // devolvemos vacío para forzar UX correcta (sin ruido de otras ciudades).
        } else {
          // Sin coords y sin ciudad → no devolver todo el mundo.
          return [];
        }
      }

      // 🚻 Filtro sexo (mixto o compatible con el usuario)
      if (userSex != null && userSex.isNotEmpty) {
        rooms = rooms.where((r) {
          final sex = (r.sex ?? 'mixto').toLowerCase();
          if (sex == 'mixto') return true;
          return sex == userSex.toLowerCase();
        }).toList();
      }

      // 🧭 Ordenar por distancia si tenemos coords; luego por fecha/creación
      if (userLat != null && userLng != null) {
        rooms.sort((a, b) {
          double da;
          {
            final la = a.lat ?? a.cityLat;
            final lo = a.lng ?? a.cityLng;
            da = (la != null && lo != null)
                ? _distanceKm(userLat, userLng, la, lo)
                : 99999;
          }
          double db;
          {
            final lb = b.lat ?? b.cityLat;
            final lo = b.lng ?? b.cityLng;
            db = (lb != null && lo != null)
                ? _distanceKm(userLat, userLng, lb, lo)
                : 99999;
          }
          if (da != db) return da.compareTo(db);
          if (a.eventAt != null && b.eventAt != null) {
            return a.eventAt!.compareTo(b.eventAt!);
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      } else {
        // Sin coords → ordenar por fecha/creación
        rooms.sort((a, b) {
          if (a.eventAt != null && b.eventAt != null) {
            return a.eventAt!.compareTo(b.eventAt!);
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      }

      return rooms;
    } catch (e) {
      // print('⚠️ Error al obtener salas filtradas: $e');
      return [];
    }
  }

  // ================================================================
  // 🧮 Utilidades de distancia
  // ================================================================
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

  double _deg2rad(double deg) => deg * (math.pi / 180);

  // ================================================================
  // 👥 Unirse / salir / editar / eliminar sala
  // ================================================================
  Future<String> joinRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    final ref = _firestore.collection('rooms').doc(roomId);

    return _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('La sala no existe');

      final data = doc.data()!;
      final players = List<String>.from(data['players'] ?? []);
      final teams = data['teams'] ?? 0;
      final playersPerTeam = data['playersPerTeam'] ?? 0;
      final substitutes = data['substitutes'] ?? 0;
      final maxPlayers = (teams * playersPerTeam) + substitutes;

      if (players.contains(uid)) return 'Ya estás en esta sala.';
      if (players.length >= maxPlayers) return 'La sala ya está llena.';

      players.add(uid);
      tx.update(ref, {'players': players, 'updatedAt': Timestamp.now()});
      return 'Te uniste correctamente.';
    });
  }

  Future<String> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    final ref = _firestore.collection('rooms').doc(roomId);

    return _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('La sala no existe');
      final data = doc.data()!;
      final players = List<String>.from(data['players'] ?? []);

      if (!players.contains(uid)) return 'No estás en esta sala.';

      players.remove(uid);
      tx.update(ref, {'players': players, 'updatedAt': Timestamp.now()});
      return 'Saliste correctamente de la sala.';
    });
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .update({...updates, 'updatedAt': Timestamp.now()});
    } catch (e) {
      throw Exception('Error al actualizar la sala: $e');
    }
  }

  Future<Room?> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return Room.fromMap(doc.data()!);
    } catch (e) {
      // print('⚠️ Error al obtener sala por ID: $e');
      return null;
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    if (!doc.exists) throw Exception('La sala no existe');

    final data = doc.data()!;
    if (data['creatorId'] != uid) {
      throw Exception('Solo el creador puede eliminar la sala.');
    }

    await _firestore.collection('rooms').doc(roomId).delete();
  }
}
