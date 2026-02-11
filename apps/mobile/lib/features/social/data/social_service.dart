import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/domain/repositories/social_repository.dart';
import 'package:draftclub_mobile/features/social/domain/repositories/social_repository_impl.dart';
import 'sources/social_storage_source.dart';

/// ===============================================================
/// ⚙️ SocialService — Servicio de alto nivel del módulo social
/// ===============================================================
/// Combina Firestore + Storage para manejar la creación y carga
/// de publicaciones (foto o video) dentro del feed social.
/// ===============================================================
class SocialService {
  final SocialRepository _repo = SocialRepositoryImpl();
  final SocialStorageSource _storage = SocialStorageSource();

  /// 🔹 Crea una publicación (foto o video)
  Future<void> createPost({
    required String uid,
    required String city,
    required String caption,
    required File file,
    required String type, // "photo" o "video"
  }) async {
    try {
      final postId = FirebaseFirestore.instance.collection('posts').doc().id;

      String thumbUrl = '';
      List<String> mediaUrls = [];

      // ==========================================================
      // 📤 Subida del medio
      // ==========================================================
      if (type == 'photo') {
        final photoUrl = await _storage.uploadPhoto(
          file: file,
          uid: uid,
          postId: postId,
        );
        mediaUrls = [photoUrl];
      } else if (type == 'video') {
        final videoData = await _storage.uploadVideo(
          file: file,
          uid: uid,
          postId: postId,
        );
        mediaUrls = [videoData['videoUrl']!];
        thumbUrl = videoData['thumbUrl']!;
      }

      // ==========================================================
      // 🧩 Crear objeto Post
      // ==========================================================
      final post = Post(
        id: postId,
        authorId: uid,
        type: type,
        mediaUrls: mediaUrls,
        thumbUrl: thumbUrl.isNotEmpty ? thumbUrl : null,
        caption: caption.trim(),
        tags: _extractTags(caption),
        mentions: _extractMentions(caption),
        createdAt: Timestamp.now(),
        city: city,
        deleted: false,
      );

      // ==========================================================
      // 🗄️ Guardar en Firestore
      // ==========================================================
      await _repo.createPost(post);

      print('✅ Post creado correctamente: $postId');
    } catch (e) {
      print('❌ Error al crear publicación: $e');
      rethrow;
    }
  }

  /// 🔹 Obtiene el stream del feed global o filtrado por ciudad
  Stream<List<Post>> getFeedStream({String? city}) {
    return _repo.getFeedStream(city: city);
  }

  // ===============================================================
  // 🧠 MÉTODOS AUXILIARES
  // ===============================================================

  /// 🏷️ Extrae hashtags del caption
  List<String> _extractTags(String caption) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(caption).map((m) => m.group(1)!).toList();
  }

  /// 👥 Extrae menciones del caption (por @usuario)
  List<String> _extractMentions(String caption) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(caption).map((m) => m.group(1)!).toList();
  }
}
