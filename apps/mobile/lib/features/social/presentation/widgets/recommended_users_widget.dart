import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 🌟 RecommendedUsersWidget — Sugerencias de jugadores para seguir
/// ============================================================================
/// ✅ Muestra jugadores populares (según followersCount o XP)
/// ✅ Evita mostrar al usuario actual ni repetidos.
/// ✅ Permite seguir directamente desde aquí.
/// ✅ UI coherente con el tema oscuro de DraftClub.
/// ============================================================================

class RecommendedUsersWidget extends StatefulWidget {
  const RecommendedUsersWidget({super.key});

  @override
  State<RecommendedUsersWidget> createState() => _RecommendedUsersWidgetState();
}

class _RecommendedUsersWidgetState extends State<RecommendedUsersWidget> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _followService = SocialFollowService();
  List<String> _myFollowing = [];

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    final me = _auth.currentUser?.uid;
    if (me == null) return;
    final snap = await _firestore
        .collection('users')
        .doc(me)
        .collection('following')
        .get();
    setState(() {
      _myFollowing = snap.docs.map((d) => d.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .orderBy('followersCount', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = doc.id;
          if (uid == currentUserId) return false; // No mostrarme a mí mismo
          if (_myFollowing.contains(uid)) return false; // No mostrar ya seguidos
          return (data['name'] != null && data['photoUrl'] != null);
        }).toList();

        if (users.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              '🎯 Jugadores populares',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data = users[index].data() as Map<String, dynamic>;
                  final uid = users[index].id;
                  final name = data['name'] ?? 'Jugador';
                  final photoUrl = data['photoUrl'] ?? '';
                  final followers = data['followersCount'] ?? 0;

                  return _UserSuggestionCard(
                    userId: uid,
                    name: name,
                    photoUrl: photoUrl,
                    followers: followers,
                    onFollowed: _loadFollowing,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ============================================================================
/// 💫 _UserSuggestionCard — Tarjeta individual para sugerencias
/// ============================================================================

class _UserSuggestionCard extends StatefulWidget {
  final String userId;
  final String name;
  final String photoUrl;
  final int followers;
  final VoidCallback onFollowed;

  const _UserSuggestionCard({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.followers,
    required this.onFollowed,
  });

  @override
  State<_UserSuggestionCard> createState() => _UserSuggestionCardState();
}

class _UserSuggestionCardState extends State<_UserSuggestionCard> {
  final _auth = FirebaseAuth.instance;
  final _followService = SocialFollowService();
  bool _isFollowing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == widget.userId) return;
    final status = await _followService.isFollowing(widget.userId);
    if (mounted) setState(() => _isFollowing = status);
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    setState(() => _loading = true);

    await _followService.toggleFollow(widget.userId);
    final status = await _followService.isFollowing(widget.userId);

    if (mounted) {
      setState(() {
        _isFollowing = status;
        _loading = false;
      });
      widget.onFollowed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
      ),
      child: Container(
        width: 95,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: widget.photoUrl.isNotEmpty
                  ? NetworkImage(widget.photoUrl)
                  : null,
              backgroundColor: Colors.white12,
              child: widget.photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white38)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              widget.name.split(' ').first,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              '${widget.followers} seg.',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _toggleFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isFollowing
                      ? Colors.white10
                      : Colors.blueAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isFollowing ? 'Siguiendo' : 'Seguir',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}