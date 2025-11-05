import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 🧠 RoomXPTracker — Sistema externo de puntos de experiencia (XP)
/// ===============================================================
/// - No modifica ninguna lógica de RoomsPage.
/// - Puede llamarse desde cualquier parte (ej: al crear, unirse, completar).
/// - Registra el progreso del usuario en `users/<uid>/xp_history`.
/// ===============================================================
class RoomXPTracker {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 🔹 Añade puntos al usuario actual
  static Future<void> addXP({
    required int amount,
    required String reason,
    String? roomId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userRef = _db.collection('users').doc(uid);
    final xpRef = userRef.collection('xp_history').doc();

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      int currentXP = (userSnap.data()?['xp'] ?? 0) as int;
      final newXP = currentXP + amount;

      tx.update(userRef, {'xp': newXP});
      tx.set(xpRef, {
        'amount': amount,
        'reason': reason,
        'roomId': roomId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 🔸 Ejemplo de ganancia por evento
  static Future<void> onRoomCreated(String roomId) async {
    await addXP(amount: 25, reason: 'Creó una sala', roomId: roomId);
  }

  static Future<void> onRoomJoined(String roomId) async {
    await addXP(amount: 10, reason: 'Se unió a una sala', roomId: roomId);
  }

  static Future<void> onRoomCompleted(String roomId) async {
    await addXP(amount: 50, reason: 'Completó una sala', roomId: roomId);
  }
}
