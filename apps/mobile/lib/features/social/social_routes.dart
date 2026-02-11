import 'package:go_router/go_router.dart';

// FEED
import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';

// CHATS
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

  // 💭 CHAT INDIVIDUAL (4 parámetros obligatorios)
  GoRoute(
    path: '/chat/:chatId/:otherUserId/:otherName/:otherPhoto',
    name: 'chat_page',
    builder: (context, state) {
      final chatId = state.pathParameters['chatId']!;
      final otherUserId = state.pathParameters['otherUserId']!;
      final otherName = state.pathParameters['otherName']!;
      final otherPhoto = state.pathParameters['otherPhoto']!;

      return ChatPage(
        chatId: chatId,
        otherUserId: otherUserId,
        otherName: otherName,
        otherPhoto: otherPhoto,
      );
    },
  ),
];
