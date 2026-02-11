// lib/app/router.dart

// 📦 Importaciones principales
import 'package:go_router/go_router.dart';

// ============ AUTH ============
import 'package:draftclub_mobile/features/auth/presentation/auth_page.dart';

// ============ PROFILE ============
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';
import 'package:draftclub_mobile/features/profile/presentation/edit_profile_page.dart';

// ============ SOCIAL ============
import 'package:draftclub_mobile/features/social/domain/entities/post.dart';
import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_list_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/follow_list_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/post_detail_page.dart';

// ============ NOTIFICACIONES ============

// ============ LOCKER ============
// ⚠️ IMPORTANTE: ajusta estas rutas según la ubicación REAL de tus archivos.
// Abre `locker_page.dart` en VSCode, haz clic derecho en el nombre del archivo
// → "Copy Relative Path" y úsalo aquí si es diferente.

/// ===============================================================
/// 🌐 Configuración global de GoRouter
/// ===============================================================

final GoRouter router = GoRouter(
  debugLogDiagnostics: true,
  // 👇 Pantalla inicial de la app:
  initialLocation: '/social',
  routes: [
    // ===================== AUTH =====================
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) => const AuthPage(),
    ),

    // ===================== HOME / SOCIAL FEED =====================
    GoRoute(
      path: '/social',
      name: 'social_feed',
      builder: (context, state) => const SocialFeedPage(),
    ),

    // ===================== PERFIL =====================
    GoRoute(
      path: '/profile/:uid',
      name: 'profile',
      builder: (context, state) {
        final uid = state.pathParameters['uid'];
        return ProfilePage(userId: uid);
      },
    ),

    // Editar perfil (usa el usuario actual)
    GoRoute(
      path: '/profile/edit',
      name: 'edit_profile',
      builder: (context, state) => const EditProfilePage(),
    ),

    // ===================== SEGUIDORES / SIGUIENDO =====================
    GoRoute(
      path: '/follow/:uid/:mode',
      name: 'follow_list',
      builder: (context, state) {
        final uid = state.pathParameters['uid']!;
        final mode = state.pathParameters['mode'] ?? 'followers';
        final showFollowers = mode == 'followers';

        return FollowListPage(
          userId: uid,
          showFollowers: showFollowers,
        );
      },
    ),

    // ===================== DETALLE DEL POST =====================
    GoRoute(
      path: '/post/:id',
      name: 'post_detail',
      builder: (context, state) {
        // 👇 Aquí usamos el Post que pasas en state.extra
        final post = state.extra as Post;
        return PostDetailPage(post: post);
      },
    ),

    // ===================== MENSAJES (LISTA DE CHATS) =====================
    GoRoute(
      path: '/chat',
      name: 'chat_list',
      builder: (context, state) => const ChatListPage(),
    ),

    // ===================== CHAT INDIVIDUAL =====================
    GoRoute(
      path: '/chat/:chatId',
      name: 'chat',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId']!;

        // Extra opcional con info del otro usuario
        String otherUserId = '';
        String otherName = 'Jugador';
        String otherPhoto = '';

        final extra = state.extra;
        if (extra is Map) {
          otherUserId = (extra['otherUserId'] ?? '') as String;
          otherName = (extra['otherName'] ?? 'Jugador') as String;
          otherPhoto = (extra['otherPhoto'] ?? '') as String;
        }

        return ChatPage(
          chatId: chatId,
          otherUserId: otherUserId,
          otherName: otherName,
          otherPhoto: otherPhoto,
        );
      },
    ),
  ],
);
