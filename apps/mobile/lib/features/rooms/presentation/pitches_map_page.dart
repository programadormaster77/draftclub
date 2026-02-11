// lib/features/rooms/presentation/pitches_map_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:draftclub_mobile/core/location/place_service.dart';

/// ===============================================================
/// 🗺️ PitchesMapPage — Mapa premium de canchas cercanas (Google Places)
/// ===============================================================
/// - Abre un mapa centrado en la ubicación del usuario.
/// - Busca canchas cercanas (Places Nearby Search) y dibuja markers.
/// - Tap en marker -> bottom sheet con info y acciones (cómo llegar / llamar / abrir maps).
/// - UX premium: chips de radio + “Buscar en esta zona” tras mover el mapa.
/// ===============================================================
class PitchesMapPage extends StatefulWidget {
  const PitchesMapPage({super.key});

  @override
  State<PitchesMapPage> createState() => _PitchesMapPageState();
}

class _PitchesMapPageState extends State<PitchesMapPage> {
  GoogleMapController? _map;

  // Estado de ubicación / permisos
  bool _locating = true;
  bool _hasLocationPermission = false;
  Position? _myPos;

  // Estado Places
  bool _loadingPlaces = false;
  String? _error;
  List<PitchPlace> _places = [];
  PitchPlace? _selected;
  PlaceContactDetails? _selectedContact;

  // UI / mapa
  Set<Marker> _markers = {};
  double _radiusKm = 5; // default premium
  bool _showSearchThisArea = false;
  LatLng? _lastSearchCenter;
  LatLng? _pendingCenter;

  Timer? _moveDebounce;

  // Para “actualizado hace…”
  DateTime? _lastUpdatedAt;

  static const _bg = Color(0xFF0E0E0E);
  static const _surface = Color(0xFF111111);
  static const _surface2 = Color(0xFF141414);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    final ok = await _ensureLocationPermission();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _locating = false;
        _hasLocationPermission = false;
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      setState(() {
        _myPos = pos;
        _locating = false;
        _hasLocationPermission = true;
      });

