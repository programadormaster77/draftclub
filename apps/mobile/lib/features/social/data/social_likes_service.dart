import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// ❤️ SocialLikesService — Control de "me gusta" en publicaciones (versión PRO)
/// ===============================================================
/// ✅ Evita duplicados (misma persona no puede dar +1 dos veces seguidas)
/// ✅ Evita valores negativos en el contador
/// ✅ Usa subcolección `likes` (posts/{postId}/likes/{userId})
/// ✅ Stream de conteo de likes en tiempo real
/// ===============================================================
class SocialLikesService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Alterna el estado del "me gusta"
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);

    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      final likeSnap = await tx.get(likeRef);

      // Verificar conteo actual
      final currentLikes = (postSnap.data()?['likeCount'] ?? 0) as int;

      if (likeSnap.exists) {
        // ✅ Quitar like
        tx.delete(likeRef);
        tx.update(postRef, {
          'likeCount': currentLikes > 0
              ? FieldValue.increment(-1)
              : 0, // evita negativos
        });
      } else {
        // ✅ Agregar like
        tx.set(likeRef, {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// 🔹 Verifica si el usuario ya dio "me gusta" a un post
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
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null) return 0;
      return (data['likeCount'] ?? 0) as int;
    });
  }
}
