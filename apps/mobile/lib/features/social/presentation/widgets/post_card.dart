import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/social_likes_service.dart';
import 'package:draftclub_mobile/features/social/data/social_reports_service.dart';
import 'package:draftclub_mobile/features/social/data/social_follow_service.dart';
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/presentation/page/post_detail_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/user_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// ============================================================================
/// 🖼️ PostCard — Tarjeta del feed social (versión PRO++ completa)
/// ============================================================================
/// • Muestra nombre y avatar del autor (lee users/<authorId>) con fallback.
/// • Avatar/nombre abren UserProfilePage(userId: authorId).
/// • Botón “Seguir” usando SocialFollowService (atómico).
/// • Soporta 1..N medias (fotos/videos) en carrusel con indicadores.
/// • Double-tap para LIKE con animación (sin dobles estados).
/// • Likes atómicos con stream de conteo + contador de comentarios.
/// • Menú contextual: copiar enlace, reportar, eliminar (autor).
/// • Manejo defensivo: posts deleted=true no se renderizan, authorId vacío,
///   usuarios inexistentes, medias caídas, etc.
/// • Player de video con loop, mute y tap-to-play/pause.
/// • Skeletons ligeros mientras cargan autor/medias.
/// ============================================================================

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  final _likesService = SocialLikesService();
  final _reportsService = SocialReportsService();
  final _followService = SocialFollowService();
  final _auth = FirebaseAuth.instance;

  String? _currentUserId;

  bool _isLiked = false;
  bool _isProcessingLike = false;
  bool _isAuthor = false;
  bool _authorLoaded = false;
  Map<String, dynamic>? _author;

  late Stream<int> _likeCountStream = const Stream<int>.empty();

  // Carrusel
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // Animación de corazón (double-tap)
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 160),
      value: 0.0,
    );
    _heartScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOutBack),
    );

    _bootstrap();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _currentUserId = _auth.currentUser?.uid;

      // ⚠️ Ignorar posts eliminados
      if (widget.post.deleted) return;

      // Estado del like del usuario y stream de conteo
      final liked = await _likesService.isPostLiked(widget.post.id);
      final stream = _likesService.getLikeCountStream(widget.post.id);

      // Datos autor (defensivo si authorId viene vacío)
      if (widget.post.authorId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.post.authorId)
            .get();
        _author = userDoc.data();
      }

      _isAuthor = (_currentUserId != null &&
          widget.post.authorId.isNotEmpty &&
          _currentUserId == widget.post.authorId);

      if (!mounted) return;
      setState(() {
        _isLiked = liked;
        _likeCountStream = stream;
        _authorLoaded = true;
      });
    } catch (e) {
      debugPrint('⚠️ Error init PostCard: $e');
      if (mounted) setState(() => _authorLoaded = true);
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

  Future<void> _likeWithHeart() async {
    if (!_isLiked) {
      await _toggleLike();
      if (!mounted) return;
      // Pop de corazón
      _heartCtrl.forward(from: 0.0);
      // Dejar que haga reverse suave
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) _heartCtrl.reverse();
      });
    }
  }

  // ----------------------------------------------------------------------------
  // MENÚ: Copiar enlace / Reportar / Eliminar (autor)
  // ----------------------------------------------------------------------------
  void _showPostOptions(BuildContext context) {
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
              if (_isAuthor) ...[
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
                      if (!mounted) return;
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
                for (final reason in const [
                  'Contenido inapropiado',
                  'Spam o publicidad',
                  'Acoso o bullying'
                ])
                  RadioListTile<String>(
                    activeColor: Colors.orangeAccent,
                    title: Text(reason,
                        style: const TextStyle(color: Colors.white70)),
                    value: reason,
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
    // No renderizar posts eliminados
    if (widget.post.deleted) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorSurface = theme.colorScheme.surface;
    const textPrimary = Colors.white;
    const textSecondary = Colors.white70;

    // Datos autor (fallbacks)
    final displayName =
        (_author?['name'] ?? _author?['nickname'] ?? 'Jugador').toString();
    final photoUrl = (_author?['photoUrl'] ?? '').toString();
    final showCityPrefix =
        widget.post.city.isNotEmpty ? '${widget.post.city} • ' : '';

    void _openAuthorProfile() {
      if (widget.post.authorId.isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(userId: widget.post.authorId),
        ),
      );
    }

    // Medias: si no hay, muestra placeholder visual elegante
    final medias = widget.post.mediaUrls;
    final hasMedia = medias.isNotEmpty;

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
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------- CABECERA ---------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openAuthorProfile,
                    child: _authorLoaded
                        ? _Avatar(photoUrl: photoUrl)
                        : const _AvatarSkeleton(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openAuthorProfile,
                      child: _authorLoaded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  '$showCityPrefix${_formatDate(widget.post.createdAt.toDate())}',
                                  style: const TextStyle(
                                      color: textSecondary, fontSize: 12),
                                ),
                              ],
                            )
                          : const _TitleSkeleton(),
                    ),
                  ),
                  if ((_currentUserId != null) &&
                      _currentUserId != widget.post.authorId &&
                      widget.post.authorId.isNotEmpty)
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

            // --------------------- MEDIA/CARRUSEL ---------------------
            if (hasMedia)
              _MediaCarousel(
                medias: medias,
                onDoubleTap: _likeWithHeart,
                currentPage: _currentPage,
                onPageChanged: (i) => setState(() => _currentPage = i),
                heartScale: _heartScale,
              )
            else
              _EmptyMediaPlaceholder(onDoubleTap: _likeWithHeart, heartScale: _heartScale),

            // --------------------- DESCRIPCIÓN ---------------------
            if (widget.post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text(
                  widget.post.caption,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                ),
              ),

            // --------------------- TAGS / MENCIONES (opcional, liviano) ------
            if (widget.post.tags.isNotEmpty || widget.post.mentions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final t in widget.post.tags)
                      _ChipTag(text: '#$t'),
                    for (final m in widget.post.mentions)
                      _ChipTag(text: '@$m'),
                  ],
                ),
              ),

            // --------------------- FOOTER ---------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Likes + Comentarios
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Icon(
                          _isLiked
                              ? Icons.favorite
                              : Icons.favorite_border_outlined,
                          color:
                              _isLiked ? Colors.redAccent : Colors.white70,
                          size: 22,
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
                              builder: (_) =>
                                  PostDetailPage(post: widget.post),
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
                  // Visibilidad
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
/// Widgets auxiliares: Avatar/Skeletons/Chips
/// ============================================================================

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 20,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      backgroundColor: Colors.white10,
      child: hasPhoto
          ? null
          : const Icon(Icons.person, color: Colors.white70, size: 18),
    );
  }
}

