import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// ❤️ SocialLikesService — Control de "me gusta" en publicaciones
/// ===============================================================
/// - Administra likes por usuario y publicación.
/// - Actualiza el contador total del post en tiempo real.
/// - Evita duplicados mediante colecciones anidadas.
/// ===============================================================
class SocialLikesService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Da "me gusta" o lo quita según el estado actual.
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    final postRef = _firestore.collection('posts').doc(postId);

    final doc = await likeRef.get();
    final isLiked = doc.exists;

    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      final currentLikes = (postSnap.data()?['likeCount'] ?? 0) as int;

      if (isLiked) {
        // Quitar "like"
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': currentLikes - 1});
      } else {
        // Dar "like"
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': currentLikes + 1});
      }
    });
  }

  /// 🔹 Verifica si el usuario ya dio "like" a un post.
  Future<bool> isPostLiked(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .get();

    return likeDoc.exists;
  }

  /// 🔹 Stream del contador de likes del post
  Stream<int> getLikeCountStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => (doc.data()?['likeCount'] ?? 0) as int);
  }
}