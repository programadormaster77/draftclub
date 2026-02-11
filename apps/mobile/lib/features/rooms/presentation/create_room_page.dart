import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';
import '../data/room_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/profile/domain/xp_tracker.dart';

/// ====================================================================
/// ⚽ CreateRoomPage — Crear y compartir nuevas salas
/// ====================================================================
/// 🔹 Compatible para crear o editar salas.
/// 🔹 Evita errores de Dropdown (género duplicado o no coincidente).
/// 🔹 Compatible con cualquier país (ciudad, país, coordenadas).
/// 🔹 Corrige el bug cuando `sex` está vacío o con espacios.
/// 🔹 Otorga XP al crear una sala.
/// ====================================================================
class CreateRoomPage extends StatefulWidget {
  final Map<String, dynamic>? existingRoom;
  const CreateRoomPage({super.key, this.existingRoom});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _eventAt;
  int _teams = 2;
  int _players = 5;
  int _subs = 2;
  bool _isPublic = true;
  bool _loading = false;
  bool _searchingCity = false;
  bool _searchingAddress = false;
  String? _sex; // puede ser null hasta cargar
  String? _lastCreatedRoomId;

  Map<String, dynamic>? _selectedCityData;
  Map<String, dynamic>? _selectedAddressData;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  // ===========================================================
  // 🌍 Extrae y normaliza el código ISO de país desde el texto
  // ===========================================================
  String _extractCountryCode(String description) {
    final lower = description.toLowerCase();

    if (lower.contains('colom')) return 'CO';
    if (lower.contains('mex')) return 'MX';
    if (lower.contains('arg')) return 'AR';
    if (lower.contains('esp') || lower.contains('espa')) return 'ES';
    if (lower.contains('chi')) return 'CL';
    if (lower.contains('per')) return 'PE';
    if (lower.contains('ecuad')) return 'EC';
    if (lower.contains('bra')) return 'BR';
    if (lower.contains('venez')) return 'VE';
    if (lower.contains('us') || lower.contains('eeuu')) return 'US';
    if (lower.contains('fran')) return 'FR';
    if (lower.contains('ita')) return 'IT';
    if (lower.contains('ale')) return 'DE';
    if (lower.contains('jap')) return 'JP';
    if (lower.contains('canad')) return 'CA';
    if (lower.contains('por')) return 'PT';
    if (lower.contains('turq')) return 'TR';
    if (lower.contains('rusi')) return 'RU';
    if (lower.contains('india')) return 'IN';
    if (lower.contains('corea')) return 'KR';
    if (lower.contains('chin')) return 'CN';
    if (lower.contains('austral')) return 'AU';
    return 'XX';
  }

  // ===========================================================
  // 🔄 Inicializar datos
  // ===========================================================
  Future<void> _initializeForm() async {
    final r = widget.existingRoom;
    if (r != null) {
      _nameCtrl.text = r['name'] ?? '';
      _cityCtrl.text = r['city'] ?? '';
      _addressCtrl.text = r['exactAddress'] ?? '';
      _eventAt = (r['eventAt'] is Timestamp)
          ? (r['eventAt'] as Timestamp).toDate()
          : r['eventAt'];
      _teams = (r['teams'] ?? 2);
      _players = (r['playersPerTeam'] ?? 5);
      _subs = (r['substitutes'] ?? 2);
      _isPublic = (r['isPublic'] ?? true);
      _sex = _normalizeSex(r['sex']);
      _matchType = r['matchType'] ?? 'friendly';
    } else {
      await _prefillSexFromProfile();
      _detectUserLocation(); // 🚀 Auto-detectar ciudad
    }
    setState(() {});
  }

  // ===========================================================
  // 📍 Auto-detectar Ubicación
  // ===========================================================
  Future<void> _detectUserLocation() async {
    setState(() => _locatingUser = true);
    try {
      // 1. Permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permisos de ubicación denegados';
        }
      }

      // 2. Coordenadas
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // 3. Geocodificación inversa (Coords -> Ciudad)
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Ej: "Bogotá", "MX", etc.
        final city = place.locality ?? place.subAdministrativeArea ?? '';
        final countryCode = place.isoCountryCode ?? 'XX';

