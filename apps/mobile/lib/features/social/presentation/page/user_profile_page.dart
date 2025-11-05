import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/presentation/page/edit_profile_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/follow_list_page.dart';
import 'package:draftclub_mobile/features/social/presentation/widgets/post_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 👤 UserProfilePage — Perfil de usuario (Versión PRO++)
/// ============================================================================
/// ✅ Carga perfil desde Firestore.
/// ✅ Usa SocialFollowService para seguir/dejar de seguir.
/// ✅ Contadores en tiempo real: seguidores, seguidos y publicaciones.
/// ✅ Feed del usuario.
/// ✅ Botón Editar perfil si es el usuario actual.
/// ✅ Al tocar seguidores/siguiendo abre FollowListPage.
/// ============================================================================

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _followService = SocialFollowService();
  bool _loadingFollow = false;
  bool _isFollowing = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _initFollowState();
  }

  Future<void> _initFollowState() async {
    final me = _auth.currentUser?.uid;
    if (me == null) return;
    _isMe = me == widget.userId;
    if (!_isMe) {
      final status = await _followService.isFollowing(widget.userId);
      if (mounted) setState(() => _isFollowing = status);
    }
  }

  Future<void> _toggleFollow() async {
    if (_loadingFollow || _isMe) return;
    setState(() => _loadingFollow = true);
    await _followService.toggleFollow(widget.userId);
    final status = await _followService.isFollowing(widget.userId);
    if (mounted) {
      setState(() {
        _isFollowing = status;
        _loadingFollow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Perfil'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(
              child: Text('Usuario no encontrado',
                  style: TextStyle(color: Colors.white70)),
            );
          }

          final data = userSnap.data!.data() as Map<String, dynamic>;
          final name = (data['name'] ?? data['nickname'] ?? 'Jugador') as String;
          final nickname = (data['nickname'] ?? '') as String;
          final city = (data['city'] ?? '-') as String;
          final bio = (data['bio'] ?? '') as String;
          final photoUrl = (data['photoUrl'] ?? '') as String;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.white12,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person,
                                color: Colors.white70, size: 42)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            if (nickname.isNotEmpty)
                              Text('@$nickname',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(city,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            if (bio.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, right: 4),
                                child: Text(bio,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                      if (!_isMe)
                        TextButton(
                          onPressed: _toggleFollow,
                          style: TextButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.white10
                                : Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loadingFollow
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isFollowing ? 'Siguiendo' : 'Seguir',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                        )
                      else
                        OutlinedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EditProfilePage()),
                            );
                            if (result == true) setState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Editar perfil',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _CountsSection(userId: widget.userId),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text('Publicaciones',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ),
              ),
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('authorId', isEqualTo: widget.userId)
                      .where('deleted', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent),
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('Sin publicaciones todavía',
                              style: TextStyle(color: Colors.white54)),
                        ),
                      );
                    }

                    final posts =
                        docs.map((d) => Post.fromFirestore(d)).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (_, i) => PostCard(post: posts[i]),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// 🔹 Contadores con navegación a FollowListPage
/// ============================================================================
class _CountsSection extends StatelessWidget {
  final String userId;
  const _CountsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final followService = SocialFollowService();
    final firestore = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _InteractiveCounter(
            label: 'Seguidores',
            stream: followService.getFollowers(userId),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FollowListPage(userId: userId, showFollowers: true),
                ),
              );
            },
          ),
          _InteractiveCounter(
            label: 'Siguiendo',
            stream: followService.getFollowing(userId),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FollowListPage(userId: userId, showFollowers: false),
                ),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('posts')
                .where('authorId', isEqualTo: userId)
                .where('deleted', isEqualTo: false)
                .snapshots(),
            builder: (_, s) {
              final count = s.data?.docs.length ?? 0;
              return _CounterItem('Publicaciones', count);
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 🔸 Widget contador interactivo (abre listas de seguidores/siguiendo)
/// ============================================================================
class _InteractiveCounter extends StatelessWidget {
  final String label;
  final Stream<List<String>> stream;
  final VoidCallback onTap;

  const _InteractiveCounter({
    required this.label,
    required this.stream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return GestureDetector(
          onTap: onTap,
          child: _CounterItem(label, count),
        );
      },
    );
  }
}

/// ============================================================================
/// 🔸 Contador visual genérico
/// ============================================================================
Widget _CounterItem(String label, int value) {
  return Column(
    children: [
      Text('$value',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
    ],
  );
}