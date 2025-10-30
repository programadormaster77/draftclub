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
/// ⚙️ RoomService — Gestión central de salas en Firestore (GLOBAL)
/// ====================================================================
/// 🔹 Compatible con cualquier país y nombre de ciudad.
/// 🔹 Normaliza códigos de país a formato ISO-2 universal.
/// 🔹 Soporta ubicación, filtrado avanzado y equipos automáticos.
/// 🔹 Resiliente ante perfiles incompletos o geolocalización fallida.
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

    // ================================================================
    // 🔧 Normalización de datos base
    // ================================================================
    String city = (manualCity ?? '').trim();
    if (city.contains(',')) city = city.split(',').first.trim();
    if (city.isEmpty) city = 'Desconocido';

    double? finalLat = lat ?? cityLat;
    double? finalLng = lng ?? cityLng;
    String? country = _toIsoFromName(countryCode);
    String finalSex = (sex ?? '').trim().toLowerCase();
    if (finalSex.isEmpty) finalSex = 'mixto';

    // ================================================================
    // 👤 Intentar obtener datos del perfil del usuario
    // ================================================================
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;

        finalSex = (data['sex'] ?? finalSex).toString().toLowerCase();

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

    // ================================================================
    // 🌍 Intento de ubicación automática si no se proporcionó manualmente
    // ================================================================
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
            final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.low);
            final placemarks =
                await placemarkFromCoordinates(pos.latitude, pos.longitude);
            final p = placemarks.first;
            city = p.locality ?? city;
            finalLat = pos.latitude;
            finalLng = pos.longitude;
            country ??= _toIsoFromName(p.isoCountryCode);
          }
        }
      } catch (_) {}
    }

    // ================================================================
    // 🧱 Crear objeto Room
    // ================================================================
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
      cityLat: cityLat ?? finalLat,
      cityLng: cityLng ?? finalLng,
      lat: finalLat,
      lng: finalLng,
      countryCode: country,
      exactAddress: exactAddress,
      sex: finalSex,
    );

    // ================================================================
    // 💾 Guardar en Firestore
    // ================================================================
    await _firestore.collection('rooms').doc(roomId).set({
      ...room.toMap(),
      'players': [uid],
      'updatedAt': Timestamp.now(),
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

    // ================================================================
    // ✅ Crear equipos predeterminados
    // ================================================================
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

  // ================================================================
  // 🔧 Asegurar ciudad/país/coords del usuario
  // ================================================================
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
                desiredAccuracy: LocationAccuracy.low);
            lat = pos.latitude;
            lng = pos.longitude;
            try {
              final ps = await placemarkFromCoordinates(lat!, lng!);
              final p = ps.first;
              city ??= p.locality;
              country ??= _toIsoFromName(p.isoCountryCode);
            } catch (_) {}
            await _firestore.collection('users').doc(uid).update({
              if (city != null) 'city': city,
              if (country != null) 'countryCode': country,
              'lat': lat,
              'lng': lng,
            });
          }
        }
      } catch (_) {}
    }

    return (city: city, countryCode: country, lat: lat, lng: lng, sex: sex);
  }

  /// ================================================================
  /// 📍 Obtener salas públicas filtradas automáticamente
  /// ================================================================
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
      rooms.sort((a, b) {
        final da = _distanceKm(profile.lat!, profile.lng!,
            a.lat ?? a.cityLat ?? 0, a.lng ?? a.cityLng ?? 0);
        final db = _distanceKm(profile.lat!, profile.lng!,
            b.lat ?? b.cityLat ?? 0, b.lng ?? b.cityLng ?? 0);
        if (da != db) return da.compareTo(db);
        if (a.eventAt != null && b.eventAt != null) {
          return a.eventAt!.compareTo(b.eventAt!);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return rooms;
    } catch (_) {
      return [];
    }
  }

  /// ================================================================
  /// 📍 Obtener salas públicas filtradas (global, tolerante)
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
      final snap = await _firestore
          .collection('rooms')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();
      List<Room> rooms =
          snap.docs.map((doc) => Room.fromMap(doc.data())).toList();

      // 🌍 Filtro país tolerante ISO/nombre
      if (userCountryCode != null && userCountryCode.isNotEmpty) {
        final userIso = _toIsoFromName(userCountryCode);
        rooms = rooms.where((r) {
          final rc = _toIsoFromName(r.countryCode ?? '');
          if (rc == null || rc.isEmpty) return true;
          return rc.toUpperCase() == (userIso ?? '').toUpperCase();
        }).toList();
      }

      // 📅 Filtro de fecha
      if (targetDate != null) {
        final start =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        final end = start.add(const Duration(days: 1));
        rooms = rooms.where((r) {
          final e = r.eventAt;
          return e != null && e.isAfter(start) && e.isBefore(end);
        }).toList();
      }

      // 🏙️ Filtro ciudad + cercanía
      if (cityName != null && cityName.trim().isNotEmpty) {
        final wanted = _norm(cityName.split(',').first);
        rooms = rooms.where((r) {
          final roomCity = _norm(r.city.split(',').first);
          final nameMatch = roomCity == wanted ||
              roomCity.contains(wanted) ||
              wanted.contains(roomCity);
          final nearCity = (r.cityLat != null &&
                  r.cityLng != null &&
                  userLat != null &&
                  userLng != null)
              ? _distanceKm(userLat, userLng, r.cityLat!, r.cityLng!) <=
                  radiusKm
              : false;
          return nameMatch || nearCity;
        }).toList();
      } else if (userLat != null && userLng != null) {
        rooms = rooms.where((r) {
          final lat = r.lat ?? r.cityLat;
          final lng = r.lng ?? r.cityLng;
          if (lat == null || lng == null) return false;
          return _distanceKm(userLat, userLng, lat, lng) <= radiusKm;
        }).toList();
      }

      // 🚻 Filtro sexo
      if (userSex != null && userSex.isNotEmpty) {
        final u = userSex.toLowerCase();
        rooms = rooms.where((r) {
          final s = (r.sex ?? 'mixto').toLowerCase();
          return s == 'mixto' || s == u;
        }).toList();
      }

      // 🧭 Orden final
      if (userLat != null && userLng != null) {
        rooms.sort((a, b) {
          final da = _distanceKm(userLat, userLng, a.lat ?? a.cityLat ?? 0,
              a.lng ?? a.cityLng ?? 0);
          final db = _distanceKm(userLat, userLng, b.lat ?? b.cityLat ?? 0,
              b.lng ?? b.cityLng ?? 0);
          return da.compareTo(db);
        });
      } else {
        rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return rooms;
    } catch (_) {
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
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .update({...updates, 'updatedAt': Timestamp.now()});
  }

  Future<Room?> getRoomById(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    return doc.exists ? Room.fromMap(doc.data()!) : null;
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

  // ================================================================
  // 🌎 Normalizadores universales
  // ================================================================
  String? _toIsoFromName(String? name) {
    if (name == null) return null;
    final n = _norm(name);
    if (n.length == 2) return n.toUpperCase();
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

  // ---------------------------------------------------------------
  // 🔠 Normalizador de texto: elimina tildes, minúsculas y ñ → n
  // ---------------------------------------------------------------
  String _norm(String s) {
    const repl = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    final sb = StringBuffer();
    for (final ch in s.trim().toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      sb.write(repl[c] ?? c);
    }
    return sb.toString();
  }
}
