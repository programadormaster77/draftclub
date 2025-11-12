import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================================
/// ❤️ SocialFollowService — Gestión de Seguidores y Seguidos (v3.0 PRO)
/// ============================================================================
/// ✅ Centraliza toda la lógica de follow/unfollow.
/// ✅ Actualiza contadores globales (followersCount / followingCount).
/// ✅ Streams en tiempo real para UI reactiva.
/// ✅ Previene duplicados y asegura consistencia con transacciones.
/// ✅ Eficiente para Firestore a gran escala.
/// ============================================================================

class SocialFollowService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Seguir o dejar de seguir a otro usuario
  Future<void> toggleFollow(String targetUserId) async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == targetUserId) return;

    final myFollowingRef = _firestore
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(targetUserId);

    final hisFollowersRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(me);

    final userRef = _firestore.collection('users').doc(me);
    final targetRef = _firestore.collection('users').doc(targetUserId);

    await _firestore.runTransaction((tx) async {
      final current = await tx.get(myFollowingRef);

      if (current.exists) {
        // 🚫 Dejar de seguir
        tx.delete(myFollowingRef);
        tx.delete(hisFollowersRef);

        // 🔄 Actualizar contadores globales
        tx.update(userRef, {
          'followingCount': FieldValue.increment(-1),
        });
        tx.update(targetRef, {
          'followersCount': FieldValue.increment(-1),
        });
      } else {
        // ✅ Seguir
        final data = {'since': FieldValue.serverTimestamp()};
        tx.set(myFollowingRef, data);
        tx.set(hisFollowersRef, data);

        // 🔄 Actualizar contadores globales
        tx.update(userRef, {
          'followingCount': FieldValue.increment(1),
        });
        tx.update(targetRef, {
          'followersCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// 🔹 Comprobar si ya sigo al usuario
  Future<bool> isFollowing(String targetUserId) async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == targetUserId) return false;

    final doc = await _firestore
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }

  /// 🔹 Stream de IDs de seguidores en tiempo real
  Stream<List<String>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// 🔹 Stream de IDs de seguidos (usuarios que sigo)
  Stream<List<String>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// 🔹 Contar seguidores (una sola lectura)
  Future<int> countFollowers(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .get();
    return snap.size;
  }

  /// 🔹 Contar seguidos (una sola lectura)
  Future<int> countFollowing(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .get();
    return snap.size;
  }
}