import 'package:go_router/go_router.dart';
import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';

// ⬇️ IMPORTA AQUÍ TUS PÁGINAS DE CHAT
import 'package:draftclub_mobile/features/social/presentation/page/chat_list_page.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_page.dart';

/// ===============================================================
/// 🌐 Rutas del módulo Social + Mensajería
/// ===============================================================
final List<GoRoute> socialRoutes = [

  // 📰 FEED SOCIAL
  GoRoute(
    path: '/social',
    name: 'social_feed',
    builder: (context, state) => const SocialFeedPage(),
  ),

  // 💬 LISTA DE CHATS
  GoRoute(
    path: '/chat',
    name: 'chat_list',
    builder: (context, state) => const ChatListPage(),
  ),

  // 💭 CHAT INDIVIDUAL
  GoRoute(
    path: '/chat/:userId',
    name: 'chat_page',
    builder: (context, state) {
      final userId = state.pathParameters['userId']!;
      return ChatPage(userId: userId);
    },
  ),
];
