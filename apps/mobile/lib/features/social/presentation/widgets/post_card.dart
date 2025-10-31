import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/post.dart';
import '../../../data/social_likes_service.dart';
import '../../../data/social_reports_service.dart';
import '../pages/post_detail_page.dart';

/// ===============================================================
/// 🖼️ PostCard — Tarjeta visual con menú dinámico (seguro)
/// ===============================================================
/// - Likes ❤️
/// - Comentarios 💬
/// - Reportes 🚨 guardados en Firestore
/// - Menú contextual:
///    🔹 Copiar enlace (todos)
///    🔹 Reportar (todos)
///    🔹 Eliminar (solo autor del post)
/// ===============================================================
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
  late Stream<int> _likeCountStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUserId = _auth.currentUser?.uid;
    final liked = await _likesService.isPostLiked(widget.post.id);
    if (mounted) {
      setState(() {
        _isLiked = liked;
        _likeCountStream = _likesService.getLikeCountStream(widget.post.id);
      });
    }
  }

  Future<void> _toggleLike() async {
    await _likesService.toggleLike(widget.post.id);
    if (mounted) setState(() => _isLiked = !_isLiked);
  }

  // =====================================================
  // 📜 MENÚ DE OPCIONES — incluye reportes y seguridad
  // =====================================================
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
              // 🔗 Copiar enlace
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

              // 🚨 Reportar publicación
              ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                title: const Text('Reportar publicación',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);

                  final reason = await _selectReportReason(context);
                  if (reason == null) return;

                  final alreadyReported =
                      await _reportsService.hasReported(widget.post.id);
                  if (alreadyReported) {
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

              // 🗑️ Eliminar (solo autor)
              if (isAuthor) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.redAccent),
                  title: const Text('Eliminar publicación',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await _confirmDelete(context);
                    if (confirm == true) {
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // 🔸 Diálogo para elegir motivo de reporte
  // =====================================================
  Future<String?> _selectReportReason(BuildContext context) async {
    String? selected;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );
  }

  // =====================================================
  // 🗑️ Confirmación de eliminación
  // =====================================================
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

  // =====================================================
  // 🧩 INTERFAZ PRINCIPAL
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = Colors.white;
    final textSecondary = Colors.white70;
    final colorSurface = theme.colorScheme.surface;

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
            // ================= CABECERA =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.person, color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.authorId,
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold)),
                        Text(
                          '${widget.post.city} • ${_formatDate(widget.post.createdAt.toDate())}',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white54, size: 20),
                    onPressed: () => _showPostOptions(context),
                  ),
                ],
              ),
            ),

            // ================= CONTENIDO =================
            if (widget.post.mediaUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.post.mediaUrls.first,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.sports_soccer,
                      color: Colors.white30, size: 50),
                ),
              ),

            // ================= DESCRIPCIÓN =================
            if (widget.post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.post.caption,
                  style: TextStyle(color: textPrimary, fontSize: 15),
                ),
              ),

            // ================= FOOTER =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isLiked
                                ? Icons.favorite
                                : Icons.favorite_border_outlined,
                            color:
                                _isLiked ? Colors.redAccent : Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StreamBuilder<int>(
                        stream: _likeCountStream,
                        builder: (context, snapshot) {
                          final likes =
                              snapshot.data ?? widget.post.likeCount;
                          return Text('$likes',
                              style: TextStyle(
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
                                    PostDetailPage(post: widget.post)),
                          );
                        },
                        child: const Icon(Icons.comment_outlined,
                            color: Colors.white70, size: 20),
                      ),
                      const SizedBox(width: 6),
                      Text('${widget.post.commentCount}',
                          style: TextStyle(
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

  // ==========================================================
  static String _formatDate(DateTime date) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}