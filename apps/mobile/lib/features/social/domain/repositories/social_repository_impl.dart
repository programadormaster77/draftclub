import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';

class SocialRepositoryImpl implements SocialRepository {
  final _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<Post>> getFeedStream({String? city}) {
    var query = _firestore
        .collection('posts')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Post.fromMap(doc.data(), doc.id)).toList());
  }

  @override
  Future<void> createPost(Post post) async {
    await _firestore.collection('posts').doc(post.id).set(post.toMap());
  }
}
