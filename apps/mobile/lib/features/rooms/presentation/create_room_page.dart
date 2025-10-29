import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';
import '../data/room_service.dart';

// 🔽 NUEVO: para autocompletar el género del partido desde el perfil (users/<uid>.sex)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// ⚽ CreateRoomPage — Crear y compartir nuevas salas
/// ====================================================================
/// 🔹 Integra Google Places para seleccionar ciudad y dirección exacta.
/// 🔹 Guarda nombre, coordenadas, país y género del partido.
/// 🔹 Crea la sala y permite compartir el enlace dinámico.
/// ====================================================================
class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

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
  String _sex = 'Masculino'; // 🧩 Campo (Masculino / Femenino / Mixto)
  String? _lastCreatedRoomId;

  // Datos de ciudad y dirección seleccionadas
  Map<String, dynamic>? _selectedCityData;
  Map<String, dynamic>? _selectedAddressData;

  @override
  void initState() {
    super.initState();
    _prefillSexFromProfile(); // 🔹 Autocompleta el “Género del partido” según users/<uid>.sex
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
      if (sex is String && sex.isNotEmpty) {
        if (!mounted) return;
        // Normalizamos a nuestras opciones
        final normalized = sex.toLowerCase().startsWith('f')
            ? 'Femenino'
            : sex.toLowerCase().startsWith('m')
                ? 'Masculino'
                : 'Mixto';
        setState(() => _sex = normalized);
      }
    } catch (_) {
      // silencioso; si no hay perfil, usamos el default 'Masculino'
    }
  }

  // ===========================================================
  // 🧱 Crear la sala
  // ===========================================================
  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _lastCreatedRoomId = null;
    });

    try {
      final service = RoomService();
      final cityData = _selectedCityData;
      final addressData = _selectedAddressData;

      final roomId = await service.createRoom(
        name: _nameCtrl.text.trim(),
        teams: _teams,
        playersPerTeam: _players,
        substitutes: _subs,
        isPublic: _isPublic,
        manualCity: cityData?['cityName'] ?? _cityCtrl.text.trim(),
        exactAddress: addressData?['address'] ?? _addressCtrl.text.trim(),
        eventAt: _eventAt,
        cityLat: addressData?['lat'] ?? cityData?['lat'],
        cityLng: addressData?['lng'] ?? cityData?['lng'],
        countryCode: cityData?['countryCode'],
        sex: _sex, // ✅ Guardamos el género del partido
      );

      if (!mounted) return;
      setState(() => _lastCreatedRoomId = roomId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.greenAccent.shade400,
          content: Text(
            '✅ Sala creada correctamente (ID: $roomId)',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent.shade700,
          content: Text('❌ Error al crear sala: $e'),
        ),
      );
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
    final message = '''
⚽ ¡Únete a mi sala en DraftClub!
Haz clic en el siguiente enlace para entrar directamente:
$link
''';
    await Share.share(message, subject: 'Únete a mi sala en DraftClub ⚽');
  }

  // ===========================================================
  // 🗓️ Fecha y hora del partido
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
  // 📍 Selector de ciudad (Google Places)
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
              // 🔧 Obtenemos detalles para lat/lng y country
              final details = await PlaceService.getCityDetails(s['placeId']);
              final data = details != null
                  ? {
                      'cityName': details.description,
                      'lat': details.lat,
                      'lng': details.lng,
                      'countryCode':
                          (details.description.split(',').last).trim(),
                    }
                  : {
                      'cityName': s['name'],
                      'lat': null,
                      'lng': null,
                      'countryCode': null,
                    };
              if (!mounted) return;
              setState(() {
                _selectedCityData = data;
                _cityCtrl.text = data['cityName'] ?? s['name'] ?? '';
              });
            },
            getDetails: PlaceService.getCityDetails,
            labelField: 'name',
          );
        });
      },
    );
  }

  // ===========================================================
  // 🏠 Selector de dirección exacta (Google Places)
  // ===========================================================
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
              // ✅ Corregido: al seleccionar, llenamos el campo y guardamos lat/lng
              setState(() {
                _selectedAddressData = {
                  'address': s['address'],
                  'lat': s['lat'],
                  'lng': s['lng'],
                };
                _addressCtrl.text = s['address'] ?? '';
              });
            },
            getDetails: null,
            labelField: 'address',
          );
        });
      },
    );
  }

  // ===========================================================
  // 🧭 UI del bottom sheet reutilizable
  //  - Corregido: ejecuta onSelect(s) y luego cierra el sheet
  // ===========================================================
  Widget _placeSheetUI({
    required String title,
    required TextEditingController searchCtrl,
    required bool searching,
    required List<Map<String, dynamic>> suggestions,
    required Future<void> Function(String) onSearch,
    required void Function(Map<String, dynamic>) onSelect,
    required String labelField,
    Future<dynamic> Function(String)? getDetails,
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
                    color: Colors.blueAccent,
                    strokeWidth: 2.5,
                  ),
                )
              else if (suggestions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      'Escribe para buscar...',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                )
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
                        title: Text(
                          '${s[labelField]}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          onSelect(s); // ✅ aplica selección
                          Navigator.pop(context); // ✅ cierra el sheet
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
  // 🖥️ INTERFAZ DE USUARIO
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Crear Sala',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // 🔹 Nombre
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Nombre de la sala'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Por favor, escribe un nombre'
                    : null,
              ),
              const SizedBox(height: 20),

              // 🔹 Selector de ciudad
              GestureDetector(
                onTap: _openCityPicker,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _cityCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _inputDecoration('Ciudad donde se jugará').copyWith(
                      prefixIcon: const Icon(Icons.location_on,
                          color: Colors.blueAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Dirección exacta
              GestureDetector(
                onTap: _openAddressPicker,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _addressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Dirección exacta (opcional)')
                        .copyWith(
                      prefixIcon:
                          const Icon(Icons.home_work, color: Colors.blueAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 🔹 Género del partido
              _buildDropdown<String>(
                label: 'Género del partido',
                value: _sex,
                items: const ['Masculino', 'Femenino', 'Mixto'],
                onChanged: (v) => setState(() => _sex = v ?? 'Masculino'),
              ),

              const SizedBox(height: 10),

              // 🔹 Fecha y hora
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _eventAt == null
                      ? 'Seleccionar fecha y hora del partido (opcional)'
                      : 'Fecha: ${_eventAt!.day}/${_eventAt!.month}/${_eventAt!.year}  ${_eventAt!.hour.toString().padLeft(2, '0')}:${_eventAt!.minute.toString().padLeft(2, '0')}',
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
                onChanged: (v) => setState(() => _teams = v!),
              ),
              _buildDropdown<int>(
                label: 'Jugadores por equipo',
                value: _players,
                items: [5, 7, 9, 11],
                onChanged: (v) => setState(() => _players = v!),
              ),
              _buildDropdown<int>(
                label: 'Cambios / Reemplazos',
                value: _subs,
                items: [0, 1, 2, 3, 5],
                onChanged: (v) => setState(() => _subs = v!),
              ),

              const SizedBox(height: 10),

              SwitchListTile.adaptive(
                title: const Text('Sala pública',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Desactívalo para hacerla privada',
                    style: TextStyle(color: Colors.white70)),
                activeColor: Colors.blueAccent,
                inactiveThumbColor: Colors.grey,
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 30),

              // 🔹 Botón Crear
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _loading ? null : _createRoom,
                icon: const Icon(Icons.sports_soccer, color: Colors.white),
                label: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Crear sala',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              if (_lastCreatedRoomId != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _shareRoomLink,
                  icon: const Icon(Icons.share, color: Colors.black),
                  label: const Text(
                    'Compartir enlace de la sala',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // 🎨 Widgets auxiliares
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
                  child:
                      Text('$n', style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
