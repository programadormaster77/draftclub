import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧩 Post — Modelo robusto de publicación (versión corregida v2.2)
/// ============================================================================
/// ✅ Compatible con campos opcionales o ausentes.
/// ✅ Evita fallos si falta `deleted` o `city`.
/// ✅ Compatible con `authorId` como campo de referencia.
/// ============================================================================
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
  final String visibility; // public | friends | private
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
    this.city = '',
    this.cityLat,
    this.cityLng,
    this.countryCode,
    this.deleted = false,
  });

  /// 🧭 Constructor desde Firestore (seguro)
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Post.fromMap(data, doc.id);
  }

  /// 🧩 Constructor desde Map (normalizado)
  factory Post.fromMap(Map<String, dynamic> data, String id) {
    return Post(
      id: id,
      authorId: data['authorId'] ?? data['userId'] ?? '',
      type: data['type'] ?? 'photo',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      thumbUrl: data['thumbUrl'],
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble(),
      caption: data['caption'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      mentions: List<String>.from(data['mentions'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt']
          : Timestamp.now(),
      likeCount: (data['likeCount'] ?? 0) is int
          ? data['likeCount']
          : int.tryParse(data['likeCount'].toString()) ?? 0,
      commentCount: (data['commentCount'] ?? 0) is int
          ? data['commentCount']
          : int.tryParse(data['commentCount'].toString()) ?? 0,
      visibility: data['visibility'] ?? 'public',
      city: data['city'] ?? '',
      cityLat: (data['cityLat'] as num?)?.toDouble(),
      cityLng: (data['cityLng'] as num?)?.toDouble(),
      countryCode: data['countryCode'],
      deleted: (data['deleted'] ?? false) == true,
    );
  }

  /// 🧾 Conversión a Map para subir a Firestore
  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'type': type,
      'mediaUrls': mediaUrls,
      if (thumbUrl != null) 'thumbUrl': thumbUrl,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
      'caption': caption,
      'tags': tags,
      'mentions': mentions,
      'createdAt': createdAt,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'visibility': visibility,
      'city': city,
      if (cityLat != null) 'cityLat': cityLat,
      if (cityLng != null) 'cityLng': cityLng,
      if (countryCode != null) 'countryCode': countryCode,
      'deleted': deleted,
    };
  }
}
