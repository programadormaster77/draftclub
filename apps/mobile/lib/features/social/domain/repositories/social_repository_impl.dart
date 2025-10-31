import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';

/// ===============================================================
/// 🧠 SocialRepositoryImpl — Implementación principal del repositorio social
/// ===============================================================
/// Maneja toda la comunicación con Firestore (lectura y escritura de posts),
/// y mantiene compatibilidad con el modelo Post.
/// ===============================================================
class SocialRepositoryImpl implements SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔹 Obtiene un stream en tiempo real del feed
  /// Si se pasa [city], filtra las publicaciones por ciudad.
  @override
  Stream<List<Post>> getFeedStream({String? city}) {
    Query query = _firestore
        .collection('posts')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList(),
        );
  }

  /// 🔹 Crea o actualiza un post en Firestore
  @override
  Future<void> createPost(Post post) async {
    final doc = _firestore.collection('posts').doc(post.id);
    await doc.set(post.toMap(), SetOptions(merge: true));
  }

  /// 🔹 Elimina un post de forma "soft delete"
  /// (solo marca `deleted = true`, no lo borra físicamente)
  Future<void> softDeletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'deleted': true,
      'updatedAt': Timestamp.now(),
    });
  }

  /// 🔹 Incrementa o decrementa el contador de likes
  Future<void> updateLikeCount(String postId, int delta) async {
    await _firestore.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(delta),
    });
  }

  /// 🔹 Incrementa el contador de comentarios
  Future<void> incrementCommentCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }
}

