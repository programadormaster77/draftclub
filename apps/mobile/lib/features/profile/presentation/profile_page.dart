// 📦 Importaciones principales
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/data/auth_service.dart';
import '../../social/data/social_follow_service.dart';
import '../../social/domain/entities/post.dart';
import '../../social/presentation/page/post_detail_page.dart';
import '../../social/presentation/page/follow_list_page.dart';
import '../../social/presentation/widgets/recommended_users_widget.dart';
import 'package:draftclub_mobile/features/notifications/presentation/notifications_settings_page.dart';
import 'edit_profile_page.dart';

/// ============================================================================
/// 🧾 ProfilePage — Perfil del jugador (Versión PRO++ 2025)
/// ============================================================================
/// ✅ Muestra datos en tiempo real desde Firestore.
/// ✅ Incluye botón seguir / editar.
/// ✅ Contadores reactivos y sección de sugerencias.
/// ✅ Parrilla de publicaciones tipo Instagram.
/// ✅ Integrado con SocialFollowService v3 (seguimiento sincronizado).
/// - Mejora estética de estadísticas y AppBar unificado (chat + logout).
/// ============================================================================

class ProfilePage extends StatefulWidget {
  final String? userId;

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

  Future<void> _refreshAfterReturn(Future<void> Function() openPage) async {
    await openPage();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() {});
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
          // 📩 Chat (ajusta la ruta si usas otra)
          IconButton(
            tooltip: 'Mensajes',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/chat');
            },
          ),
          // 🔒 Logout (solo en mi perfil)
          if (widget.userId == null)
            IconButton(
              tooltip: 'Cerrar sesión',
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
                child: CircularProgressIndicator(color: Colors.white));
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
          final posts = data['postsCount'] ?? 0;

          // 👉 Estadísticas visibles
          final partidos = (data['matches'] ?? 0).toString();
          final victoriasConfirmadas =
              (data['wins'] ?? 0).toString(); // confirmadas por árbitro
          final torneos = (data['tournaments'] ?? 0).toString();

          // (No mostramos empates/derrotas por decisión de producto)

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
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('@$nickname',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 4),
                Text('Sexo: $sex  ·  $position  ·  $city',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),

                const SizedBox(height: 12),

                // 🏅 Chip de rango (opcional visual, no cambia lógica)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2320),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4A3E36)),
                  ),
                  child: Text(
                    rank,
                    style: const TextStyle(
                        color: Color(0xFFD0B8A0), fontWeight: FontWeight.w700),
                  ),
                ),

                const SizedBox(height: 16),

                // 👥 CONTADORES SOCIALES + SUGERENCIAS
                StreamBuilder<List<String>>(
                  stream: _followService.getFollowers(userId),
                  builder: (context, followersSnap) {
                    final followersCount = followersSnap.data?.length ?? 0;
                    return StreamBuilder<List<String>>(
                      stream: _followService.getFollowing(userId),
                      builder: (context, followingSnap) {
                        final followingCount =
                            followingSnap.data?.length ?? 0;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _CounterButton(
                                  label: 'Seguidores',
                                  value: followersCount,
                                  onTap: () async {
                                    await _refreshAfterReturn(() async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowListPage(
                                            userId: userId,
                                            showFollowers: true,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(width: 20),
                                _CounterButton(
                                  label: 'Seguidos',
                                  value: followingCount,
                                  onTap: () async {
                                    await _refreshAfterReturn(() async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowListPage(
                                            userId: userId,
                                            showFollowers: false,
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(width: 20),
                                _SocialCounter(label: 'Posts', value: posts),
                              ],
                            ),
                            // 🌟 SUGERENCIAS DE JUGADORES
                            const RecommendedUsersWidget(),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                // 🧠 PROGRESO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
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

                // ⚽ ESTADÍSTICAS — Solo positivas (3 columnas)
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1,
                  children: [
                    _StatCard(title: 'Partidos', value: partidos),
                    _StatCard(
                      title: 'Victorias',
                      value: victoriasConfirmadas,
                      subtitle: 'confirmadas por árbitro',
                    ),
                    _StatCard(title: 'Torneos', value: torneos),
                  ],
                ),

                const SizedBox(height: 30),

                // 🧩 BOTONES DE ACCIÓN
                //////////////// 🧩 BOTONES ///////////////////
                if (isMyProfile) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _refreshAfterReturn(() async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        );
                      });
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
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const NotificationsSettingsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Notificaciones'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 40,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: const BorderSide(
                        color: Colors.blueAccent,
                        width: 1,
                      ),
                    ),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: _isLoadingFollow ? null : _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? Colors.grey[800] : Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 60,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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

                // ===================== ⚙️ ACCIONES INFERIORES =====================
                const SizedBox(height: 30),

// 📩 Botón de Mensajes
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mensajes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: Colors.blueAccent.withOpacity(0.4),
                    elevation: 6,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/chat');
                  },
                ),

                const SizedBox(height: 14),

// 🚪 Botón de Cerrar Sesión (solo si es mi perfil)
                if (isMyProfile)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:
                          const BorderSide(color: Colors.redAccent, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () async {
                      await AuthService().signOut();
                    },
                  ),

                const SizedBox(height: 40),

                // 🖼️ PARRILLA DE POSTS
                _UserPostsGrid(userId: userId),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// 📸 _UserPostsGrid — Grilla de publicaciones del usuario
/// ============================================================================
class _UserPostsGrid extends StatelessWidget {
  final String userId;
  const _UserPostsGrid({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('🏟️ Aún no hay publicaciones',
                  style: TextStyle(color: Colors.white54)),
            ),
          );
        }

        final posts = docs
            .map((d) => Post.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            final thumb = post.thumbUrl ??
                (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : '');
            final isVideo = post.type == 'video' ||
                thumb.toLowerCase().endsWith('.mp4') ||
                thumb.toLowerCase().contains('video');

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: thumb.isNotEmpty
                        ? Image.network(thumb, fit: BoxFit.cover)
                        : const Icon(Icons.sports_soccer,
                            color: Colors.white30, size: 40),
                  ),
                  if (isVideo)
                    const Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white70, size: 20),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// ============================================================================
/// 🔢 _CounterButton — Contador con acción (clicable)
///=============
class _CounterButton extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _CounterButton({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 📊 _StatCard — Tarjeta reutilizable para estadísticas
/// ============================================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle; // ← NUEVO

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

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
            Text(value,
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 👥 _SocialCounter — Contador simple (sin acción)
/// ============================================================================
class _SocialCounter extends StatelessWidget {
  final String label;
  final int value;

  const _SocialCounter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}