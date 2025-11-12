// 📦 DEPENDENCIAS PRINCIPALES
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:draftclub_mobile/core/location/place_service.dart';
import 'profile_card_animation.dart';

/// ============================================================================
/// ⚙️ EditProfilePage — Edición avanzada de perfil (Versión 2025.11.05)
/// ============================================================================
/// ✅ Compatible con tus reglas actuales de Firebase.
/// ✅ Maneja JPG, JPEG y PNG correctamente.
/// ✅ Borra imágenes viejas de forma segura (sin errores si no existen).
/// ✅ Muestra mensajes de progreso durante la subida.
/// ============================================================================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  File? _imageFile;
  String? _currentPhotoUrl;
  bool _saving = false;
  bool _searchingCity = false;

  // Controladores
  final _nombreCtrl = TextEditingController();
  final _apodoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();

  // Campos especiales
  List<String> _selectedPositions = [];
  String _preferredFoot = 'Derecho';
  String _sex = 'Masculino';
  Map<String, dynamic>? _selectedCityData;

  final List<String> _posiciones = [
    'Portero',
    'Defensa Central',
    'Lateral Derecho',
    'Lateral Izquierdo',
    'Mediocampista Defensivo',
    'Mediocampista Central',
    'Mediocampista Ofensivo',
    'Extremo Derecho',
    'Extremo Izquierdo',
    'Delantero',
    'Segundo Delantero',
  ];

  final List<String> _pies = ['Derecho', 'Izquierdo', 'Ambos'];
  final List<String> _sexos = ['Masculino', 'Femenino'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      setState(() {
        _nombreCtrl.text = data['name'] ?? '';
        _apodoCtrl.text = data['nickname'] ?? '';
        _alturaCtrl.text = data['heightCm']?.toString() ?? '';
        _ciudadCtrl.text = data['city'] ?? '';
        _preferredFoot = data['preferredFoot'] ?? 'Derecho';
        _sex = data['sex'] ?? 'Masculino';
        _currentPhotoUrl = data['photoUrl'];

        final pos = data['position'];
        if (pos != null && pos is String) {
          _selectedPositions = pos.split(',').map((e) => e.trim()).toList();
        }
        if (data.containsKey('cityData')) {
          _selectedCityData = Map<String, dynamic>.from(data['cityData']);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando perfil: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final ext = picked.path.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        setState(() => _imageFile = File(picked.path));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo se permiten imágenes JPG o PNG.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error seleccionando imagen: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final uid = _auth.currentUser!.uid;
      String? photoUrl = _currentPhotoUrl;

      if (_imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subiendo imagen...'),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );

        try {
          final userFolder = _storage.ref('users/$uid');
          final oldFiles = await userFolder.listAll();
          for (final f in oldFiles.items) {
            await f.delete();
          }
        } catch (_) {
          debugPrint('⚠️ No se encontraron archivos antiguos, continuando...');
        }

        final ext = _imageFile!.path.split('.').last.toLowerCase();
        final type = ext == 'png' ? 'image/png' : 'image/jpeg';
        final ref = _storage.ref('users/$uid/avatar.$ext');

        final uploadTask = await ref.putFile(
          _imageFile!,
          SettableMetadata(contentType: type),
        );

        photoUrl = await uploadTask.ref.getDownloadURL();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Imagen actualizada con éxito'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _firestore.collection('users').doc(uid).set({
        'name': _nombreCtrl.text.trim(),
        'nickname': _apodoCtrl.text.trim(),
        'heightCm': double.tryParse(_alturaCtrl.text.trim()),
        'city': _ciudadCtrl.text.trim(),
        'cityData': _selectedCityData,
        'preferredFoot': _preferredFoot,
        'position': _selectedPositions.join(', '),
        'sex': _sex,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfileCardAnimation(
          name: _nombreCtrl.text.trim(),
          nickname: _apodoCtrl.text.trim().isNotEmpty
              ? '@${_apodoCtrl.text.trim()}'
              : '@jugador',
          rank: 'Bronce',
          xp: 0,
          victories: 0,
          matches: 0,
          photoUrl: photoUrl,
        ),
      );

      // 🚀 Redirigir al Dashboard después de completar el perfil
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }

      Navigator.pop(context);
    } catch (e) {
      debugPrint('⚠️ Error al guardar perfil: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCityPicker() async {
    final placeService = PlaceService();
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> suggestions = [];

    await showModalBottomSheet(
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> search(String query) async {
              if (query.isEmpty) {
                setSheet(() => suggestions = []);
                return;
              }
              setSheet(() => _searchingCity = true);
              final results = await placeService.searchPlaces(query);
              setSheet(() {
                suggestions = results;
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
                            fontWeight: FontWeight.w500),
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
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14),
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
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedCityData = result;
          _ciudadCtrl.text = result['name'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatarWidget = _imageFile != null
        ? CircleAvatar(radius: 44, backgroundImage: FileImage(_imageFile!))
        : _currentPhotoUrl != null
            ? CircleAvatar(
                radius: 44,
                backgroundImage: NetworkImage(_currentPhotoUrl!),
                onBackgroundImageError: (_, __) =>
                    debugPrint('⚠️ Error cargando imagen.'),
              )
            : const CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white10,
                child: Icon(Icons.person, color: Colors.white54, size: 36),
              );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(60),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    avatarWidget,
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nombreCtrl, 'Nombre', true),
              _buildTextField(_apodoCtrl, 'Apodo (opcional)', false),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sex,
                dropdownColor: const Color(0xFF1A1A1A),
                decoration: const InputDecoration(
                  labelText: 'Sexo',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF111111),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent)),
                ),
                items: _sexos
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s,
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _sex = v ?? 'Masculino'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openCityPicker,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _ciudadCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon:
                          Icon(Icons.location_on, color: Colors.blueAccent),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueAccent)),
                      filled: true,
                      fillColor: Color(0xFF111111),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildHeightField(),
              const SizedBox(height: 12),
              _buildPositionSelector(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _preferredFoot,
                dropdownColor: const Color(0xFF1A1A1A),
                items: _pies
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p,
                            style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _preferredFoot = v ?? 'Derecho'),
                decoration: const InputDecoration(
                  labelText: 'Pie dominante',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent)),
                  filled: true,
                  fillColor: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, bool obligatorio) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      validator: obligatorio
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent)),
        filled: true,
        fillColor: const Color(0xFF111111),
      ),
    );
  }

  Widget _buildHeightField() {
    return TextFormField(
      controller: _alturaCtrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      validator: (v) {
        final value = double.tryParse(v ?? '');
        if (value == null || value < 1.4 || value > 2.2) {
          return 'Ingresa una altura válida (1.40–2.20 m)';
        }
        return null;
      },
      decoration: const InputDecoration(
        labelText: 'Altura (en metros, ej: 1.75)',
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent)),
        filled: true,
        fillColor: Color(0xFF111111),
      ),
    );
  }

  Widget _buildPositionSelector() {
    return GestureDetector(
      onTap: _showPositionSelector,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _selectedPositions.isEmpty
              ? 'Seleccionar posiciones (máx. 3)'
              : _selectedPositions.join(', '),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showPositionSelector() {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF1A1A1A),
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheet) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Selecciona tus posiciones (máx. 3)',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Expanded(
                child: ListView(
                  children: _posiciones.map((pos) {
                    final selected = _selectedPositions.contains(pos);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(pos,
                          style: const TextStyle(color: Colors.white)),
                      activeColor: Colors.blueAccent,
                      onChanged: (v) {
                        setSheet(() {
                          if (v == true && _selectedPositions.length < 3) {
                            _selectedPositions.add(pos);
                          } else if (v == false) {
                            _selectedPositions.remove(pos);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar',
                    style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      },
    );
  }
}
