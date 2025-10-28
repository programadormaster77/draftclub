import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';
import '../data/room_service.dart';

/// ====================================================================
/// ⚽ CreateRoomPage — Crear y compartir nuevas salas
/// ====================================================================
/// 🔹 Integra Google Places para seleccionar ciudad con precisión.
/// 🔹 Guarda nombre, coordenadas y país.
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
  DateTime? _eventAt;
  int _teams = 2;
  int _players = 5;
  int _subs = 2;
  bool _isPublic = true;
  bool _loading = false;
  bool _searchingCity = false;
  String? _lastCreatedRoomId;

  // Datos de la ciudad seleccionada
  Map<String, dynamic>? _selectedCityData;

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

      final roomId = await service.createRoom(
        name: _nameCtrl.text.trim(),
        teams: _teams,
        playersPerTeam: _players,
        substitutes: _subs,
        isPublic: _isPublic,
        manualCity: cityData?['cityName'] ?? _cityCtrl.text.trim(),
        eventAt: _eventAt,
        cityLat: cityData?['lat'],
        cityLng: cityData?['lng'],
        countryCode: cityData?['countryCode'],
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
                  .map((r) => {
                        'name': r.description,
                        'placeId': r.placeId,
                      })
                  .toList();
              _searchingCity = false;
            });
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Buscar ciudad o país',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ejemplo: Bogotá, Madrid...',
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
                  const SizedBox(height: 16),
                  if (_searchingCity)
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
                          'Escribe para buscar ciudades',
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
                              s['name'],
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () async {
                              final details = await PlaceService.getCityDetails(
                                  s['placeId']);
                              if (details != null) {
                                Navigator.pop(context, {
                                  'cityName': details.description,
                                  'lat': details.lat,
                                  'lng': details.lng,
                                  'countryCode': details.description
                                      .split(',')
                                      .last
                                      .trim(),
                                });
                              } else {
                                Navigator.pop(context, s);
                              }
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
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedCityData = result;
          _cityCtrl.text = result['cityName'] ?? result['name'];
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
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
                    decoration: _inputDecoration(
                      'Ciudad (opcional, detectada si se deja vacía)',
                    ).copyWith(
                      prefixIcon: const Icon(Icons.location_on,
                          color: Colors.blueAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
        initialValue: value,
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
