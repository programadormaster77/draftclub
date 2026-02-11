// lib/features/rooms/presentation/rooms_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../data/room_service.dart';
import '../models/room_model.dart';
import '../domain/room_filters.dart';

import 'widgets/room_card.dart';
import 'create_room_page.dart';
import 'room_detail_page.dart';
import 'find_room_page.dart';
import 'widgets/match_history_tab.dart'; // 🆕 Historial global

import 'package:draftclub_mobile/core/location/place_service.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _service = RoomService();

  late TabController _tabController;

  // -------- Contexto del usuario ----------
  double? _myLat;
  double? _myLng;
  String? _myCity;
  String? _myCountryCode;
  String? _userSex; // masculino | femenino | mixto

  // -------- Filtros activos ---------------
  RoomFilters _filters = const RoomFilters();
  bool _useNearby = true; // toggle “Cerca de mí (40 km)”
  static const double _nearbyKm = 40.0;

  // -------- Estado UI ---------------------
  bool _bootstrapping = true;
  late Future<List<Room>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _roomsFuture = _bootstrapAndFetch();
  }

  Future<List<Room>> _bootstrapAndFetch() async {
    await _ensureUserContext();
    _rebuildFiltersDefaults();
    return _fetchRooms();
  }

  // 1) Carga ubicación, país y sexo del usuario
  Future<void> _ensureUserContext() async {
    try {
      // Sexo desde perfil
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _db.collection('users').doc(uid).get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>?;

          // 🔹 Sexo
          final rawSex = (data?['sex'] ?? '').toString().trim().toLowerCase();
          _userSex = _normalizeSex(rawSex);

          // 🔹 Ciudad (city o ciudad)
          final city = (data?['city'] ?? data?['ciudad'])?.toString();
          if (city != null && city.trim().isNotEmpty) {
            _myCity = city.split(',').first.trim();
          }

          // 🔹 Código de país (maneja ambos: countryCode o country)
          final ccode = data?['countryCode']?.toString() ?? '';
          if (ccode.isNotEmpty) {
            _myCountryCode = ccode;
          } else if (data?['country'] != null) {
            _myCountryCode = data!['country'].toString();
          }

          // 🔹 Coordenadas
          final lat = (data?['lat'] as num?)?.toDouble();
          final lng = (data?['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _myLat = lat;
            _myLng = lng;
          }
        }
      }

      // Si siguen faltando coords, intenta geolocalizar
      if (_myLat == null || _myLng == null) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) return;

        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.deniedForever ||
            perm == LocationPermission.denied) return;

        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
        _myLat = pos.latitude;
        _myLng = pos.longitude;

        try {
          final ps = await placemarkFromCoordinates(_myLat!, _myLng!);
          final p = ps.first;
          _myCity = p.locality ?? _myCity ?? 'Desconocido';
          _myCountryCode ??= p.isoCountryCode;
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
      } else {
        _bootstrapping = false;
      }
    }
  }

// 2) Define filtros por defecto con 40 km y ciudad/sexo del usuario
  void _rebuildFiltersDefaults() {
    _filters = RoomFilters(
      cityName: _myCity,
      userLat: _myLat,
      userLng: _myLng,
      userCountryCode: _myCountryCode,
      userSex: _userSex, // importante para filtrar mixto/mismo sexo
      radiusKm: _nearbyKm,
      date: null,
    );
  }

