import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 💬 SocialCommentsService — Gestión de comentarios
/// ===============================================================
/// - Administra comentarios en cada publicación.
/// - Actualiza el contador en el documento principal del post.
/// - Emite streams para mostrar comentarios en tiempo real.
/// ===============================================================
class SocialCommentsService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Crear comentario
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final commentsRef = postRef.collection('comments');

    final commentDoc = commentsRef.doc();

    await _firestore.runTransaction((tx) async {
      tx.set(commentDoc, {
        'id': commentDoc.id,
        'authorId': user.uid,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final postSnap = await tx.get(postRef);
      final currentCount = (postSnap.data()?['commentCount'] ?? 0) as int;
      tx.update(postRef, {'commentCount': currentCount + 1});
    });
  }

  /// 🔹 Obtener stream de comentarios en tiempo real
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }
}