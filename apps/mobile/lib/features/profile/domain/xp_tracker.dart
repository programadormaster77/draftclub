// lib/features/profile/domain/xp_tracker.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ===============================================================
/// 🧩 RoomXPTracker — Sistema centralizado de puntos XP
/// ===============================================================
/// Llama este servicio cada vez que el usuario realiza una acción
/// relevante (crear sala, unirse, ganar partido, etc.)
/// ===============================================================
class RoomXPTracker {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 🏗️ Gana XP al crear una sala
  static Future<void> onRoomCreated(String roomId) async {
    await _addXP(amount: 25, reason: 'Creó una sala', roomId: roomId);
  }

  /// ⚽ Gana XP al unirse a una sala
  static Future<void> onJoinRoom(String roomId) async {
    await _addXP(amount: 10, reason: 'Se unió a una sala', roomId: roomId);
  }

  /// 🏆 Gana XP al completar un partido o evento
  static Future<void> onMatchCompleted(String roomId) async {
    await _addXP(amount: 50, reason: 'Completó un partido', roomId: roomId);
  }

  /// ===============================================================
  /// 🧠 Método interno que actualiza XP total y guarda historial
  /// ===============================================================
  static Future<void> _addXP({
    required int amount,
    required String reason,
    String? roomId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final xpRef = userRef.collection('xp_history').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);

      // ✅ Aseguramos que el documento exista
      if (!snap.exists) {
        tx.set(userRef, {'xp': amount}, SetOptions(merge: true));
      } else {
        final currentXP = (snap.data()?['xp'] ?? 0) as int;
        final newXP = currentXP + amount;
        tx.update(userRef, {'xp': newXP});
      }

      // 🕒 Guardar registro en historial
      tx.set(xpRef, {
        'amount': amount,
        'reason': reason,
        'roomId': roomId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }).catchError((e) {
      print('⚠️ Error al actualizar XP: $e');
    });
  }
}
