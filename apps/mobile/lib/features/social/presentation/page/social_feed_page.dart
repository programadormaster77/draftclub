import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/post.dart';
import '../../../data/repositories/social_repository_impl.dart';
import '../../widgets/post_card.dart';
import '../sheets/create_post_sheet.dart';

/// ===============================================================
/// 📰 SocialFeedPage — Página principal del módulo social
/// ===============================================================
/// - Muestra las publicaciones recientes (foto/video)
/// - Usa el repositorio SocialRepositoryImpl (no accede directo a Firestore)
/// - Integra CreatePostSheet con animación modal
/// - Diseño coherente con theme.dart
/// ===============================================================
class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final _repo = SocialRepositoryImpl();
  String? _currentCity; // Futuro: filtro por ciudad
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ==========================================================
  // 🔹 Método para abrir el modal de creación de post
  // ==========================================================
  Future<void> _openCreatePostSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0E0E0E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: const CreatePostSheet(),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // 🧩 UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0.5,
          title: const Text(
            'Feed Social',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),

        // ===================== STREAM PRINCIPAL =====================
        body: StreamBuilder<List<Post>>(
          stream: _repo.getFeedStream(city: _currentCity),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  '❌ Error al cargar las publicaciones.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return const Center(
                child: Text(
                  '⚽ No hay publicaciones todavía.\nSé el primero en compartir algo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              );
            }

            return RefreshIndicator(
              color: Colors.blueAccent,
              backgroundColor: theme.scaffoldBackgroundColor,
              onRefresh: () async {
                setState(() {}); // Refresca stream
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100, top: 4),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return PostCard(post: post);
                },
              ),
            );
          },
        ),

        // ===================== BOTÓN CREAR POST =====================
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Publicar'),
          onPressed: _openCreatePostSheet,
        ),
      ),
    );
  }
}