import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 🚨 SocialReportsService — Servicio para manejar reportes
/// ===============================================================
/// - Guarda reportes en la colección `reports`
/// - Incluye motivo, usuario y postId
/// ===============================================================
class SocialReportsService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Crea un reporte nuevo en Firestore
  Future<void> createReport({
    required String postId,
    required String authorId,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final reportData = {
      'postId': postId,
      'authorId': authorId,
      'reporterId': user.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('reports').add(reportData);
  }

  /// Verifica si el usuario ya reportó un post (para evitar spam)
  Future<bool> hasReported(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final query = await _firestore
        .collection('reports')
        .where('postId', isEqualTo: postId)
        .where('reporterId', isEqualTo: user.uid)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }
}