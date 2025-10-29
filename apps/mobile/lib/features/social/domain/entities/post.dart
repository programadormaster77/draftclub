import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String type; // photo | video
  final List<String> mediaUrls;
  final String? thumbUrl;
  final double? aspectRatio;
  final String caption;
  final List<String> tags;
  final List<String> mentions;
  final Timestamp createdAt;
  final int likeCount;
  final int commentCount;
  final String visibility; // public | friends | privateFuture
  final String city;
  final double? cityLat;
  final double? cityLng;
  final String? countryCode;
  final bool deleted;

  Post({
    required this.id,
    required this.authorId,
    required this.type,
    required this.mediaUrls,
    this.thumbUrl,
    this.aspectRatio,
    required this.caption,
    this.tags = const [],
    this.mentions = const [],
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.visibility = 'public',
    required this.city,
    this.cityLat,
    this.cityLng,
    this.countryCode,
    this.deleted = false,
  });

  factory Post.fromMap(Map<String, dynamic> data, String id) {
    return Post(
      id: id,
      authorId: data['authorId'] ?? '',
      type: data['type'] ?? 'photo',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      thumbUrl: data['thumbUrl'],
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble(),
      caption: data['caption'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      mentions: List<String>.from(data['mentions'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      visibility: data['visibility'] ?? 'public',
      city: data['city'] ?? '',
      cityLat: (data['cityLat'] as num?)?.toDouble(),
      cityLng: (data['cityLng'] as num?)?.toDouble(),
      countryCode: data['countryCode'],
      deleted: data['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'type': type,
      'mediaUrls': mediaUrls,
      'thumbUrl': thumbUrl,
      'aspectRatio': aspectRatio,
      'caption': caption,
      'tags': tags,
      'mentions': mentions,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'visibility': visibility,
      'city': city,
      'cityLat': cityLat,
      'cityLng': cityLng,
      'countryCode': countryCode,
      'deleted': deleted,
    };
  }
}
