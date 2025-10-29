import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';
import 'package:go_router/go_router.dart';

final socialRoutes = [
  GoRoute(
    path: '/social',
    builder: (context, state) => const SocialFeedPage(),
  ),
];
