import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

/// ======================================================================
/// 🧠 ProfileXPWidget — Módulo visual del sistema de experiencia (XP)
/// ======================================================================
/// 🔹 Muestra el nivel del jugador, su progreso y rango visual.
/// 🔹 Calcula automáticamente el nivel según el XP acumulado.
/// 🔹 Se actualiza en tiempo real al cambiar el XP en Firestore.
/// 🔹 Incluye lista de historial reciente (últimos 5 eventos XP).
/// ======================================================================
class ProfileXPWidget extends StatelessWidget {
  const ProfileXPWidget({super.key});

  /// Calcula el nivel del jugador según el XP total.
  int _calculateLevel(int xp) {
    // Fórmula simple y escalable (cada nivel requiere +100 XP adicionales)
    int level = 1;
    int xpNeeded = 100;
    int remainingXP = xp;

    while (remainingXP >= xpNeeded) {
      remainingXP -= xpNeeded;
      xpNeeded += 100;
      level++;
    }
    return level;
  }

  /// Devuelve el rango visual según el nivel
  String _getRankName(int level) {
    if (level < 3) return "🥉 Bronce";
    if (level < 6) return "🥈 Plata";
    if (level < 9) return "🥇 Oro";
    if (level < 12) return "💎 Diamante";
    return "👑 Leyenda";
  }

  /// Calcula el progreso dentro del nivel actual
  double _getProgressPercent(int xp) {
    int level = _calculateLevel(xp);
    int totalForPrevLevels = 0;
    for (int i = 1; i < level; i++) {
      totalForPrevLevels += (i * 100);
    }
    int xpForThisLevel = level * 100;
    int currentXPInLevel = xp - totalForPrevLevels;
    return (currentXPInLevel / xpForThisLevel).clamp(0.0, 1.0);
  }

  /// Calcula el XP total necesario para el nivel actual
  int _getXpNeededForLevel(int level) => level * 100;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text("Inicia sesión para ver tu progreso"));
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    final xpHistoryQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('xp_history')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: userDoc,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final xp = (data['xp'] ?? 0) as int;
        final level = _calculateLevel(xp);
        final rank = _getRankName(level);
        final percent = _getProgressPercent(xp);
        final xpNeeded = _getXpNeededForLevel(level);
        final currentLevelXP = (percent * xpNeeded).toInt();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👑 Nivel y rango
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Nivel $level",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    rank,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ⚡ Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 12,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 6),

              Text(
                "$currentLevelXP / $xpNeeded XP",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // 📜 Historial reciente de XP
              const Text(
                "Últimos logros",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: xpHistoryQuery,
                builder: (context, historySnapshot) {
                  if (!historySnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final docs = historySnapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Aún no has ganado experiencia.",
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final reason = d['reason'] ?? 'Actividad desconocida';
                      final amount = d['amount'] ?? 0;
                      final time = (d['timestamp'] as Timestamp?)?.toDate();
                      final dateText = time != null
                          ? "${time.day}/${time.month}/${time.year}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                reason,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "+$amount XP",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateText,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
