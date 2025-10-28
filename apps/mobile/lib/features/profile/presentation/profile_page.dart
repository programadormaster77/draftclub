// 📦 Importaciones principales
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/data/auth_service.dart';
import 'edit_profile_page.dart';

/// ===============================================================
/// 🧾 ProfilePage — Pantalla del perfil del jugador
/// ===============================================================
/// - Lee datos en tiempo real desde Firestore.
/// - Muestra información, progreso y estadísticas.
/// - Permite editar el perfil y cerrar sesión.
/// ===============================================================
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Error: usuario no autenticado.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // ===================== APP BAR =====================
      appBar: AppBar(
        title: const Text('Mi perfil ⚽'),
        backgroundColor: Colors.black,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await AuthService().signOut();
              // El flujo de salida lo maneja AuthStateHandler automáticamente.
            },
          ),
        ],
      ),

      // ===================== CONTENIDO =====================
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Aún no tienes un perfil configurado.\nCompleta tu información.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // ===================== DATOS BASE =====================
          final name = data['name'] ?? 'Jugador';
          final nickname = data['nickname'] ?? '';
          final city = data['city'] ?? '-';
          final position = data['position'] ?? '-';
          final sex = data['sex'] ?? '-'; // 🔹 Nuevo campo mostrado
          final rank = data['rank'] ?? 'Bronce';
          final xp = (data['xp'] is int)
              ? data['xp'] as int
              : (data['xp'] is double)
                  ? (data['xp'] as double).toInt()
                  : 0;
          final photoUrl = data['photoUrl'];
          final partidos = (data['matches'] ?? 0).toString();
          final victorias = (data['wins'] ?? 0).toString();
          final empates = (data['draws'] ?? 0).toString();
          final derrotas = (data['losses'] ?? 0).toString();

          // ===================== RANGOS DISPONIBLES =====================
          final rangos = {
            'Bronce': 0,
            'Plata': 500,
            'Oro': 2000,
            'Esmeralda': 4000,
            'Diamante': 8000,
          };

          final siguienteNivel = rangos.entries.firstWhere(
            (e) => e.value > xp,
            orElse: () => const MapEntry('Máximo', 10000),
          );

          final progreso =
              (xp / siguienteNivel.value.toDouble()).clamp(0.0, 1.0);

          // ===================== INTERFAZ PRINCIPAL =====================
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 📸 FOTO DE PERFIL
                CircleAvatar(
                  radius: 60,
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),

                // 🏷️ INFORMACIÓN PRINCIPAL
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // 🔹 Mostramos sexo, posición y ciudad
                Text(
                  '@$nickname',
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sexo: $sex  ·  $position  ·  $city',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 20),

                // 🧠 PROGRESO DE NIVEL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Progreso de nivel',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progreso,
                        color: Colors.blueAccent,
                        backgroundColor: Colors.grey.shade800,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Rango: $rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'XP: $xp / ${siguienteNivel.value} (${siguienteNivel.key})',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ⚽ ESTADÍSTICAS
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1,
                  children: [
                    _StatCard(title: 'Partidos', value: partidos),
                    _StatCard(title: 'Victorias', value: victorias),
                    _StatCard(title: 'Empates', value: empates),
                    _StatCard(title: 'Derrotas', value: derrotas),
                  ],
                ),

                const SizedBox(height: 30),

                // ✏️ BOTÓN EDITAR PERFIL
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar perfil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 40,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// 📊 _StatCard — Tarjeta reutilizable para estadísticas
/// ===============================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