class _AvatarSkeleton extends StatelessWidget {
  const _AvatarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white10, borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _TitleSkeleton extends StatelessWidget {
  const _TitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 12, width: 120, color: Colors.white10),
        const SizedBox(height: 6),
        Container(height: 10, width: 160, color: Colors.white10),
      ],
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String text;
  const _ChipTag({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12, borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

/// ============================================================================
/// Carrusel de medias: soporta imágenes y videos con indicadores.
/// Incluye double-tap para LIKE con animación de corazón.
/// ============================================================================
class _MediaCarousel extends StatefulWidget {
  final List<String> medias;
  final void Function() onDoubleTap;
  final int currentPage;
  final void Function(int) onPageChanged;
  final Animation<double> heartScale;

  const _MediaCarousel({
    required this.medias,
    required this.onDoubleTap,
    required this.currentPage,
    required this.onPageChanged,
    required this.heartScale,
  });

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  final PageController _localPageCtrl = PageController();
  @override
  void dispose() {
    _localPageCtrl.dispose();
    super.dispose();
  }

  bool _isVideo(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    // Aspecto estándar 4:5 para consistencia visual de feed
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTap: widget.onDoubleTap,
            child: PageView.builder(
              controller: _localPageCtrl,
              onPageChanged: widget.onPageChanged,
              itemCount: widget.medias.length,
              itemBuilder: (_, i) {
                final url = widget.medias[i];
                if (_isVideo(url)) {
                  return _VideoPreview(url: url, fill: true);
                }
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Text('Imagen no disponible',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _MediaSkeleton();
                  },
                );
              },
            ),
          ),

          // Corazón animado (double-tap)
          ScaleTransition(
            scale: widget.heartScale,
            child: const Icon(Icons.favorite, color: Colors.white70, size: 88),
          ),

          // Indicadores de página
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.medias.length, (i) {
                  final active = i == widget.currentPage;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaSkeleton extends StatelessWidget {
  const _MediaSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
    );
    }
}

/// Placeholder cuando no hay medias: muestra ícono + anima heart en double-tap.
class _EmptyMediaPlaceholder extends StatelessWidget {
  final VoidCallback onDoubleTap;
  final Animation<double> heartScale;
  const _EmptyMediaPlaceholder({
    required this.onDoubleTap,
    required this.heartScale,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
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
            ScaleTransition(
              scale: heartScale,
              child:
                  const Icon(Icons.favorite, color: Colors.white70, size: 88),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// Botón “Seguir” usando SocialFollowService (sin listeners manuales).
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
    _initFollowState();
  }

  Future<void> _initFollowState() async {
    if (widget.authorId.isEmpty) return;
    final status = await _service.isFollowing(widget.authorId);
    if (mounted) setState(() => _isFollowing = status);
  }

  Future<void> _toggleFollow() async {
    if (_loading || widget.authorId.isEmpty) return;
    setState(() => _loading = true);

    try {
      await _service.toggleFollow(widget.authorId);
      await _initFollowState();
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
        backgroundColor: _isFollowing ? Colors.white10 : Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isFollowing ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
    );
  }
}

/// ============================================================================
/// Player de video minimalista con loop/mute y tap-to-play/pause.
/// `fill=true` permite ajustar dentro de AspectRatio externo (carrusel).
/// ============================================================================
class _VideoPreview extends StatefulWidget {
  final String url;
  final bool fill;
  const _VideoPreview({required this.url, this.fill = false});

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
      ..setLooping(true)
      ..setVolume(0)
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
      return const _MediaSkeleton();
    }

    final aspect = _controller.value.aspectRatio == 0
        ? 16 / 9
        : _controller.value.aspectRatio;

    final child = Stack(
      alignment: Alignment.center,
      children: [
        FittedBox(
          fit: widget.fill ? BoxFit.cover : BoxFit.contain,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
        GestureDetector(
          onTap: _toggle,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _controller.value.isPlaying ? 0 : 1,
            child: const Icon(Icons.play_circle_outline,
                size: 64, color: Colors.white70),
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
    );

    if (widget.fill) {
      // El contenedor padre controla el aspect ratio (carrusel 4:5)
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      );
    }

    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}