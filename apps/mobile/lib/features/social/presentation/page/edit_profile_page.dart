// 📦 DEPENDENCIAS PRINCIPALES
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// ============================================================================
/// 🧑‍💼 EditProfilePage — Edición de perfil (Versión PRO++ 2025)
/// ============================================================================
/// ✅ Carga datos actuales desde Firestore.
/// ✅ Sube imagen JPG/PNG a Storage de forma segura.
/// ✅ Compatible con tus reglas (`users/<uid>/avatar.jpg`)
/// ✅ Soporte para reemplazar imagen anterior.
/// ✅ Validaciones, feedback visual y diseño limpio.
/// ============================================================================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // ===================== INSTANCIAS BÁSICAS =====================
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _photoUrl;
  File? _newImage;

  // ===================== INIT =====================
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ===================== CARGAR PERFIL =====================
  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameCtrl.text = data['name'] ?? '';
        _nicknameCtrl.text = data['nickname'] ?? '';
        _cityCtrl.text = data['city'] ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        _photoUrl = data['photoUrl'];
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al cargar el perfil: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===================== SELECCIONAR IMAGEN =====================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked != null) {
        final ext = picked.path.split('.').last.toLowerCase();
        if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
          setState(() => _newImage = File(picked.path));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text('Formato no compatible. Usa JPG o PNG.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error seleccionando imagen: $e');
    }
  }

  // ===================== GUARDAR PERFIL =====================
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    String? photoUrl = _photoUrl;

    try {
      // 🧹 Eliminar fotos antiguas antes de subir nueva
      if (_newImage != null) {
        final userFolder = _storage.ref('users/$uid');
        final existingFiles = await userFolder.listAll();
        for (final item in existingFiles.items) {
          await item.delete();
        }

        // ✅ Subir nueva imagen al path permitido
        final ref = _storage.ref().child('users/$uid/avatar.jpg');
        final uploadTask = await ref.putFile(
          _newImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        photoUrl = await uploadTask.ref.getDownloadURL();
      }

      // 🧾 Actualizar documento Firestore
      await _firestore.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('✅ Perfil actualizado correctamente'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('⚠️ Error al guardar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al guardar cambios: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===================== INTERFAZ =====================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Guardar',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 📸 FOTO DE PERFIL
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white12,
                      backgroundImage: _newImage != null
                          ? FileImage(_newImage!)
                          : (_photoUrl != null && _photoUrl!.isNotEmpty)
                              ? NetworkImage(_photoUrl!)
                              : null,
                      onBackgroundImageError: (_, __) =>
                          debugPrint('⚠️ Error cargando imagen de perfil.'),
                      child: (_photoUrl == null || _photoUrl!.isEmpty) &&
                              _newImage == null
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 52)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _showImagePicker(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🧾 CAMPOS DE TEXTO
              _buildField(_nameCtrl, 'Nombre completo',
                  validator: true, icon: Icons.person_outline),
              _buildField(_nicknameCtrl, 'Nombre de usuario',
                  hint: '@jugador', icon: Icons.alternate_email),
              _buildField(_cityCtrl, 'Ciudad',
                  icon: Icons.location_on_outlined),
              _buildField(_bioCtrl, 'Biografía',
                  maxLines: 3, icon: Icons.edit_outlined),

              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Guardar cambios',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== CAMPO REUTILIZABLE =====================
  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool validator = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.white70, size: 20) : null,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: validator
            ? (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null
            : null,
      ),
    );
  }

  // ===================== SELECCIÓN DE IMAGEN =====================
  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (_) => _ImagePickerSheet(
        onPickCamera: () {
          Navigator.pop(context);
          _pickImage(ImageSource.camera);
        },
        onPickGallery: () {
          Navigator.pop(context);
          _pickImage(ImageSource.gallery);
        },
      ),
    );
  }
}

/// ============================================================================
/// 🔹 Selector de fuente de imagen (Galería o Cámara)
/// ============================================================================
class _ImagePickerSheet extends StatelessWidget {
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  const _ImagePickerSheet({
    required this.onPickCamera,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.photo_camera, color: Colors.white70),
          title:
              const Text('Tomar foto', style: TextStyle(color: Colors.white)),
          onTap: onPickCamera,
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white70),
          title: const Text('Elegir de galería',
              style: TextStyle(color: Colors.white)),
          onTap: onPickGallery,
        ),
      ],
    );
  }
}
