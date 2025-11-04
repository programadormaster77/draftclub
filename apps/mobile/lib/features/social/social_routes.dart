import 'package:go_router/go_router.dart';
import 'presentation/pages/social_feed_page.dart';

/// ===============================================================
/// 🌐 Rutas del módulo Social
/// ===============================================================
/// Define las rutas principales de la sección social de DraftClub.
/// Se integrarán directamente en tu router global (router.dart)
/// ===============================================================
final List<GoRoute> socialRoutes = [
  GoRoute(
    path: '/social',
    name: 'social_feed',
    builder: (context, state) => const SocialFeedPage(),
  ),
];