        if (city.isNotEmpty) {
          setState(() {
            _cityCtrl.text = city;
            _selectedCityData = {
              'cityName': city,
              'lat': position.latitude,
              'lng': position.longitude,
              'countryCode': countryCode,
            };
          });
          debugPrint('📍 Ubicación detectada: $city ($countryCode)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error detectando ubicación: $e');
      // No mostramos error UI intrusivo, solo no se llena
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  // ===========================================================
  // 🔧 Normalizador seguro de género
  // ===========================================================
  String _normalizeSex(String? sex) {
    if (sex == null || sex.trim().isEmpty) return 'mixto';
    final s = sex.trim().toLowerCase();
    if (['masculino', 'femenino', 'mixto'].contains(s)) return s;
    return 'mixto';
  }

  Future<void> _prefillSexFromProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final sex = (snap.data() ?? const {})['sex'];
      _sex = _normalizeSex(sex);
    } catch (_) {
      _sex = 'mixto';
    }
  }

  // ===========================================================
  // 🧱 Guardar Sala
  // ===========================================================
  Future<void> _createOrUpdateRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final service = RoomService();
      final cityData = _selectedCityData;
      final addressData = _selectedAddressData;

      final payload = {
        'name': _nameCtrl.text.trim(),
        'teams': _teams,
        'playersPerTeam': _players,
        'substitutes': _subs,
        'isPublic': _isPublic,
        'manualCity': cityData?['cityName'] ?? _cityCtrl.text.trim(),
        'exactAddress': addressData?['address'] ?? _addressCtrl.text.trim(),
        'eventAt': _eventAt,
        'cityLat': addressData?['lat'] ?? cityData?['lat'],
        'cityLng': addressData?['lng'] ?? cityData?['lng'],
        'countryCode':
            cityData?['countryCode'] ?? 'XX', // TODO: Extract if manual
        'sex': _normalizeSex(_sex),
        'matchType': _matchType,
      };

      String roomId;

      if (widget.existingRoom != null) {
        roomId = widget.existingRoom!['id'];
        await service.updateRoom(roomId, payload);
      } else {
        roomId = await service.createRoom(
          name: payload['name'],
          teams: payload['teams'],
          playersPerTeam: payload['playersPerTeam'],
          substitutes: payload['substitutes'],
          isPublic: payload['isPublic'],
          manualCity: payload['manualCity'],
          exactAddress: payload['exactAddress'],
          eventAt: payload['eventAt'],
          cityLat: payload['cityLat'],
          cityLng: payload['cityLng'],
          countryCode: payload['countryCode'],
          sex: payload['sex'],
          matchType: payload['matchType'],
        );

        // 🎯 Asignar experiencia al crear una nueva sala
        await RoomXPTracker.onRoomCreated(roomId);
      }

      if (!mounted) return;
      setState(() => _lastCreatedRoomId = roomId);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.greenAccent.shade400,
        content: Text(
          widget.existingRoom != null
              ? '✅ Sala actualizada correctamente'
              : '✅ Sala creada (ID: $roomId)',
          style: const TextStyle(color: Colors.black),
        ),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.redAccent.shade700,
        content: Text('❌ Error: $e'),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareRoomLink() async {
    if (_lastCreatedRoomId == null) return;
    final link = 'draftclub://room/$_lastCreatedRoomId';
    await Share.share(
      '⚽ ¡Únete a mi sala en DraftClub!\n$link',
      subject: 'Únete a mi sala ⚽',
    );
  }

  // ===========================================================
  // 🗓️ Date Picker
  // ===========================================================
  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (pickedTime == null) return;
    setState(() {
      _eventAt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute);
    });
  }

  // ===========================================================
  // 📍 Location Pickers
  // ===========================================================
  Future<void> _openCityPicker() async {
    // ... (Keeping logic similar but using your PlaceService)
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> suggestions = [];

    await showModalBottomSheet<Map<String, dynamic>>(
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> search(String query) async {
          if (query.isEmpty) {
            setSheet(() => suggestions = []);
            return;
          }

          return _placeSheetUI(
            title: 'Buscar ciudad o país',
            searchCtrl: searchCtrl,
            searching: _searchingCity,
            suggestions: suggestions,
            onSearch: search,
            onSelect: (s) async {
              final details = await PlaceService.getCityDetails(s['placeId']);
              final data = details != null
                  ? {
                      'cityName': details.description.split(',').first.trim(),
                      'lat': details.lat,
                      'lng': details.lng,
                      'countryCode': _extractCountryCode(details.description),
                    }
                  : {'cityName': s['name']};

              if (!mounted) return;
              setState(() {
                _selectedCityData = data;
                _cityCtrl.text = data['cityName'] ?? '';
              });
            },
            labelField: 'name',
          );
        });
      },
    );
  }

  Future<void> _openAddressPicker() async {
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> suggestions = [];

    await showModalBottomSheet<Map<String, dynamic>>(
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheet) {
          Future<void> search(String query) async {
            if (query.isEmpty) {
              setSheet(() => suggestions = []);
              return;
            }
            setSheet(() => _searchingAddress = true);
            final results = await PlaceService.fetchAddressSuggestions(query);
            setSheet(() {
              suggestions = results
                  .map((r) => {
                        'address': r['address'],
                        'lat': r['lat'],
                        'lng': r['lng']
                      })
                  .toList();
              _searchingAddress = false;
            });
          }

          return _placeSheetUI(
            title: 'Buscar dirección exacta',
            searchCtrl: searchCtrl,
            searching: _searchingAddress,
            suggestions: suggestions,
            onSearch: search,
            onSelect: (s) {
              setState(() {
                _selectedAddressData = {
                  'address': s['address'],
                  'lat': s['lat'],
                  'lng': s['lng'],
                };
                _addressCtrl.text = s['address'] ?? '';
              });
            },
            labelField: 'address',
          );
        });
      },
    );
  }

  Widget _placeSheetUI({
    required String title,
    required TextEditingController searchCtrl,
    required bool searching,
    required List<Map<String, dynamic>> suggestions,
    required Future<void> Function(String) onSearch,
    required void Function(Map<String, dynamic>) onSelect,
    required String labelField,
  }) {
    // ... (Same Place Sheet UI)
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe aquí...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.location_on, color: Colors.blueAccent),
                  filled: true,
                  fillColor: const Color(0xFF111111),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.white24, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (searching)
                const Center(
                    child: CircularProgressIndicator(
                        color: Colors.blueAccent, strokeWidth: 2.5))
              else if (suggestions.isEmpty)
                const Expanded(
                    child: Center(
                        child: Text('Escribe para buscar...',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14))))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (context, i) {
                      final s = suggestions[i];
                      return ListTile(
                        leading: const Icon(Icons.location_city,
                            color: Colors.blueAccent),
                        title: Text('${s[labelField]}',
                            style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          onSelect(s);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // 🖥️ UI PRINCIPAL
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.existingRoom != null ? 'Editar Sala' : 'Crear Sala'),
      ),
      body: _sex == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. INFO GENERAL
                  _buildSectionTitle('Información General'),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Nombre de la partida'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  MatchTypeSelector(
                    selectedType: _matchType,
                    onTypeChanged: (v) => setState(() => _matchType = v),
                  ),

                  const SizedBox(height: 24),

                  // 2. CONFIGURACIÓN DEL JUEGO
                  _buildSectionTitle('Configuración del Juego'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Equipos',
                          value: _teams,
                          items: [2, 4, 6, 8],
                          onChanged: (v) => setState(() => _teams = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Jugadores',
                          value: _players,
                          items: [5, 6, 7, 8, 9, 10, 11],
                          onChanged: (v) => setState(() => _players = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<int>(
                          label: 'Suplentes',
                          value: _subs,
                          items: [0, 1, 2, 3, 4, 5],
                          onChanged: (v) => setState(() => _subs = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _normalizeSex(_sex),
                          dropdownColor: const Color(0xFF1A1A1A),
                          decoration: _inputDecoration('Género'),
                          items: const [
                            DropdownMenuItem(
                                value: 'masculino', child: Text('Masculino')),
                            DropdownMenuItem(
                                value: 'femenino', child: Text('Femenino')),
                            DropdownMenuItem(
                                value: 'mixto', child: Text('Mixto')),
                          ],
                          onChanged: (v) => setState(() => _sex = v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. UBICACIÓN Y FECHA
                  _buildSectionTitle('Ubicación y Fecha'),
                  GestureDetector(
                    onTap: _openCityPicker,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _cityCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Ciudad').copyWith(
                          prefixIcon: _locatingUser
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : const Icon(Icons.location_on,
                                  color: Colors.blueAccent),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _detectUserLocation, // 🎯 Manual trigger
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _openAddressPicker,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _addressCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            _inputDecoration('Dirección exacta (Sede/Cancha)'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _eventAt == null
                          ? 'Seleccionar fecha y hora'
                          : 'Fecha: ${_eventAt!.day}/${_eventAt!.month} - ${_eventAt!.hour}:${_eventAt!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(Icons.calendar_today,
                        color: Colors.blueAccent),
                    onTap: _selectDateTime,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white24)),
                  ),

                  const SizedBox(height: 24),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sala Pública',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Visible para todos en el feed',
                        style: TextStyle(color: Colors.white54)),
                    activeColor: Colors.blueAccent,
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),

                  const SizedBox(height: 30),

                  // BOTÓN DE ACCIÓN
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _loading ? null : _createOrUpdateRoom,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.existingRoom != null
                                ? 'Guardar Cambios'
                                : 'Crear Sala',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),

                  if (_lastCreatedRoomId != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _shareRoomLink,
                      icon: const Icon(Icons.share, color: Colors.black),
                      label: const Text(
                        'Compartir enlace',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: const Color(0xFF141414),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      dropdownColor: const Color(0xFF1C1C1C),
      value: value,
      decoration: _inputDecoration(label),
      items: items
          .map((n) => DropdownMenuItem(
              value: n,
              child: Text('$n', style: const TextStyle(color: Colors.white))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
