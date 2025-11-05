import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 👥 SocialFollowService — Sistema de seguidores y seguidos
/// ===============================================================
/// ✅ Evita duplicados y actualiza contadores atómicamente.
/// ✅ Permite verificar si un usuario ya sigue a otro.
/// ✅ Streams para listar seguidores o seguidos.
/// ===============================================================
class SocialFollowService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔹 Alterna el estado de "seguir"
  Future<void> toggleFollow(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == targetUserId) return;

    final myRef = _firestore.collection('users').doc(currentUser.uid);
    final targetRef = _firestore.collection('users').doc(targetUserId);

    final myFollowingRef = myRef.collection('following').doc(targetUserId);
    final targetFollowersRef =
        targetRef.collection('followers').doc(currentUser.uid);

    await _firestore.runTransaction((tx) async {
      final followSnap = await tx.get(myFollowingRef);
      final targetSnap = await tx.get(targetRef);
      final mySnap = await tx.get(myRef);

      final isFollowing = followSnap.exists;

      if (isFollowing) {
        // ✅ Dejar de seguir
        tx.delete(myFollowingRef);
        tx.delete(targetFollowersRef);

        final targetFollowers =
            (targetSnap.data()?['followersCount'] ?? 0) as int;
        final myFollowing = (mySnap.data()?['followingCount'] ?? 0) as int;

        tx.update(targetRef,
            {'followersCount': targetFollowers > 0 ? targetFollowers - 1 : 0});
        tx.update(
            myRef, {'followingCount': myFollowing > 0 ? myFollowing - 1 : 0});
      } else {
        // ✅ Seguir
        tx.set(myFollowingRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.set(targetFollowersRef, {'createdAt': FieldValue.serverTimestamp()});

        tx.update(targetRef, {'followersCount': FieldValue.increment(1)});
        tx.update(myRef, {'followingCount': FieldValue.increment(1)});
      }
    });
  }

  /// 🔹 Verifica si el usuario actual sigue al objetivo
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .get();

    return doc.exists;
  }

  /// 🔹 Stream de seguidores
  Stream<List<String>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// 🔹 Stream de seguidos
  Stream<List<String>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
