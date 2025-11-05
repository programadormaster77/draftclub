import 'dart:io';
import 'package:draftclub_mobile/features/social/data/social_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/post_success_overlay.dart';

/// ===============================================================
/// 📝 CreatePostSheet — Modal real para crear una publicación
/// ===============================================================
/// - Permite tomar o elegir foto/video.
/// - Sube medios a Firebase Storage.
/// - Crea documento en Firestore mediante [SocialService].
/// - Muestra animación de éxito tras publicar.
/// ===============================================================
class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _service = SocialService();

  File? _selectedFile;
  String? _mediaType; // 'photo' | 'video'
  bool _isUploading = false;

  // ===================== MÉTODOS DE SELECCIÓN =====================

  Future<void> _pickImageFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'photo';
      });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'photo';
      });
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'video';
      });
    }
  }

  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'video';
      });
    }
  }

  // ===================== PUBLICAR =====================
  Future<void> _publish() async {
    final caption = _captionCtrl.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Debes iniciar sesión para publicar.'),
        ),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Selecciona o graba una imagen o video.'),
        ),
      );
      return;
    }

    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Escribe una descripción.'),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _service.createPost(
        uid: uid,
        file: _selectedFile!,
        type: _mediaType ?? 'photo',
        caption: caption,
        city: 'Bogotá', // 🔹 Temporal hasta integrar ubicación real
      );

      if (!mounted) return;
      Navigator.pop(context);

      // ✅ Overlay visual de éxito
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (_) => const PostSuccessOverlay(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al publicar: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===================== INTERFAZ =====================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ====== Indicador superior ======
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Text(
              'Nueva publicación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // ===================== PREVISUALIZACIÓN =====================
            if (_selectedFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _mediaType == 'photo'
                    ? Image.file(_selectedFile!, fit: BoxFit.cover)
                    : Container(
                        height: 200,
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white70,
                          size: 60,
                        ),
                      ),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Selecciona o graba una imagen o video',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 16),

            // ===================== BOTONES DE SELECCIÓN =====================
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                    Icons.photo, 'Foto galería', _pickImageFromGallery),
                _buildActionButton(
                    Icons.videocam, 'Video galería', _pickVideoFromGallery),
                _buildActionButton(Icons.camera_alt, 'Tomar foto', _takePhoto),
                _buildActionButton(Icons.camera, 'Grabar video', _recordVideo),
              ],
            ),
            const SizedBox(height: 20),

            // ===================== DESCRIPCIÓN =====================
            TextField(
              controller: _captionCtrl,
              maxLength: 2200,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe una descripción...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),

            // ===================== BOTÓN PUBLICAR =====================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _publish,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(_isUploading ? 'Publicando...' : 'Publicar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== BOTÓN AUXILIAR =====================
  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: _isUploading ? null : onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
