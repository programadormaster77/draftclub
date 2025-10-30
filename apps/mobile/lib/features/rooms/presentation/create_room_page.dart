import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';
import '../data/room_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// ⚽ CreateRoomPage — Crear y compartir nuevas salas
/// ====================================================================
/// 🔹 Compatible para crear o editar salas.
/// 🔹 Evita errores de Dropdown (género duplicado o no coincidente).
/// 🔹 Compatible con cualquier país (ciudad, país, coordenadas).
/// 🔹 Corrige el bug cuando `sex` está vacío o con espacios.
/// ====================================================================
class CreateRoomPage extends StatefulWidget {
  final Map<String, dynamic>? existingRoom; // 👈 si llega, estamos editando
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
  String? _sex; // ahora puede ser null hasta cargar
  String? _lastCreatedRoomId;

  Map<String, dynamic>? _selectedCityData;
  Map<String, dynamic>? _selectedAddressData;

  @override
  void initState() {
    super.initState();
    _initializeForm();
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

  // ===========================================================
  // 🔄 Inicializar datos (crear o editar)
  // ===========================================================
  Future<void> _initializeForm() async {
    final r = widget.existingRoom;
    if (r != null) {
      // 🧠 Editando sala existente
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
    } else {
      // 🧠 Nuevo registro → prellenar sexo desde perfil
      await _prefillSexFromProfile();
    }
    setState(() {});
  }

  // ===========================================================
  // 👤 Autocompletar “Género del partido” desde el perfil
  // ===========================================================
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
  // 🧱 Crear o actualizar sala
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
        'countryCode': cityData?['countryCode'],
        'sex': _normalizeSex(_sex),
      };

      String roomId;
      if (widget.existingRoom != null) {
        // 🟢 Editar sala existente
        roomId = widget.existingRoom!['id'];
        await service.updateRoom(roomId, payload);
      } else {
        // 🟢 Crear nueva sala
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
        );
      }

      if (!mounted) return;
      setState(() => _lastCreatedRoomId = roomId);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.greenAccent.shade400,
        content: Text(
          widget.existingRoom != null
              ? '✅ Sala actualizada correctamente'
              : '✅ Sala creada correctamente (ID: $roomId)',
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

  // ===========================================================
  // 📤 Compartir enlace
  // ===========================================================
  Future<void> _shareRoomLink() async {
    if (_lastCreatedRoomId == null) return;
    final link = 'draftclub://room/$_lastCreatedRoomId';
    await Share.share(
      '⚽ ¡Únete a mi sala en DraftClub!\n$link',
      subject: 'Únete a mi sala ⚽',
    );
  }

  // ===========================================================
  // 🗓️ Fecha y hora
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
      _eventAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // ===========================================================
  // 📍 Selectores (ciudad / dirección)
  // ===========================================================
  Future<void> _openCityPicker() async {
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
            setSheet(() => _searchingCity = true);
            final results = await PlaceService.fetchCitySuggestions(query);
            setSheet(() {
              suggestions = results
                  .map((r) => {'name': r.description, 'placeId': r.placeId})
                  .toList();
              _searchingCity = false;
            });
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
                      'cityName': details.description,
                      'lat': details.lat,
                      'lng': details.lng,
                      'countryCode':
                          (details.description.split(',').last).trim(),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.blueAccent, width: 1),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
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
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Nombre de la sala'),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Por favor, escribe un nombre'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: _openCityPicker,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _cityCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Ciudad').copyWith(
                              prefixIcon: const Icon(Icons.location_on,
                                  color: Colors.blueAccent)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: _openAddressPicker,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _addressCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _inputDecoration('Dirección exacta (opcional)'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Dropdown universal seguro
                    DropdownButtonFormField<String>(
                      value: _normalizeSex(_sex),
                      dropdownColor: const Color(0xFF1A1A1A),
                      decoration: _inputDecoration('Género del partido'),
                      items: const [
                        DropdownMenuItem(
                            value: 'masculino', child: Text('Masculino')),
                        DropdownMenuItem(
                            value: 'femenino', child: Text('Femenino')),
                        DropdownMenuItem(value: 'mixto', child: Text('Mixto')),
                      ],
                      onChanged: (v) => setState(() => _sex = v),
                      validator: (v) =>
                          v == null ? 'Selecciona un género' : null,
                    ),

                    const SizedBox(height: 20),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _eventAt == null
                            ? 'Seleccionar fecha y hora'
                            : 'Fecha: ${_eventAt!.day}/${_eventAt!.month}/${_eventAt!.year} ${_eventAt!.hour.toString().padLeft(2, '0')}:${_eventAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today,
                            color: Colors.blueAccent),
                        onPressed: _selectDateTime,
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 10),

                    _buildDropdown<int>(
                        label: 'Número de equipos',
                        value: _teams,
                        items: [2, 4, 6, 8, 10],
                        onChanged: (v) => setState(() => _teams = v!)),

                    _buildDropdown<int>(
                        label: 'Jugadores por equipo',
                        value: _players,
                        items: [5, 7, 9, 11],
                        onChanged: (v) => setState(() => _players = v!)),

                    _buildDropdown<int>(
                        label: 'Cambios / Reemplazos',
                        value: _subs,
                        items: [0, 1, 2, 3, 5],
                        onChanged: (v) => setState(() => _subs = v!)),

                    SwitchListTile.adaptive(
                      title: const Text('Sala pública',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Desactívalo para hacerla privada',
                          style: TextStyle(color: Colors.white70)),
                      activeColor: Colors.blueAccent,
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: _loading ? null : _createOrUpdateRoom,
                      icon:
                          const Icon(Icons.sports_soccer, color: Colors.white),
                      label: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              widget.existingRoom != null
                                  ? 'Guardar cambios'
                                  : 'Crear sala',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 16),

                    if (_lastCreatedRoomId != null)
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
                ),
              ),
            ),
    );
  }

  // ===========================================================
  // 🎨 Estilos
  // ===========================================================
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
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        dropdownColor: const Color(0xFF1C1C1C),
        value: value,
        decoration: _inputDecoration(label),
        items: items
            .map((n) => DropdownMenuItem(
                value: n,
                child: Text('$n', style: const TextStyle(color: Colors.white))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
