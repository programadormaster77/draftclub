import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_likes_service.dart';
import 'package:draftclub_mobile/features/social/data/social_reports_service.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/presentation/page/post_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// ============================================================================
/// 🖼️ PostCard — Tarjeta del feed social (versión PRO++)
/// ============================================================================
/// • Muestra nombre y avatar del autor (lee users/<authorId>)
/// • Botón “Seguir” (stub listo para conectar al servicio de follow)
/// • Imagen con aspecto 4:5 (estilo Instagram) y vídeo con reproductor simple
/// • Likes atómicos (sin dobles toques fantasma) y contador en stream
/// • Menú contextual: copiar enlace, reportar, eliminar (autor)
/// ============================================================================

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _likesService = SocialLikesService();
  final _reportsService = SocialReportsService();
  final _auth = FirebaseAuth.instance;

  bool _isLiked = false;
  bool _isProcessingLike = false;
  String? _currentUserId;
  late Stream<int> _likeCountStream = const Stream<int>.empty();

  /// Cache de datos del autor (para no consultar en cada build)
  Map<String, dynamic>? _author;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _currentUserId = _auth.currentUser?.uid;

      // estado de like del usuario y stream de conteo
      final liked = await _likesService.isPostLiked(widget.post.id);
      final stream = _likesService.getLikeCountStream(widget.post.id);

      // cargar datos del autor (users/<authorId>)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.authorId)
          .get();

      if (!mounted) return;
      setState(() {
        _isLiked = liked;
        _likeCountStream = stream;
        _author = userDoc.data();
      });
    } catch (e) {
      debugPrint('⚠️ Error init PostCard: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isProcessingLike) return;
    _isProcessingLike = true;

    try {
      await _likesService.toggleLike(widget.post.id);
      if (mounted) setState(() => _isLiked = !_isLiked);
    } catch (e) {
      debugPrint('⚠️ Error al alternar like: $e');
    } finally {
      _isProcessingLike = false;
    }
  }

  // ----------------------------------------------------------------------------
  // MENÚ: Copiar enlace / Reportar / Eliminar (autor)
  // ----------------------------------------------------------------------------
  void _showPostOptions(BuildContext context) {
    final isAuthor = _currentUserId == widget.post.authorId;

    showModalBottomSheet(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.white70),
                title: const Text('Copiar enlace',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  final url = 'https://draftclub.app/post/${widget.post.id}';
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.blueAccent,
                      content: Text('🔗 Enlace copiado'),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                title: const Text('Reportar publicación',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final reason = await _selectReportReason(context);
                  if (reason == null) return;

                  final already =
                      await _reportsService.hasReported(widget.post.id);
                  if (already) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.grey,
                        content: Text('⚠️ Ya has reportado esta publicación.'),
                      ),
                    );
                    return;
                  }

                  await _reportsService.createReport(
                    postId: widget.post.id,
                    authorId: widget.post.authorId,
                    reason: reason,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.orangeAccent,
                      content: Text('🚨 Reporte enviado correctamente.'),
                    ),
                  );
                },
              ),
              if (isAuthor) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Eliminar publicación',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await _confirmDelete(context);
                    if (ok == true) {
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.id)
                          .update({'deleted': true});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('🗑️ Publicación eliminada'),
                        ),
                      );
                    }
                  },
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _selectReportReason(BuildContext context) async {
    String? selected;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Motivo del reporte',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  activeColor: Colors.orangeAccent,
                  title: const Text('Contenido inapropiado',
                      style: TextStyle(color: Colors.white70)),
                  value: 'Contenido inapropiado',
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                ),
                RadioListTile<String>(
                  activeColor: Colors.orangeAccent,
                  title: const Text('Spam o publicidad',
                      style: TextStyle(color: Colors.white70)),
                  value: 'Spam o publicidad',
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                ),
                RadioListTile<String>(
                  activeColor: Colors.orangeAccent,
                  title: const Text('Acoso o bullying',
                      style: TextStyle(color: Colors.white70)),
                  value: 'Acoso o bullying',
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Enviar',
                style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Eliminar publicación',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          '¿Seguro que deseas eliminar esta publicación?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorSurface = theme.colorScheme.surface;
    const textPrimary = Colors.white;
    const textSecondary = Colors.white70;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailPage(post: widget.post)),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: colorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------- CABECERA ---------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _Avatar(photoUrl: _author?['photoUrl']),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_author?['name'] ??
                              _author?['nickname'] ??
                              'Jugador') as String,
                          style: const TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.post.city} • ${_formatDate(widget.post.createdAt.toDate())}',
                          style: const TextStyle(
                              color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if ((_currentUserId != null) &&
                      _currentUserId != widget.post.authorId)
                    _FollowButton(
                      authorId: widget.post.authorId,
                      currentUserId: _currentUserId!,
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white54, size: 20),
                    onPressed: () => _showPostOptions(context),
                  ),
                ],
              ),
            ),

            // --------------------- MEDIA ---------------------
            if (widget.post.mediaUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PostMedia(url: widget.post.mediaUrls.first),
              )
            else
              Container(
                height: 220,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.sports_soccer,
                      color: Colors.white30, size: 50),
                ),
              ),

            // --------------------- DESCRIPCIÓN ---------------------
            if (widget.post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text(
                  widget.post.caption,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
              ),

            // --------------------- FOOTER ---------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            _isLiked
                                ? Icons.favorite
                                : Icons.favorite_border_outlined,
                            color: _isLiked ? Colors.redAccent : Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StreamBuilder<int>(
                        stream: _likeCountStream,
                        builder: (context, snapshot) {
                          final likes = snapshot.data ?? widget.post.likeCount;
                          return Text('$likes',
                              style: const TextStyle(
                                  color: textSecondary, fontSize: 13));
                        },
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailPage(post: widget.post),
                            ),
                          );
                        },
                        child: const Icon(Icons.comment_outlined,
                            color: Colors.white70, size: 20),
                      ),
                      const SizedBox(width: 6),
                      Text('${widget.post.commentCount}',
                          style: const TextStyle(
                              color: textSecondary, fontSize: 13)),
                    ],
                  ),
                  Text(
                    widget.post.visibility == 'public' ? 'Público' : 'Privado',
                    style: TextStyle(
                      color: Colors.blueAccent.shade100,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}

/// ============================================================================
/// Widgets auxiliares
/// ============================================================================

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 18,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      backgroundColor: Colors.white12,
      child: hasPhoto
          ? null
          : const Icon(Icons.person, color: Colors.white70, size: 18),
    );
  }
}

