// lib/features/profile/domain/xp_bootstrap.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class XPBootstrap {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Asegura que /users/{uid}.xp exista (si falta, lo inicializa en 0)
  static Future<void> ensureUserXP() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        // Si por alguna razón aún no existe el doc, créalo mínimo con xp:0
        tx.set(ref, {'xp': 0}, SetOptions(merge: true));
        return;
      }
      final data = snap.data()!;
      if (!data.containsKey('xp') || data['xp'] == null) {
        tx.update(ref, {'xp': 0});
      }
    });
  }
}
