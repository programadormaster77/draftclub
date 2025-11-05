import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 💬 SocialCommentsService — Gestión de comentarios (versión PRO)
/// ===============================================================
/// ✅ Evita el error: "Transactions require all reads before all writes".
/// ✅ Separa la lectura previa del post antes de transaccionar.
/// ✅ Contador de comentarios con FieldValue.increment (atómico).
/// ✅ Guarda metadatos útiles del autor (name, photoUrl) para render rápido.
/// ✅ Editar y eliminar con reglas seguras + decremento del contador.
/// ✅ Streams en tiempo real para lista y contador.
/// ===============================================================
class SocialCommentsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SocialCommentsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// 🔹 Crear comentario (seguro y con metadatos)
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final commentsRef = postRef.collection('comments');
    final commentDoc = commentsRef.doc();

    // ✅ Lee el post fuera de la transacción (cumple la regla de Firestore)
    final postSnap = await postRef.get();
    if (!postSnap.exists) {
      throw Exception('El post no existe o fue eliminado.');
    }

    // 🔎 Toma datos básicos del usuario para evitar lookups costosos en UI
    //    (si falta name/photoUrl, no bloquea)
    String? authorName;
    String? authorPhotoUrl;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final u = userDoc.data();
      if (u != null) {
        authorName = (u['name'] ?? u['nickname'])?.toString();
        authorPhotoUrl = u['photoUrl']?.toString();
      }
    } catch (_) {
      // Ignoramos errores de enriquecimiento (no críticos)
    }

    // ✅ Transacción de solo escrituras
    await _firestore.runTransaction((tx) async {
      tx.set(commentDoc, {
        'id': commentDoc.id,
        'authorId': user.uid,
        'authorName': authorName, // opcional (para UI más fluida)
        'authorPhotoUrl': authorPhotoUrl, // opcional (para UI más fluida)
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });

      tx.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });
    });
  }

  /// ✏️ Editar comentario (solo autor)
  Future<void> editComment({
    required String postId,
    required String commentId,
    required String newText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    // Revisa propiedad del comentario (fuera de tx)
    final snap = await commentRef.get();
    if (!snap.exists) {
      throw Exception('El comentario no existe.');
    }
    final data = snap.data() as Map<String, dynamic>;
    if (data['authorId'] != user.uid) {
      throw Exception('No tienes permisos para editar este comentario.');
    }

    await commentRef.update({
      'text': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🗑️ Eliminar comentario (solo autor) + decrementa contador
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    // Lee el comentario fuera de la tx (cumple la regla de Firestore)
    final commentSnap = await commentRef.get();
    if (!commentSnap.exists) {
      throw Exception('El comentario no existe.');
    }
    final data = commentSnap.data() as Map<String, dynamic>;
    if (data['authorId'] != user.uid) {
      throw Exception('No tienes permisos para eliminar este comentario.');
    }

    // 🧾 Transacción: borra y decrementa de forma atómica
    await _firestore.runTransaction((tx) async {
      tx.delete(commentRef);
      tx.update(postRef, {
        'commentCount': FieldValue.increment(-1),
      });
    });
  }

  /// 🔄 Stream de comentarios (ordenados por fecha desc)
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList());
  }

  /// 🔢 Stream del contador de comentarios (útil para badges)
  Stream<int> getCommentCountStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => (doc.data()?['commentCount'] ?? 0) as int);
  }
}