/// Botón “Seguir” (stub listo para conectar a tu servicio de follows).
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
  bool _loading = false;
  bool _isFollowing = false;
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    // escucha rápida para reflejar estado
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('following')
        .doc(widget.authorId);

    _sub = ref.snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => _isFollowing = snap.exists);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggleFollow() async {
    if (_loading) return;
    setState(() => _loading = true);

    final myFollowingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('following')
        .doc(widget.authorId);

    final hisFollowersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.authorId)
        .collection('followers')
        .doc(widget.currentUserId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fSnap = await tx.get(myFollowingRef);
        if (fSnap.exists) {
          tx.delete(myFollowingRef);
          tx.delete(hisFollowersRef);
        } else {
          tx.set(myFollowingRef, {
            'since': FieldValue.serverTimestamp(),
          });
          tx.set(hisFollowersRef, {
            'since': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error toggle follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error al cambiar el estado de seguimiento'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _toggleFollow,
      style: TextButton.styleFrom(
        backgroundColor:
            _isFollowing ? Colors.white10 : Colors.blueAccent, // contraste
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

/// Muestra imagen (aspecto 4:5) o video (player simple) según la URL.
class _PostMedia extends StatelessWidget {
  final String url;
  const _PostMedia({required this.url});

  bool get _isVideo {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.contains('video'); // por si el storage taggea
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) return _VideoPreview(url: url);

    // Imagen con aspecto 4:5 (vertical “estilo Instagram”)
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black12,
          child: const Center(
            child: Text(
              'Imagen no disponible',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.black12,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          );
        },
      ),
    );
  }
}

/// Player de video minimalista con overlay de play/pause.
class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_initialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 350,
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    final aspect = _controller.value.aspectRatio == 0
        ? 16 / 9
        : _controller.value.aspectRatio;

    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggle,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton(
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white70,
                size: 28,
              ),
              onPressed: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}
