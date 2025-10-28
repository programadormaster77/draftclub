// 📦 IMPORTACIONES PRINCIPALES
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 🧩 Módulos internos
import '../../auth/data/auth_service.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'profile_card_animation.dart';

/// ===============================================================
/// 🧾 ProfileSetupPage — Configuración inicial del perfil
/// ===============================================================
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  // ===================== CONTROLADORES Y VARIABLES =====================
  final _formKey = GlobalKey<FormState>();
  final _repo = ProfileRepository();
  final _auth = AuthService();

  final _nameCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Bogotá');

  String _preferredFoot = 'Derecho';
  String? _sex; // 🔹 Nuevo campo obligatorio (Masculino / Femenino)

  File? _avatarFile;
  bool _saving = false;

  // ===================== SELECCIONAR FOTO =====================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  // ===================== GUARDAR PERFIL =====================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      // 🔹 Subir foto
      String? photoUrl;
      if (_avatarFile != null) {
        photoUrl = await _repo.uploadAvatar(uid: user.uid, file: _avatarFile!);
      }

      // 🔹 Crear objeto perfil
      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        name: _nameCtrl.text.trim(),
        nickname: _nickCtrl.text.trim().isEmpty ? null : _nickCtrl.text.trim(),
        photoUrl: photoUrl,
        heightCm: _heightCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_heightCtrl.text.trim()),
        position: _positionCtrl.text.trim().isEmpty
            ? null
            : _positionCtrl.text.trim(),
        preferredFoot: _preferredFoot,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        sex: _sex ?? 'Masculino', // ✅ Nuevo campo
        rank: 'Bronce',
        xp: 0,
        vipFlag: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 🔹 Guardar documento
      await _repo.createOrUpdateProfile(profile);

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfileCardAnimation(
          name: _nameCtrl.text.trim(),
          nickname: _nickCtrl.text.trim().isNotEmpty
              ? '@${_nickCtrl.text.trim()}'
              : '@jugador',
          rank: 'Bronce',
          xp: 0,
          victories: 0,
          matches: 0,
          photoUrl: photoUrl,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(); // <- vuelve al ProfileGate
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[700],
          content: Text('Error al guardar perfil: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===================== INTERFAZ =====================
  @override
  Widget build(BuildContext context) {
    final avatar = _avatarFile == null
        ? const CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person, color: Colors.white54, size: 36),
          )
        : CircleAvatar(radius: 44, backgroundImage: FileImage(_avatarFile!));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tu tarjeta de jugador'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ===================== FOTO DE PERFIL =====================
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(60),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      avatar,
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ===================== FORMULARIO =====================
                _TextField(
                  controller: _nameCtrl,
                  label: 'Nombre',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu nombre'
                      : null,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 12),
                _TextField(controller: _nickCtrl, label: 'Apodo (opcional)'),
                const SizedBox(height: 12),
                _TextField(
                  controller: _heightCtrl,
                  label: 'Estatura (cm)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _TextField(
                  controller: _positionCtrl,
                  label: 'Posición (Ej: Delantero)',
                ),
                const SizedBox(height: 12),

                // ===================== SEXO (nuevo campo obligatorio) =====================
                DropdownButtonFormField<String>(
                  value: _sex,
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF111111),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Masculino',
                      child: Text('Masculino',
                          style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'Femenino',
                      child: Text('Femenino',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _sex = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Selecciona tu sexo' : null,
                ),
                const SizedBox(height: 12),

                // ===================== PIE DOMINANTE =====================
                Row(
                  children: [
                    const Text('Pie dominante:',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      dropdownColor: const Color(0xFF1A1A1A),
                      value: _preferredFoot,
                      items: const [
                        DropdownMenuItem(
                          value: 'Derecho',
                          child: Text('Derecho',
                              style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'Izquierdo',
                          child: Text('Izquierdo',
                              style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'Ambos',
                          child: Text('Ambos',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _preferredFoot = v ?? 'Derecho'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _TextField(controller: _cityCtrl, label: 'Ciudad'),
                const SizedBox(height: 20),

                // ===================== BOTÓN GUARDAR =====================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(_saving ? 'Guardando…' : 'Crear mi perfil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// 🧱 _TextField — Campo reutilizable oscuro
/// ===============================================================
class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;

  const _TextField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        filled: true,
        fillColor: const Color(0xFF111111),
      ),
    );
  }
}
