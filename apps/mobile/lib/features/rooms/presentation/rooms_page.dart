import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
/// ✅ Bloqueo si se busca en país distinto al actual
/// ✅ Fallback: si no hay cercanas, muestra por ciudad
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

        // Si no hay una ciudad objetivo aún, usa la del usuario
        _filterCityName ??= _myCity;
        // Nota: _filterCityLat/Lng se calcularán solo si el usuario
        // elige explícitamente una ciudad en el buscador (para precisión).
      });
    } catch (e) {
      setState(() => _loadingLoc = false);
    }
  }

  // ==========================================================
  // 🔎 Stream base de salas públicas
  // (filtrado fino se hace en cliente para soportar distancia/fecha)
  // ==========================================================
  Stream<List<Room>> _publicRoomsBaseStream() {
    return _db
        .collection('rooms')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(200)
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
  // 🧮 Aplicar filtros (distancia, ciudad, fecha, país)
  // ==========================================================
  List<Room> _applyFilters(List<Room> rooms) {
    // 1) Bloqueo por país cuando se selecciona ciudad objetivo
    if (_filterCountryCode != null &&
        _myCountryCode != null &&
        _filterCountryCode!.toUpperCase() != _myCountryCode!.toUpperCase()) {
      _showBlockedCountryDialog();
      // No mostramos nada cuando está bloqueado
      return const [];
    }

    // 2) Filtro por fecha (si se seleccionó)
    final DateTime? dayStart;
    final DateTime? dayEnd;
    if (_filterDate != null) {
      dayStart =
          DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      dayEnd = dayStart.add(const Duration(days: 1)).subtract(
            const Duration(milliseconds: 1),
          );
    } else {
      dayStart = null;
      dayEnd = null;
    }

    List<Room> filtered = rooms.where((r) {
      // País: si la sala tiene countryCode y yo lo tengo, deben coincidir
      if (r.countryCode != null &&
          _myCountryCode != null &&
          _filterCityName == null) {
        // Búsqueda "cerca de mí" o "mi ciudad": exigir mismo país del usuario
        if (r.countryCode!.toUpperCase() != _myCountryCode!.toUpperCase()) {
          return false;
        }
      }

      // Fecha (opcional)
      if (dayStart != null) {
        if (r.eventAt == null) return false;
        if (r.eventAt!.isBefore(dayStart) || r.eventAt!.isAfter(dayEnd!)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 3) Cercanía (si está activo y tengo mi lat/lng)
    List<Room> nearby = [];
    if (_useNearby && _myLat != null && _myLng != null) {
      nearby = filtered.where((r) {
        if (r.cityLat != null && r.cityLng != null) {
          final d = _distanceKm(_myLat!, _myLng!, r.cityLat!, r.cityLng!);
          return d <= _nearbyKm;
        }
        // Fallback: si no hay coordenadas, usa ciudad textual
        if (_myCity != null && r.city.toLowerCase() == _myCity!.toLowerCase()) {
          return true;
        }
        return false;
      }).toList();

      if (nearby.isNotEmpty) {
        // Ordenar por distancia (si es posible), sino por fecha
        nearby.sort((a, b) {
          double da = 1e9, db = 1e9;
          if (a.cityLat != null && a.cityLng != null) {
            da = _distanceKm(_myLat!, _myLng!, a.cityLat!, a.cityLng!);
          }
          if (b.cityLat != null && b.cityLng != null) {
            db = _distanceKm(_myLat!, _myLng!, b.cityLat!, b.cityLng!);
          }
          if (da != db) return da.compareTo(db);
          // empate → más reciente primero
          return (b.createdAt).compareTo(a.createdAt);
        });
        return nearby;
      }
      // Si no hubo cercanas, cae a filtro de ciudad abajo
    }

    // 4) Filtro por ciudad elegida (si la hay)
    if (_filterCityName != null && _filterCityName!.trim().isNotEmpty) {
      final nameLc = _filterCityName!.toLowerCase();
      // Si tengo coordenadas exactas de la ciudad buscada, ordenar por distancia a esa ciudad
      if (_filterCityLat != null && _filterCityLng != null) {
        final inCity = filtered.where((r) {
          if (r.cityLat != null && r.cityLng != null) {
            final d = _distanceKm(
                _filterCityLat!, _filterCityLng!, r.cityLat!, r.cityLng!);
            // dentro de ~30 km del centro de la ciudad buscada (radio generoso)
            return d <= 30;
          }
          return r.city.toLowerCase() == nameLc;
        }).toList();

        inCity.sort((a, b) {
          double da = 1e9, db = 1e9;
          if (a.cityLat != null && a.cityLng != null) {
            da = _distanceKm(
                _filterCityLat!, _filterCityLng!, a.cityLat!, a.cityLng!);
          }
          if (b.cityLat != null && b.cityLng != null) {
            db = _distanceKm(
                _filterCityLat!, _filterCityLng!, b.cityLat!, b.cityLng!);
          }
          if (da != db) return da.compareTo(db);
          return (b.createdAt).compareTo(a.createdAt);
        });

        return inCity;
      } else {
        // Sin lat/lng de la ciudad buscada → match por nombre
        final inCity =
            filtered.where((r) => r.city.toLowerCase() == nameLc).toList();
        inCity.sort((a, b) => (b.createdAt).compareTo(a.createdAt));
        return inCity;
      }
    }

    // 5) Sin filtros de ciudad/cercanía → ordenar por recientes
    filtered.sort((a, b) => (b.createdAt).compareTo(a.createdAt));
    return filtered;
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
                      // Limpia ciudad objetivo para volver al estado válido
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
                  title: 'No hay salas públicas cerca',
                  message:
                      'No encontramos partidos dentro del radio o filtros seleccionados.\n\u2022 Prueba otra fecha\n\u2022 Cambia la ciudad\n\u2022 O crea tu propia sala',
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

        final rooms = snap.data ?? [];
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
        room.cityLat != null &&
        room.cityLng != null) {
      final d = _distanceKm(_myLat!, _myLng!, room.cityLat!, room.cityLng!);
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
