import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_comments_service.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/presentation/page/user_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 💬 PostDetailPage — Detalle del post con comentarios (Versión PRO++)
/// ============================================================================
/// - Muestra la publicación y sus comentarios en tiempo real.
/// - Avatar/nombre del autor o comentarista abre su perfil.
/// - Botón “Seguir” conectado al servicio oficial.
/// - Permite editar o eliminar tus comentarios.
/// ============================================================================

class PostDetailPage extends StatefulWidget {
  final Post post;
  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _commentCtrl = TextEditingController();
  final _commentsService = SocialCommentsService();

  bool _sending = false;
  Map<String, dynamic>? _authorData;

  @override
  void initState() {
    super.initState();
    _loadAuthor();
  }

  Future<void> _loadAuthor() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.authorId)
          .get();
      if (doc.exists) setState(() => _authorData = doc.data());
    } catch (e) {
      debugPrint('⚠️ Error cargando autor: $e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _commentsService.addComment(postId: widget.post.id, text: text);
      _commentCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al enviar comentario: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Publicación'),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // ================= CABECERA DEL POST =================
          Container(
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF1A1A1A),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserProfilePage(userId: widget.post.authorId),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: (_authorData?['photoUrl'] != null &&
                            (_authorData?['photoUrl'] as String).isNotEmpty)
                        ? NetworkImage(_authorData!['photoUrl'])
                        : null,
                    backgroundColor: Colors.white12,
                    child: (_authorData?['photoUrl'] == null ||
                            (_authorData?['photoUrl'] as String).isEmpty)
                        ? const Icon(Icons.person,
                            color: Colors.white70, size: 26)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfilePage(userId: widget.post.authorId),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authorData?['name'] ??
                              _authorData?['nickname'] ??
                              'Jugador',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.post.caption,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                if (currentUser != null &&
                    currentUser.uid != widget.post.authorId)
                  _FollowButton(
                    authorId: widget.post.authorId,
                    currentUserId: currentUser.uid,
                  ),
              ],
            ),
          ),

          // ================= STREAM DE COMENTARIOS =================
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _commentsService.getCommentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      '💬 No hay comentarios todavía.\nSé el primero en escribir uno.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    final created = c['createdAt'] as Timestamp?;
                    final date = created?.toDate();
                    final isMine = c['authorId'] == currentUser?.uid;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(c['authorId'])
                          .get(),
                      builder: (context, snap) {
                        final user = snap.data?.data() as Map<String, dynamic>?;
                        final name =
                            user?['name'] ?? user?['nickname'] ?? 'Jugador';
                        final photo = user?['photoUrl'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserProfilePage(
                                          userId: c['authorId']),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundImage: (photo != null &&
                                          (photo as String).isNotEmpty)
                                      ? NetworkImage(photo)
                                      : null,
                                  backgroundColor: Colors.white12,
                                  child: (photo == null || photo.isEmpty)
                                      ? const Icon(Icons.person,
                                          color: Colors.white70, size: 18)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UserProfilePage(
                                                userId: c['authorId']),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isMine)
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert,
                                                  color: Colors.white54,
                                                  size: 18),
                                              color: const Color(0xFF1A1A1A),
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _editComment(c);
                                                } else if (value == 'delete') {
                                                  _deleteComment(c);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Editar',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white)),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Eliminar',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .redAccent)),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      c['text'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                    if (date != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 3.5),
                                        child: Text(
                                          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ================= CAMPO DE ESCRITURA =================
          SafeArea(
            child: Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un comentario...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔹 EDITAR COMENTARIO
  // ============================================================
  Future<void> _editComment(Map<String, dynamic> comment) async {
    final ctrl = TextEditingController(text: comment['text']);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Editar comentario',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: 'Escribe tu comentario...',
              hintStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar',
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(comment['id'])
          .update({'text': result});
    }
  }

  // ============================================================
  // 🔹 ELIMINAR COMENTARIO
  // ============================================================
  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar comentario',
            style: TextStyle(color: Colors.white)),
        content: const Text('¿Seguro que deseas eliminarlo?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(comment['id'])
          .delete();
    }
  }
}

/// ============================================================================
/// 🔹 Botón “Seguir” (con SocialFollowService)
/// ============================================================================
class _FollowButton extends StatefulWidget {
  final String authorId;
  final String currentUserId;
  const _FollowButton({
    required this.authorId,
    required this.currentUserId,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final _service = SocialFollowService();
  bool _loading = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkFollow();
  }

  Future<void> _checkFollow() async {
    final status = await _service.isFollowing(widget.authorId);
    if (mounted) setState(() => _isFollowing = status);
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    setState(() => _loading = true);
    await _service.toggleFollow(widget.authorId);
    await _checkFollow();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _toggleFollow,
      style: TextButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.white10 : Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(
              _isFollowing ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
    );
  }
}