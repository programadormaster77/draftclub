// lib/features/rooms/presentation/rooms_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/room_service.dart';

import '../models/room_model.dart';
import 'room_detail_page.dart';
import 'create_room_page.dart';
import 'find_room_page.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';

/// ====================================================================
/// 🏟️ RoomsPage — Panel principal de salas (con filtros inteligentes)
/// ====================================================================
/// ✅ Cercanía (40 km) usando geolocalización del usuario
/// ✅ Filtro por ciudad con buscador (Google Places)
/// ✅ Filtro por fecha (mismo día)
/// ✅ Filtro automático por sexo del usuario (Masculino/Femenino/Mixto)
/// ✅ Bloqueo si se busca en país distinto al actual
/// ✅ Fallback controlado y sin parpadeos
/// ====================================================================
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;

  // ------- Estado de ubicación del usuario -------
  double? _myLat;
  double? _myLng;
  String? _myCity;
  String? _myCountryCode;

  // ------- Sexo del usuario (para filtro automático) -------
  String? _userSex; // "masculino" | "femenino" | null (sin dato)

  // ------- Filtros seleccionados por el usuario -------
  bool _useNearby = true; // por defecto: buscar cerca (40 km)
  static const double _nearbyKm = 40.0;

  String? _filterCityName;
  double? _filterCityLat;
  double? _filterCityLng;
  String? _filterCountryCode;

  DateTime? _filterDate; // mismo día (00:00–23:59)

  // ------- UI -------
  bool _loadingLoc = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ensureLocation();
    _loadUserSex();
  }

  // ==========================================================
  // 👤 Cargar sexo del usuario (una vez) para filtro automático
  // ==========================================================
  Future<void> _loadUserSex() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _db.collection('users').doc(uid).get();
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final val = (doc['sex'] ?? '').toString().trim().toLowerCase();
        if (val.isNotEmpty) {
          setState(() => _userSex = val); // setState aquí no causa bucles
        }
      }
    } catch (_) {
      // silencioso
    }
  }

  // ==========================================================
  // 📍 Obtener ubicación y país actual del usuario
  // ==========================================================
  Future<void> _ensureLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLoc = false);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() => _loadingLoc = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.first;

      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _myCity = p.locality ?? 'Desconocido';
        _myCountryCode = p.isoCountryCode;
        _loadingLoc = false;

        // Si no hay una ciudad objetivo aún, usa la del usuario (solo etiqueta)
        _filterCityName ??= _myCity;
      });
    } catch (e) {
      setState(() => _loadingLoc = false);
    }
  }

  // ==========================================================
// 🔎 Stream base de salas públicas (ya acotado por país)
// ==========================================================
  Stream<List<Room>> _publicRoomsBaseStream() {
    // Nota: cuando _myCountryCode esté listo (tras _ensureLocation()),
    // la consulta se re-crea y suscribe de nuevo.
    final col = _db.collection('rooms');
    final hasCountry = (_myCountryCode != null && _myCountryCode!.isNotEmpty);

    final query = hasCountry
        ? col
            .where('isPublic', isEqualTo: true)
            .where('countryCode', isEqualTo: _myCountryCode) // 🔒 mismo país
            .orderBy('createdAt', descending: true)
            .limit(200)
        : col
            .where('isPublic', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(200);

    return query
        .snapshots()
        .map((snap) => snap.docs.map((d) => Room.fromMap(d.data())).toList());
  }

  // ==========================================================
  // 📏 Distancia Haversine (km)
  // ==========================================================
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

// ==========================================================
// 🔠 Normalizador universal (quita tildes, comas, puntos, espacios extras)
// ==========================================================
  String _normalizeCity(String s) {
    const Map<String, String> accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'Á': 'a',
      'À': 'a',
      'Ä': 'a',
      'Â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'É': 'e',
      'È': 'e',
      'Ë': 'e',
      'Ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Í': 'i',
      'Ì': 'i',
      'Ï': 'i',
      'Î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ó': 'o',
      'Ò': 'o',
      'Ö': 'o',
      'Ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ú': 'u',
      'Ù': 'u',
      'Ü': 'u',
      'Û': 'u',
      'ñ': 'n',
      'Ñ': 'n'
    };

    return s
        .toLowerCase()
        .trim()
        .split('')
        .map((c) => accents[c] ?? c)
        .join()
        .replaceAll(
            RegExp(r'[^a-z0-9 ]'), ' ') // elimina comas, puntos, símbolos, etc.
        .replaceAll(RegExp(r'\s+'), ' '); // colapsa espacios
  }