// 3) Pide al service las salas con los filtros actuales
  Future<List<Room>> _fetchRooms() async {
    // ✅ Determinar el centro de búsqueda:
    // Si hay ciudad seleccionada, usamos sus coords; si no, las del usuario.
    final centerLat = _filters.cityLat ?? _filters.userLat;
    final centerLng = _filters.cityLng ?? _filters.userLng;

    final rooms = await _service.getFilteredPublicRooms(
      cityName: _filters.cityName,
      userLat: _filters.userLat,
      userLng: _filters.userLng,
      userCountryCode: _filters.userCountryCode,
      userSex: _filters.userSex,
      radiusKm: _useNearby ? _filters.radiusKm : 50.0,
      targetDate: _filters.date,
      cityCountryCode: _filters.cityCountryCode, // 👈 nuevo
    );

    // 🔹 Orden final: por distancia al centro activo, luego por fecha de creación
    if (centerLat != null && centerLng != null) {
      rooms.sort((a, b) {
        final da = _distanceKm(
          centerLat,
          centerLng,
          a.lat ?? a.cityLat ?? 0,
          a.lng ?? a.cityLng ?? 0,
        );
        final db = _distanceKm(
          centerLat,
          centerLng,
          b.lat ?? b.cityLat ?? 0,
          b.lng ?? b.cityLng ?? 0,
        );
        if (da != db) return da.compareTo(db);
        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return rooms;
  }

// ----------------- Utilidades -----------------
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

  String _normalizeSex(String? s) {
    if (s == null || s.trim().isEmpty) return 'mixto';
    final v = s.trim().toLowerCase();
    if (v.startsWith('m')) return 'masculino';
    if (v.startsWith('f')) return 'femenino';
    if (v.startsWith('mi')) return 'mixto';
    return 'mixto';
  }

// ----------------- Acciones UI -----------------
  Future<void> _onRefresh() async {
    setState(() {
      _roomsFuture = _fetchRooms();
    });
    await _roomsFuture;
  }

  Future<void> _pickCity() async {
    TextEditingController searchCtrl = TextEditingController();
    List<CitySuggestion> suggestions = [];
    bool searching = false;
    CitySuggestion? chosen;

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
                    child: Text('Buscar ciudad',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
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
                            color: Colors.blueAccent, strokeWidth: 2.5))
                  else if (suggestions.isEmpty)
                    const Expanded(
                        child: Center(
                            child: Text('Escribe para buscar ciudades',
                                style: TextStyle(color: Colors.white38))))
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
                            onTap: () {
                              chosen = s;
                              Navigator.pop(context);
                            },
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
    );

    if (chosen == null) return;

    // Obtén lat/lng + país ISO-2 de la CIUDAD seleccionada
    final details = await PlaceService.getCityDetails(chosen!.placeId);
    if (details == null) return;

    setState(() {
      _filters = _filters.copyWith(
        cityName: details.description,
        cityLat: details.lat,
        cityLng: details.lng,
        cityCountryCode: details.countryCode, // 👈 clave
      );
      _roomsFuture = _fetchRooms();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filters.date ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) {
      setState(() {
        _filters = _filters.copyWith(
          date: DateTime(picked.year, picked.month, picked.day),
        );
        _roomsFuture = _fetchRooms();
      });
    }
  }

  void _clearCity() {
    setState(() {
      _filters = _filters.copyWith(
        cityName: _myCity,
        cityLat: null,
        cityLng: null,
        cityCountryCode: null, // 👈 importante
      );
      _roomsFuture = _fetchRooms();
    });
  }

  void _clearDate() {
    setState(() {
      _filters = _filters.copyWith(date: null);
      _roomsFuture = _fetchRooms();
    });
  }

  // ----------------- UI -----------------
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
            Tab(text: 'Historial'), // 🆕
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
              if (created == true && mounted) {
                setState(() => _roomsFuture = _fetchRooms());
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicTab(),
          _buildMyRoomsTab(),
          const FindRoomPage(),
          const MatchHistoryTab(), // 🆕
        ],
      ),
    );
  }

  Widget _buildPublicTab() {
    if (_bootstrapping) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _FiltersCard(
            useNearby: _useNearby,
            onToggleNearby: (v) {
              setState(() {
                _useNearby = v;
                _roomsFuture = _fetchRooms();
              });
            },
            currentCityLabel: _filters.cityName ?? _myCity ?? 'Seleccionar…',
            onPickCity: _pickCity,
            onClearCity: _clearCity,
            dateLabel: _filters.date == null
                ? 'Fecha (opcional)'
                : '${_filters.date!.day.toString().padLeft(2, '0')}/${_filters.date!.month.toString().padLeft(2, '0')}/${_filters.date!.year}',
            onPickDate: _pickDate,
            onClearDate: _clearDate,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RefreshIndicator(
            color: Colors.blueAccent,
            onRefresh: _onRefresh,
            child: FutureBuilder<List<Room>>(
              future: _roomsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                final rooms = snap.data ?? const <Room>[];

                if (rooms.isEmpty) {
                  return _EmptyState(
                    title: 'No hay salas públicas según tus filtros',
                    message:
                        'Prueba otra fecha, cambia la ciudad o crea tu propia sala.',
                    actionText: 'Crear una sala',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateRoomPage()),
                      );
                    },
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) {
                    final r = rooms[i];
                    return RoomCard(
                      room: r,
                      userLat: _filters.userLat,
                      userLng: _filters.userLng,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(room: r),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRoomsTab() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text('Inicia sesión para ver tus salas.',
            style: TextStyle(color: Colors.white54)),
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
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        List<Room> rooms = (snap.data ?? []);
        // Aplica regla: mixto o mismo sexo
        final u = _normalizeSex(_userSex);
        rooms = rooms.where((r) {
          final s = (r.sex ?? 'mixto').toLowerCase();
          return s == 'mixto' || s == u;
        }).toList();

        if (rooms.isEmpty) {
          return const Center(
            child: Text('Aún no te has unido ni has creado salas.',
                style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (_, i) {
            final r = rooms[i];
            return RoomCard(
              room: r,
              userLat: _filters.userLat,
              userLng: _filters.userLng,
              showCountdown: true, // 🆕 Enabled for My Rooms
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomDetailPage(room: r)),
                );
              },
            );
          },
        );
      },
    );
  }
}

// =================== Widgets auxiliares UI ===================

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
    final cityEmpty = currentCityLabel.trim().isEmpty ||
        currentCityLabel.toLowerCase().contains('seleccionar');

    final dateEmpty = dateLabel.toLowerCase().contains('opcional');

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
                    isEmpty: cityEmpty,
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
                    isEmpty: dateEmpty,
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
  final bool isEmpty;

  const _ActionField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
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
