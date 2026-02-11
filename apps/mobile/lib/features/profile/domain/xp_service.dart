// lib/features/users/domain/xp_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class XPService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// XP total actual del usuario
  static Future<int> getUserXP() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    final doc = await _db.collection('users').doc(user.uid).get();
    return (doc.data()?['xp'] ?? 0) as int;
  }

  /// Historial completo de XP
  static Stream<List<Map<String, dynamic>>> getXPHistory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('xp_history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