// ==========================================================
// 🧮 Aplicar filtros (país, fecha, sexo, ciudad/40km)
// ==========================================================
  List<Room> _applyFilters(List<Room> rooms) {
    Iterable<Room> base = rooms;

    // 1️⃣ País (solo si hay coincidencia clara)
    if (_myCountryCode != null && _myCountryCode!.isNotEmpty) {
      final userCountry = _normalizeCity(_myCountryCode!);
      base = base.where((r) {
        final rc = _normalizeCity(r.countryCode ?? '');
        if (userCountry.isEmpty || rc.isEmpty) return true;
        return rc.contains(userCountry) || userCountry.contains(rc);
      });
    }

    // 2️⃣ Fecha (opcional)
    DateTime? dayStart, dayEnd;
    if (_filterDate != null) {
      dayStart =
          DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      dayEnd = dayStart
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      base = base.where((r) {
        final e = r.eventAt;
        return e != null && !e.isBefore(dayStart!) && !e.isAfter(dayEnd!);
      });
    }

    // 3️⃣ Sexo (automático)
    if (_userSex != null && _userSex!.isNotEmpty) {
      final u = _userSex!.toLowerCase();
      base = base.where((r) {
        final s = (r.sex ?? 'mixto').toLowerCase();
        return s == 'mixto' || s == u;
      });
    }

    // 4️⃣ Ciudad seleccionada manualmente → prioridad total
    if (_filterCityName != null && _filterCityName!.trim().isNotEmpty) {
      final nameLc = _normalizeCity(_filterCityName!);
      if (_filterCityLat != null && _filterCityLng != null) {
        const cityTightKm = 10.0;
        base = base.where((r) {
          final lat = r.lat ?? r.cityLat;
          final lng = r.lng ?? r.cityLng;
          if (lat == null || lng == null) {
            return _normalizeCity(r.city) == nameLc;
          }
          final d = _distanceKm(_filterCityLat!, _filterCityLng!, lat, lng);
          return d <= cityTightKm;
        });
      } else {
        base = base.where((r) => _normalizeCity(r.city) == nameLc);
      }

      return _sortRooms(base);
    }

    // 5️⃣ Sin ciudad seleccionada → usar ciudad del perfil o radio 50 km
    if (_myCity != null && _myCity!.trim().isNotEmpty) {
      final myCityNorm = _normalizeCity(_myCity!);

      base = base.where((r) {
        final roomCity = (r.city ?? '').toString();
        final roomCityNorm = _normalizeCity(roomCity);

        // Coincidencia flexible
        if (roomCityNorm.contains(myCityNorm) ||
            myCityNorm.contains(roomCityNorm)) {
          return true;
        }

        // Distancia (50 km)
        final lat = r.lat ?? r.cityLat;
        final lng = r.lng ?? r.cityLng;
        if (_myLat != null && _myLng != null && lat != null && lng != null) {
          final d = _distanceKm(_myLat!, _myLng!, lat, lng);
          if (d <= 50.0) return true;
        }

        return false;
      });
    } else {
      // Sin ciudad → usar solo cercanía si hay ubicación
      if (_myLat != null && _myLng != null) {
        base = base.where((r) {
          final lat = r.lat ?? r.cityLat;
          final lng = r.lng ?? r.cityLng;
          if (lat == null || lng == null) return false;
          final d = _distanceKm(_myLat!, _myLng!, lat, lng);
          return d <= 50.0;
        });
      } else {
        base = const Iterable<Room>.empty();
      }
    }

    return _sortRooms(base);
  }

