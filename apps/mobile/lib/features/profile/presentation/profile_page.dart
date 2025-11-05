// 📦 Importaciones principales
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/data/auth_service.dart';
import '../../social/data/social_follow_service.dart';
import 'edit_profile_page.dart';

/// ===============================================================
/// 🧾 ProfilePage — Pantalla del perfil del jugador (versión PRO)
/// ===============================================================
/// - Muestra datos en tiempo real desde Firestore.
/// - Incluye botón de seguir / siguiendo.
/// - Muestra contadores: seguidores, seguidos y publicaciones.
/// - Permite editar perfil y cerrar sesión.
/// ===============================================================
class ProfilePage extends StatefulWidget {
  final String? userId; // Si se pasa otro usuario, se muestra su perfil

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _followService = SocialFollowService();

  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final current = _auth.currentUser;
    if (current == null ||
        widget.userId == null ||
        widget.userId == current.uid) return;

    final following = await _followService.isFollowing(widget.userId!);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    if (_isLoadingFollow) return;
    setState(() => _isLoadingFollow = true);
    await _followService.toggleFollow(widget.userId!);
    await _checkFollowStatus();
    setState(() => _isLoadingFollow = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final userId = widget.userId ?? currentUser?.uid;

    if (userId == null) {
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
        title: const Text('Perfil ⚽'),
        backgroundColor: Colors.black,
        elevation: 2,
        actions: [
          if (widget.userId == null) // Solo en el propio perfil
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                await AuthService().signOut();
              },
            ),
        ],
      ),

      // ===================== CONTENIDO =====================
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
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
                'Este jugador aún no tiene perfil configurado.',
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
          final sex = data['sex'] ?? '-';
          final rank = data['rank'] ?? 'Bronce';
          final xp = (data['xp'] ?? 0).toInt();
          final photoUrl = data['photoUrl'];
          final followers = data['followersCount'] ?? 0;
          final following = data['followingCount'] ?? 0;
          final posts = data['postsCount'] ?? 0;
          final partidos = (data['matches'] ?? 0).toString();
          final victorias = (data['wins'] ?? 0).toString();
          final empates = (data['draws'] ?? 0).toString();
          final derrotas = (data['losses'] ?? 0).toString();

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

          final isMyProfile = currentUser?.uid == userId;

          // ===================== INTERFAZ =====================
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

                // 🏷️ INFORMACIÓN
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text('@$nickname',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  'Sexo: $sex  ·  $position  ·  $city',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 16),

                // 👥 CONTADORES SOCIALES
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialCounter(label: 'Seguidores', value: followers),
                    const SizedBox(width: 20),
                    _SocialCounter(label: 'Seguidos', value: following),
                    const SizedBox(width: 20),
                    _SocialCounter(label: 'Posts', value: posts),
                  ],
                ),

                const SizedBox(height: 20),

                // 🧠 PROGRESO
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
                      const Text('Progreso de nivel',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progreso,
                        color: Colors.blueAccent,
                        backgroundColor: Colors.grey.shade800,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 10),
                      Text('Rango: $rank',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(
                          'XP: $xp / ${siguienteNivel.value} (${siguienteNivel.key})',
                          style: const TextStyle(color: Colors.white54)),
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

                // 🧩 BOTONES (editar o seguir)
                if (isMyProfile)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfilePage()),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar perfil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoadingFollow ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? Colors.grey[800] : Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 60),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _isLoadingFollow
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isFollowing ? 'Siguiendo' : 'Seguir',
                            style: const TextStyle(color: Colors.white),
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

/// ===============================================================
/// 👥 _SocialCounter — Contador pequeño (seguidores / seguidos / posts)
/// ===============================================================
class _SocialCounter extends StatelessWidget {
  final String label;
  final int value;

  const _SocialCounter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}