      final center = LatLng(pos.latitude, pos.longitude);
      _lastSearchCenter = center;
      await _searchPitches(center: center, animateCamera: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _hasLocationPermission = true; // permisos ok, pero no logró ubicación
        _error = 'No pudimos obtener tu ubicación. Intenta de nuevo.';
      });
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _searchPitches({
    required LatLng center,
    bool animateCamera = false,
  }) async {
    setState(() {
      _loadingPlaces = true;
      _error = null;
      _showSearchThisArea = false;
      _selected = null;
      _selectedContact = null;
    });

    try {
      if (animateCamera && _map != null) {
        await _map!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: center, zoom: 14.2),
          ),
        );
      }

      final results = await PlaceService.fetchNearbySoccerPitches(
        lat: center.latitude,
        lng: center.longitude,
        radiusMeters: (_radiusKm * 1000).toDouble(),
      );

      final mk = <Marker>{};
      for (final p in results) {
        mk.add(
          Marker(
            markerId: MarkerId(p.placeId),
            position: LatLng(p.lat, p.lng),
            onTap: () => _onSelectPlace(p),
            infoWindow: InfoWindow(title: p.name),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _places = results;
        _markers = mk;
        _loadingPlaces = false;
        _lastUpdatedAt = DateTime.now();
        _lastSearchCenter = center;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPlaces = false;
        _error = 'No pudimos cargar canchas ahora. Reintenta.';
        _places = [];
        _markers = {};
      });
    }
  }

  Future<void> _onSelectPlace(PitchPlace p) async {
    setState(() {
      _selected = p;
      _selectedContact = null;
    });

    // Cargamos detalles de contacto solo cuando el usuario toca una cancha
    final details = await PlaceService.getPlaceContactDetails(p.placeId);
    if (!mounted) return;
    setState(() {
      _selectedContact = details;
    });

    // Enfocar cámara suavemente
    if (_map != null) {
      await _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(p.lat, p.lng), zoom: 15.2),
        ),
      );
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _pendingCenter = pos.target;

    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      // Si el centro se movió lo suficiente respecto a la última búsqueda, mostramos “Buscar en esta zona”
      final last = _lastSearchCenter;
      final now = _pendingCenter;
      if (last == null || now == null) return;

      final movedMeters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        now.latitude,
        now.longitude,
      );

      // Umbral: 450m para no molestar
      if (movedMeters > 450) {
        setState(() => _showSearchThisArea = true);
      }
    });
  }

  Future<void> _searchThisArea() async {
    final center = _pendingCenter ?? _lastSearchCenter;
    if (center == null) return;
    await _searchPitches(center: center);
  }

  Future<void> _recenter() async {
    if (_myPos == null) {
      await _bootstrap();
      return;
    }
    final center = LatLng(_myPos!.latitude, _myPos!.longitude);
    _pendingCenter = center;
    await _searchPitches(center: center, animateCamera: true);
  }

  Future<void> _openDirections(LatLng to) async {
    // Universal Google Maps directions URL
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInMaps(LatLng to, {String? query}) async {
    final q = Uri.encodeComponent(query ?? '${to.latitude},${to.longitude}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    await launchUrl(uri);
  }

  String _distanceLabelToSelected() {
    final p = _selected;
    final me = _myPos;
    if (p == null || me == null) return '';
    final meters = Geolocator.distanceBetween(
      me.latitude,
      me.longitude,
      p.lat,
      p.lng,
    );
    if (meters < 950) return '${meters.toInt()} m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  String _updatedLabel() {
    final t = _lastUpdatedAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 15) return 'Actualizado ahora';
    if (diff.inMinutes < 1) return 'Actualizado hace ${diff.inSeconds}s';
    if (diff.inHours < 1) return 'Actualizado hace ${diff.inMinutes} min';
    return 'Actualizado hace ${diff.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    final canShowMap = _hasLocationPermission && !_locating;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // =======================
          // MAPA
          // =======================
          Positioned.fill(
            child: canShowMap
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _myPos != null
                          ? LatLng(_myPos!.latitude, _myPos!.longitude)
                          : const LatLng(4.7110, -74.0721), // fallback Bogotá
                      zoom: 14.0,
                    ),
                    onMapCreated: (c) => _map = c,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    buildingsEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    onCameraMove: _onCameraMove,
                    onTap: (_) {
                      setState(() {
                        _selected = null;
                        _selectedContact = null;
                      });
                    },
                  )
                : Container(
                    color: _bg,
                    alignment: Alignment.center,
                    child: _buildNoLocationState(),
                  ),
          ),

          // =======================
          // HEADER overlay (premium)
          // =======================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _buildHeader(context),
            ),
          ),

          // =======================
          // FAB recenter
          // =======================
          Positioned(
            right: 14,
            bottom: 190,
            child: _buildRecenterButton(),
          ),

          // =======================
          // “Buscar en esta zona”
          // =======================
          if (_showSearchThisArea)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 0,
              right: 0,
              child: Center(
                child: _SearchThisAreaPill(
                  loading: _loadingPlaces,
                  onTap: _searchThisArea,
                ),
              ),
            ),

          // =======================
          // Bottom Sheet
          // =======================
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _bg.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Canchas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Radios chips
          _RadiusChip(
            km: 2,
            selected: _radiusKm == 2,
            onTap: () async {
              setState(() => _radiusKm = 2);
              await _searchPitches(center: _lastSearchCenter ?? _pendingCenter ?? _fallbackCenter());
            },
          ),
          const SizedBox(width: 6),
          _RadiusChip(
            km: 5,
            selected: _radiusKm == 5,
            onTap: () async {
              setState(() => _radiusKm = 5);
              await _searchPitches(center: _lastSearchCenter ?? _pendingCenter ?? _fallbackCenter());
            },
          ),
          const SizedBox(width: 6),
          _RadiusChip(
            km: 10,
            selected: _radiusKm == 10,
            onTap: () async {
              setState(() => _radiusKm = 10);
              await _searchPitches(center: _lastSearchCenter ?? _pendingCenter ?? _fallbackCenter());
            },
          ),
        ],
      ),
    );
  }

  LatLng _fallbackCenter() {
    final me = _myPos;
    if (me != null) return LatLng(me.latitude, me.longitude);
    return const LatLng(4.7110, -74.0721);
  }

  Widget _buildRecenterButton() {
    return Material(
      color: _bg.withOpacity(0.90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _recenter,
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.20,
      minChildSize: 0.14,
      maxChildSize: 0.58,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),

              // Header sheet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Canchas cerca',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_lastUpdatedAt != null)
                      Text(
                        _updatedLabel(),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Body: estados / seleccionado / lista
              Expanded(
                child: _buildSheetBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetBody(ScrollController c) {
    // Loading
    if (_locating || _loadingPlaces) {
      return ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          const _SheetInfoBanner(
            icon: Icons.search,
            title: 'Buscando canchas cerca…',
            subtitle: 'Usamos tu ubicación para mostrar opciones cercanas.',
          ),
          const SizedBox(height: 12),
          ...List.generate(
            6,
            (i) => const _SkeletonTile(),
          ),
        ],
      );
    }

    // No permission
    if (!_hasLocationPermission) {
      return ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          const _SheetInfoBanner(
            icon: Icons.location_off,
            title: 'Activa tu ubicación',
            subtitle: 'Para mostrar canchas cerca, DraftClub necesita acceso a tu ubicación.',
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _bootstrap,
            child: const Text('Permitir ubicación', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    // Error
    if (_error != null) {
      return ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          _SheetInfoBanner(
            icon: Icons.cloud_off,
            title: 'No pudimos cargar canchas',
            subtitle: _error!,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _searchPitches(center: _lastSearchCenter ?? _fallbackCenter()),
            child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    // Selected place card first
    final selected = _selected;
    if (selected != null) {
      return ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          _PlaceCard(
            place: selected,
            distanceLabel: _distanceLabelToSelected(),
            contact: _selectedContact,
            onDirections: () => _openDirections(LatLng(selected.lat, selected.lng)),
            onOpenMaps: () => _openInMaps(LatLng(selected.lat, selected.lng), query: selected.name),
            onCall: () {
              final phone = _selectedContact?.phone ?? _selectedContact?.internationalPhone;
              if (phone != null && phone.trim().isNotEmpty) {
                _callPhone(phone);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Más canchas',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ..._places.take(12).map((p) => _PlaceListTile(
                place: p,
                selected: p.placeId == selected.placeId,
                onTap: () => _onSelectPlace(p),
              )),
        ],
      );
    }

    // Empty
    if (_places.isEmpty) {
      return ListView(
        controller: c,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          const _SheetInfoBanner(
            icon: Icons.search_off,
            title: 'No encontramos canchas en este radio',
            subtitle: 'Prueba ampliando el radio o moviendo el mapa.',
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              setState(() => _radiusKm = 10);
              await _searchPitches(center: _lastSearchCenter ?? _fallbackCenter());
            },
            child: const Text('Aumentar radio', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _recenter,
            child: const Text('Recentrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    // List
    return ListView.builder(
      controller: c,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
      itemCount: _places.length.clamp(0, 25),
      itemBuilder: (_, i) {
        final p = _places[i];
        return _PlaceListTile(
          place: p,
          selected: false,
          onTap: () => _onSelectPlace(p),
        );
      },
    );
  }

  Widget _buildNoLocationState() {
    // Estado superior si no hay permiso / servicio
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, color: Colors.white54, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Activa tu ubicación',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para mostrar canchas cerca, DraftClub necesita acceso a tu ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _bootstrap,
              child: const Text('Permitir ubicación', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// =================== Widgets UI pequeños ===================

class _RadiusChip extends StatelessWidget {
  final double km;
  final bool selected;
  final VoidCallback onTap;

  const _RadiusChip({
    required this.km,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.blueAccent.withOpacity(0.22) : const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? Colors.blueAccent : Colors.white24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            '${km.toInt()} km',
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchThisAreaPill extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _SearchThisAreaPill({
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Colors.white24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                )
              else
                const Icon(Icons.search, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text(
                'Buscar en esta zona',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetInfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SheetInfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Container(height: 10, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 8),
                Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  final PitchPlace place;
  final bool selected;
  final VoidCallback onTap;

  const _PlaceListTile({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.blueAccent.withOpacity(0.12) : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? Colors.blueAccent : Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.sports_soccer, color: Colors.blueAccent),
        title: Text(
          place.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          place.address ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PitchPlace place;
  final String distanceLabel;
  final PlaceContactDetails? contact;
  final VoidCallback onDirections;
  final VoidCallback onOpenMaps;
  final VoidCallback onCall;

  const _PlaceCard({
    required this.place,
    required this.distanceLabel,
    required this.contact,
    required this.onDirections,
    required this.onOpenMaps,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final phone = contact?.phone ?? contact?.internationalPhone;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + badges
          Row(
            children: [
              Expanded(
                child: Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (distanceLabel.isNotEmpty) ...[
                const SizedBox(width: 10),
                _Badge(text: distanceLabel),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (place.rating != null) ...[
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${place.rating!.toStringAsFixed(1)}'
                  '${place.userRatingsTotal != null ? ' (${place.userRatingsTotal})' : ''}',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if ((place.address ?? '').trim().isNotEmpty)
            Text(
              place.address!,
              style: const TextStyle(color: Colors.white60),
            ),

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onOpenMaps,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Abrir Maps', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Call (only if exists)
          if (hasPhone)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onCall,
                icon: const Icon(Icons.call, size: 18),
                label: Text('Llamar ${phone!}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.50)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