// ==========================================================
// 🔄 Función auxiliar para ordenar por cercanía y fecha
// ==========================================================
  List<Room> _sortRooms(Iterable<Room> base) {
    final list = base.toList();
    if (_myLat != null && _myLng != null) {
      list.sort((a, b) {
        double da = 1e9, db = 1e9;
        final aLat = a.lat ?? a.cityLat, aLng = a.lng ?? a.cityLng;
        final bLat = b.lat ?? b.cityLat, bLng = b.lng ?? b.cityLng;
        if (aLat != null && aLng != null) {
          da = _distanceKm(_myLat!, _myLng!, aLat, aLng);
        }
        if (bLat != null && bLng != null) {
          db = _distanceKm(_myLat!, _myLng!, bLat, bLng);
        }
        if (da != db) return da.compareTo(db);
        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  String _norm(String s) {
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n'
    };
    return s
        .toLowerCase()
        .replaceAllMapped(RegExp('[áéíóúüñ]'), (m) => accents[m.group(0)] ?? '')
        .replaceAll(RegExp('[^a-z0-9 ]'), ' ') // elimina símbolos como , .
        .replaceAll(RegExp(' +'), ' ') // colapsa espacios
        .trim();
  }

  // ==========================================================
  // 🚫 Bloqueo por país diferente (pantalla completa)
  // ==========================================================
  void _showBlockedCountryDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          color: const Color(0xFF0E0E0E),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_off,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Rango de búsqueda fuera de los límites',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Por seguridad y para evitar experiencias negativas, las búsquedas deben realizarse dentro de tu país actual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _filterCityName = null;
                        _filterCityLat = null;
                        _filterCityLng = null;
                        _filterCountryCode = null;
                      });
                    },
                    child: const Text('Entendido',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // 🧭 Navegación a detalle
  // ==========================================================
  void _openRoom(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
    );
  }

  // ==========================================================
  // 🏙️ Abrir buscador de ciudad (Google Places)
  // ==========================================================
  Future<void> _openCityPicker() async {
    TextEditingController searchCtrl = TextEditingController();
    List<CitySuggestion> suggestions = [];
    bool searching = false;

    await showModalBottomSheet(
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheet) {
          Future<void> search(String q) async {
            setSheet(() => searching = true);
            suggestions = await PlaceService.fetchCitySuggestions(q);
            setSheet(() => searching = false);
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Buscar ciudad',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (v) => v.trim().isEmpty ? null : search(v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ej: Bogotá, Madrid…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.location_on,
                          color: Colors.blueAccent),
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white24, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blueAccent, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (searching)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Colors.blueAccent, strokeWidth: 2.5),
                    )
                  else if (suggestions.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Escribe para buscar ciudades',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (_, i) {
                          final s = suggestions[i];
                          return ListTile(
                            leading: const Icon(Icons.location_city,
                                color: Colors.blueAccent),
                            title: Text(s.description,
                                style: const TextStyle(color: Colors.white)),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    ).then((res) async {
      if (res is CitySuggestion) {
        // Obtener lat/lng exactos
        final details = await PlaceService.getCityDetails(res.placeId);
        if (details == null) return;

        // Resolver país vía reverse geocoding para tener isoCountryCode
        String? targetIso;
        try {
          final ps = await placemarkFromCoordinates(details.lat!, details.lng!);
          targetIso = ps.first.isoCountryCode;
        } catch (_) {}

        // Si país difiere del actual → bloquear
        if (targetIso != null &&
            _myCountryCode != null &&
            targetIso.toUpperCase() != _myCountryCode!.toUpperCase()) {
          setState(() {
            _filterCityName = details.description;
            _filterCityLat = details.lat;
            _filterCityLng = details.lng;
            _filterCountryCode = targetIso;
          });
          _showBlockedCountryDialog();
          return;
        }

        // Aceptar ciudad
        setState(() {
          _filterCityName = details.description;
          _filterCityLat = details.lat;
          _filterCityLng = details.lng;
          _filterCountryCode = targetIso;
        });
      }
    });
  }

  // ==========================================================
  // 🗓️ Selector de fecha (día objetivo)
  // ==========================================================
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) {
      setState(
          () => _filterDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  // ==========================================================
  // 🎨 Construcción principal
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Salas'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'Públicas'),
            Tab(text: 'Mis salas'),
            Tab(text: 'Buscar'),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
            tooltip: 'Crear nueva sala',
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoomPage()),
              );
              if (created == true && mounted) setState(() {});
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicRoomsTab(),
          _buildMyRoomsTab(),
          const FindRoomPage(),
        ],
      ),
    );
  }

  /// ==========================================================
  /// 🏙️ TAB 1 — Salas públicas (con filtros)
  /// ==========================================================
  Widget _buildPublicRoomsTab() {
    if (_loadingLoc) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FiltersCard(
            useNearby: _useNearby,
            onToggleNearby: (v) => setState(() => _useNearby = v),
            currentCityLabel: _filterCityName ?? _myCity ?? 'Seleccionar…',
            onPickCity: _openCityPicker,
            dateLabel: _filterDate == null
                ? 'Fecha (opcional)'
                : '${_filterDate!.day.toString().padLeft(2, '0')}/${_filterDate!.month.toString().padLeft(2, '0')}/${_filterDate!.year}',
            onPickDate: _pickDate,
            onClearCity: () {
              setState(() {
                _filterCityName = null;
                _filterCityLat = null;
                _filterCityLng = null;
                _filterCountryCode = null;
              });
            },
            onClearDate: () => setState(() => _filterDate = null),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: StreamBuilder<List<Room>>(
            key: ValueKey(
              'pub_${_filterCityName}_${_filterDate?.millisecondsSinceEpoch ?? ''}_${_userSex ?? ''}_${_myCountryCode ?? ''}_${_myCity ?? ''}',
            ),
            stream: _publicRoomsBaseStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent));
              }
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.redAccent)));
              }

              final all = snap.data ?? [];
              final rooms = _applyFilters(all);

              if (rooms.isEmpty) {
                return _EmptyState(
                  title: 'No hay salas públicas según tus filtros',
                  message:
                      'Prueba otra fecha, cambia la ciudad o crea tu propia sala.',
                  actionText: 'Crear una sala',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateRoomPage()),
                    );
                  },
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rooms.length,
                itemBuilder: (_, i) => _roomCard(rooms[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// ==========================================================
  /// 👤 TAB 2 — Mis salas
  /// ==========================================================
  Widget _buildMyRoomsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text(
          'Inicia sesión para ver tus salas.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return StreamBuilder<List<Room>>(
      stream: _db
          .collection('rooms')
          .where('players', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((snap) => snap.docs.map((d) => Room.fromMap(d.data())).toList()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent)));
        }

        // Filtro de sexo aplicado también a "Mis salas"
        List<Room> rooms = (snap.data ?? []);
        if (_userSex != null && _userSex!.isNotEmpty) {
          rooms = rooms.where((r) {
            final roomSex = (r.sex ?? 'mixto').toLowerCase();
            if (roomSex == 'mixto') return true;
            return roomSex == _userSex;
          }).toList();
        }

        if (rooms.isEmpty) {
          return const Center(
              child: Text('Aún no te has unido ni has creado salas.',
                  style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (_, i) => _roomCard(rooms[i]),
        );
      },
    );
  }

  /// ==========================================================
  /// 💠 Tarjeta reutilizable de sala
  /// ==========================================================
  Widget _roomCard(Room room) {
    // Distancia (si hay coords)
    String? distLabel;
    if (_myLat != null &&
        _myLng != null &&
        (room.lat != null || room.cityLat != null) &&
        (room.lng != null || room.cityLng != null)) {
      final lat = room.lat ?? room.cityLat!;
      final lng = room.lng ?? room.cityLng!;
      final d = _distanceKm(_myLat!, _myLng!, lat, lng);
      distLabel = '${d.toStringAsFixed(1)} km';
    }

    // Fecha
    String? dateLabel;
    if (room.eventAt != null) {
      final e = room.eventAt!;
      dateLabel =
          '${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year} ${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: () => _openRoom(room),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (distLabel != null)
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(distLabel,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Ciudad y fecha
            Row(
              children: [
                const Icon(Icons.location_city,
                    size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Ciudad: ${room.city}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
            if (dateLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(dateLabel,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Equipos: ${room.teams} | Jugadores/Equipo: ${room.playersPerTeam}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_forward_ios,
                    color: Colors.blueAccent, size: 16),
                label: const Text(
                  'Ver sala',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                ),
                onPressed: () => _openRoom(room),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// ====================================================================
/// 🎛️ Tarjeta de filtros (UI)
/// ====================================================================
class _FiltersCard extends StatelessWidget {
  final bool useNearby;
  final ValueChanged<bool> onToggleNearby;

  final String currentCityLabel;
  final VoidCallback onPickCity;
  final VoidCallback onClearCity;

  final String dateLabel;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  const _FiltersCard({
    required this.useNearby,
    required this.onToggleNearby,
    required this.currentCityLabel,
    required this.onPickCity,
    required this.onClearCity,
    required this.dateLabel,
    required this.onPickDate,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          children: [
            // Cercanía
            SwitchListTile.adaptive(
              value: useNearby,
              onChanged: onToggleNearby,
              title: const Text('Cerca de mí (40 km)',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Usa tu ubicación para ordenar por cercanía',
                style: TextStyle(color: Colors.white54),
              ),
              activeColor: Colors.blueAccent,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Ciudad + Fecha
            Row(
              children: [
                Expanded(
                  child: _ActionField(
                    icon: Icons.location_on,
                    label: 'Ciudad',
                    value: currentCityLabel,
                    onTap: onPickCity,
                    onClear: onClearCity,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionField(
                    icon: Icons.event,
                    label: 'Fecha',
                    value: dateLabel,
                    onTap: onPickDate,
                    onClear: onClearDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ActionField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ActionField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.toLowerCase().contains('opcional') ||
        value.toLowerCase().contains('seleccionar');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isEmpty ? Colors.white54 : Colors.white,
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.w500,
                ),
              ),
            ),
            if (!isEmpty)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                tooltip: 'Limpiar',
              ),
          ],
        ),
      ),
    );
  }
}

/// ====================================================================
/// 🔕 Estado vacío con acción
/// ====================================================================
class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;

  const _EmptyState({
    required this.title,
    required this.message,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied,
                color: Colors.white24, size: 56),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAction,
              child:
                  Text(actionText, style: const TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
