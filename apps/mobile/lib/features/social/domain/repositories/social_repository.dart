import '../entities/post.dart';

abstract class SocialRepository {
  Stream<List<Post>> getFeedStream({String? city});
  Future<void> createPost(Post post);
}
