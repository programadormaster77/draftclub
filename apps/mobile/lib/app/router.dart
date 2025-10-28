import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/feed/presentation/feed_page.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/feed',
      builder: (context, state) => const FeedPage(),
    ),
  ],
);
