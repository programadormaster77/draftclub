import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 📋 FollowListPage — Lista de Seguidores o Seguidos (Versión PRO v3)
/// ============================================================================
/// ✅ Muestra lista completa (nombre, nickname, foto, seguir/siguiendo)
/// ✅ Enlaza a perfiles individuales.
/// ✅ Actualiza todo en tiempo real.
/// ✅ Optimizada con streams y control de estado local.
/// ============================================================================

class FollowListPage extends StatefulWidget {
  final String userId;
  final bool showFollowers; // true = seguidores, false = seguidos
  const FollowListPage({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final _auth = FirebaseAuth.instance;
  final _followService = SocialFollowService();

  @override
  Widget build(BuildContext context) {
    final title = widget.showFollowers ? 'Seguidores' : 'Siguiendo';

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title),
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: widget.showFollowers
            ? _followService.getFollowers(widget.userId)
            : _followService.getFollowing(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final ids = snapshot.data ?? [];
          if (ids.isEmpty) {
            return Center(
              child: Text(
                widget.showFollowers
                    ? 'Aún no tienes seguidores.'
                    : 'Aún no sigues a nadie.',
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            );
          }

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final userId = ids[index];
              return _UserTile(userId: userId);
            },
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// 🔹 _UserTile — Ítem de usuario (foto + nombre + nickname + botón seguir)
/// ============================================================================

class _UserTile extends StatefulWidget {
  final String userId;
  const _UserTile({required this.userId});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
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
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == widget.userId) return;

    final following = await _followService.isFollowing(widget.userId);
    if (mounted) setState(() => _isFollowing = following);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ListTile(
            title: Text('Usuario no encontrado',
                style: TextStyle(color: Colors.white54)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? data['nickname'] ?? 'Jugador';
        final nickname = data['nickname'] ?? '';
        final photoUrl = data['photoUrl'] ?? '';

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(userId: widget.userId),
              ),
            );
          },
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white12,
            backgroundImage:
                (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            child: (photoUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          title: Text(
            name,
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: nickname.isNotEmpty
              ? Text('@$nickname',
                  style: const TextStyle(color: Colors.white54, fontSize: 13))
              : null,
          trailing: (currentUserId != null && currentUserId != widget.userId)
              ? TextButton(
                  onPressed: _toggleFollow,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        _isFollowing ? Colors.white10 : Colors.blueAccent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isFollowing ? 'Siguiendo' : 'Seguir',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                )
              : null,
        );
      },
    );
  }
}