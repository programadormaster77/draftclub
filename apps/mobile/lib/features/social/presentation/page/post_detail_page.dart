import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_comments_service.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// ============================================================================
/// 🖼️ PostDetailPage — Detalle del post con animación de entrada única
/// ============================================================================
/// ✅ Fade + zoom suave solo la primera vez.
/// ✅ Carga inmediata del contenido multimedia.
/// ✅ Campo de comentario fijo y limpio.
/// ============================================================================
class PostDetailPage extends StatefulWidget {
  final Post post;
  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _commentCtrl = TextEditingController();
  final _commentsService = SocialCommentsService();
  bool _sending = false;
  Map<String, dynamic>? _authorData;
  VideoPlayerController? _videoCtrl;

  static final Map<String, bool> _animationPlayed = {}; // 👈 Control de “una vez”
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _loadAuthor();
    _initMedia();

    // 🎞️ Animación solo si aún no se ha mostrado antes
    final alreadyPlayed = _animationPlayed[widget.post.id] ?? false;
    _animCtrl = AnimationController(
      vsync: this,
      duration: alreadyPlayed
          ? const Duration(milliseconds: 0)
          : const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.97, end: 1.0).animate(_fadeAnim);

    if (!alreadyPlayed) {
      _animCtrl.forward().then((_) {
        _animationPlayed[widget.post.id] = true;
      });
    } else {
      _animCtrl.value = 1.0;
    }
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

  Future<void> _initMedia() async {
    if (widget.post.type == 'video' && widget.post.mediaUrls.isNotEmpty) {
      final url = widget.post.mediaUrls.first;
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          setState(() {});
          _videoCtrl!.play();
        });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _commentCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Publicación'),
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CABECERA DEL POST
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
                                  ProfilePage(userId: widget.post.authorId),
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
                            const SizedBox(height: 4),
                            Text(
                              widget.post.caption.isNotEmpty
                                  ? widget.post.caption
                                  : '(Sin descripción)',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (_auth.currentUser != null &&
                          _auth.currentUser!.uid != widget.post.authorId)
                        _FollowButton(
                          authorId: widget.post.authorId,
                          currentUserId: _auth.currentUser!.uid,
                        ),
                    ],
                  ),
                ),

                // CONTENIDO MULTIMEDIA CON EFECTO
                if (widget.post.mediaUrls.isNotEmpty)
                  AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _fadeAnim.value,
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: child,
                      ),
                    ),
                    child: Container(
                      color: Colors.black,
                      width: double.infinity,
                      height: 360,
                      child: widget.post.type == 'video'
                          ? (_videoCtrl == null ||
                                  !_videoCtrl!.value.isInitialized)
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blueAccent),
                                )
                              : AspectRatio(
                                  aspectRatio:
                                      _videoCtrl!.value.aspectRatio > 0
                                          ? _videoCtrl!.value.aspectRatio
                                          : 1,
                                  child: VideoPlayer(_videoCtrl!),
                                )
                          : FadeInImage.assetNetwork(
                              placeholder: 'assets/images/placeholder.jpg',
                              image: widget.post.mediaUrls.first,
                              fit: BoxFit.cover,
                              imageErrorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image,
                                      color: Colors.white30),
                            ),
                    ),
                  ),

                const Divider(height: 1, color: Colors.white12),

                // COMENTARIOS
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _commentsService.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(
                                color: Colors.blueAccent),
                          ),
                        );
                      }

                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              '💬 No hay comentarios todavía.\nSé el primero en escribir uno.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 15),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: comments.map((c) {
                          final date =
                              (c['createdAt'] as Timestamp?)?.toDate();
                          return _buildCommentTile(context, c, date);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // CAMPO DE COMENTARIO FIJO
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                color: const Color(0xFF1A1A1A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: _sending ? null : _sendComment,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(
      BuildContext context, Map<String, dynamic> c, DateTime? date) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(c['authorId'])
          .get(),
      builder: (context, snap) {
        final user = snap.data?.data() as Map<String, dynamic>?;
        final name = user?['name'] ?? user?['nickname'] ?? 'Jugador';
        final photo = user?['photoUrl'];
        final isMine = c['authorId'] == _auth.currentUser?.uid;

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
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (photo != null && (photo as String).isNotEmpty)
                        ? NetworkImage(photo)
                        : null,
                backgroundColor: Colors.white12,
                child: (photo == null || photo.isEmpty)
                    ? const Icon(Icons.person,
                        color: Colors.white70, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMine)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white54, size: 18),
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
                                    style:
                                        TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar',
                                    style: TextStyle(
                                        color: Colors.redAccent)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c['text'] ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    if (date != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.5),
                        child: Text(
                          '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
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
  }

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
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
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
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
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
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(
              _isFollowing ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
    );
  }
}