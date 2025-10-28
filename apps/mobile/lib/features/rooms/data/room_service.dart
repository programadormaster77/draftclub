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
/// 🔹 Soporta ubicación completa (ciudad, país, coordenadas).
/// 🔹 Compatible con filtros inteligentes (cercanía, ciudad, fecha).
/// 🔹 Crea equipos automáticos en Firestore.
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
    String? countryCode,
    DateTime? eventAt,
    String? exactAddress, // Dirección exacta del partido
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final roomId = const Uuid().v4();

    String city = manualCity ?? 'Desconocido';
    double? lat = cityLat;
    double? lng = cityLng;
    String? country = countryCode;

    // 🌍 Ubicación automática si no se proporcionó manualmente
    if ((manualCity == null || manualCity.isEmpty) ||
        (lat == null || lng == null)) {
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
            lat = position.latitude;
            lng = position.longitude;
            country = p.isoCountryCode;
          }
        }
      } catch (e) {
        print('⚠️ Error al obtener ubicación automática: $e');
      }
    }

    // 🧱 Crear objeto Room con coordenadas y país
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
      cityLat: lat,
      cityLng: lng,
      countryCode: country,
    );

    // 💾 Guardar en Firestore
    await _firestore.collection('rooms').doc(roomId).set({
      ...room.toMap(),
      'players': [uid],
      if (eventAt != null) 'eventAt': Timestamp.fromDate(eventAt),
      if (exactAddress != null && exactAddress.isNotEmpty)
        'exactAddress': exactAddress,
      if (lat != null && lng != null) ...{
        'cityLat': lat,
        'cityLng': lng,
      },
      if (country != null) 'countryCode': country,
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
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .update({'isPublic': isPublic});
    } catch (e) {
      throw Exception('Error al cambiar visibilidad: $e');
    }
  }

  /// ================================================================
  /// 📍 Obtener salas públicas cercanas / por ciudad / por fecha
  /// ================================================================
  Future<List<Room>> getFilteredPublicRooms({
    String? cityName,
    double? userLat,
    double? userLng,
    String? userCountryCode,
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

      // Filtro: país
      if (userCountryCode != null) {
        rooms = rooms
            .where((r) =>
                r.countryCode == null ||
                r.countryCode!.toUpperCase() == userCountryCode.toUpperCase())
            .toList();
      }

      // Filtro: fecha (día exacto)
      if (targetDate != null) {
        final start =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        final end = start.add(const Duration(days: 1)).subtract(
              const Duration(milliseconds: 1),
            );
        rooms = rooms.where((r) {
          if (r.eventAt == null) return false;
          return r.eventAt!.isAfter(start) && r.eventAt!.isBefore(end);
        }).toList();
      }

      // Filtro: ciudad
      if (cityName != null && cityName.trim().isNotEmpty) {
        rooms = rooms
            .where((r) =>
                r.city.toLowerCase() == cityName.toLowerCase() ||
                (r.cityLat != null &&
                    userLat != null &&
                    userLng != null &&
                    _distanceKm(userLat, userLng, r.cityLat!, r.cityLng!) <=
                        radiusKm))
            .toList();
      }

      // Filtro: cercanía si hay coordenadas
      if (userLat != null && userLng != null) {
        rooms = rooms.where((r) {
          if (r.cityLat == null || r.cityLng == null) return false;
          final d = _distanceKm(userLat, userLng, r.cityLat!, r.cityLng!);
          return d <= radiusKm;
        }).toList();
      }

      // Ordenar por distancia si es posible
      if (userLat != null && userLng != null) {
        rooms.sort((a, b) {
          double da = a.cityLat != null && a.cityLng != null
              ? _distanceKm(userLat, userLng, a.cityLat!, a.cityLng!)
              : 99999;
          double db = b.cityLat != null && b.cityLng != null
              ? _distanceKm(userLat, userLng, b.cityLat!, b.cityLng!)
              : 99999;
          return da.compareTo(db);
        });
      }

      return rooms;
    } catch (e) {
      print('⚠️ Error al obtener salas filtradas: $e');
      return [];
    }
  }

  /// ================================================================
  /// 🧮 Distancia Haversine (km)
  /// ================================================================
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

  /// ================================================================
  /// 🧍 Unirse a una sala (con validación de cupos)
  /// ================================================================
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
      tx.update(ref, {'players': players});
      return 'Te uniste correctamente.';
    });
  }

  /// ================================================================
  /// 🚪 Salir de una sala
  /// ================================================================
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
      tx.update(ref, {'players': players});
      return 'Saliste correctamente de la sala.';
    });
  }

  /// ================================================================
  /// 🧾 Editar datos de una sala existente
  /// ================================================================
  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update(updates);
    } catch (e) {
      throw Exception('Error al actualizar la sala: $e');
    }
  }

  /// ================================================================
  /// 🔍 Obtener una sala por ID
  /// ================================================================
  Future<Room?> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return Room.fromMap(doc.data()!);
    } catch (e) {
      print('⚠️ Error al obtener sala por ID: $e');
      return null;
    }
  }

  /// ================================================================
  /// ❌ Eliminar una sala (solo creador)
  /// ================================================================
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
