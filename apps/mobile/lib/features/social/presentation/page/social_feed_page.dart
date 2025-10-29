import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/post.dart';
import '../widgets/post_card.dart';

class SocialFeedPage extends StatelessWidget {
  const SocialFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final postsRef = FirebaseFirestore.instance
        .collection('posts')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Feed Social'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: postsRef,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!.docs
              .map((d) => Post.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => PostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}
