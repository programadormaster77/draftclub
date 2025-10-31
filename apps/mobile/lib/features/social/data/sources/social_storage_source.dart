import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

/// ===============================================================
/// ☁️ SocialStorageSource — Maneja la subida de medios (foto/video)
/// ===============================================================
/// 
/// - Sube imágenes comprimidas a Storage.
/// - Genera thumbnails de video.
/// - Devuelve las URLs listas para usar en Firestore.
/// ===============================================================
class SocialStorageSource {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 🔹 Sube una imagen optimizada al Storage
  Future<String> uploadPhoto({
    required File file,
    required String uid,
    required String postId,
  }) async {
    try {
      // Comprimir imagen
      final compressed = await _compressImage(file);

      // Ruta destino
      final path = 'uploads/$uid/photos/$postId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(path);

      // Subir a Storage
      final uploadTask = await ref.putFile(compressed);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('❌ Error al subir imagen: $e');
      rethrow;
    }
  }

  /// 🔹 Sube un video y genera thumbnail automáticamente
  Future<Map<String, String>> uploadVideo({
    required File file,
    required String uid,
    required String postId,
  }) async {
    try {
      // Ruta del video
      final videoPath = 'uploads/$uid/videos/$postId/video.mp4';
      final refVideo = _storage.ref().child(videoPath);

      // Subir video
      final uploadTask = await refVideo.putFile(file);
      final videoUrl = await uploadTask.ref.getDownloadURL();

      // Crear thumbnail
      final thumbFile = await _generateVideoThumbnail(file);
      final thumbPath = 'uploads/$uid/videos/$postId/thumb.jpg';
      final refThumb = _storage.ref().child(thumbPath);
      final uploadThumb = await refThumb.putFile(thumbFile);
      final thumbUrl = await uploadThumb.ref.getDownloadURL();

      return {'videoUrl': videoUrl, 'thumbUrl': thumbUrl};
    } catch (e) {
      debugPrint('❌ Error al subir video: $e');
      rethrow;
    }
  }

  // ===============================================================
  // 🧩 MÉTODOS PRIVADOS
  // ===============================================================

  /// 🖼️ Comprime una imagen a ~2048px máximo y JPEG 80%
  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return file;

    final resized = img.copyResize(
      image,
      width: image.width > 2048 ? 2048 : image.width,
      height: image.height > 2048 ? 2048 : image.height,
    );

    final compressedBytes = img.encodeJpg(resized, quality: 80);

    final tempDir = await getTemporaryDirectory();
    final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  /// 🎞️ Genera un thumbnail (imagen) desde un video
  Future<File> _generateVideoThumbnail(File videoFile) async {
    final tempDir = await getTemporaryDirectory();
    final thumbPath = await VideoThumbnail.thumbnailFile(
      video: videoFile.path,
      thumbnailPath: tempDir.path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 400,
      quality: 75,
    );

    return File(thumbPath!);
  }
}