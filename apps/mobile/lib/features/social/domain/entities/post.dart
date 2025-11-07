import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 📰 Post — Entidad principal de publicaciones (Versión PRO++)
/// ============================================================================
/// ✅ Compatible con Firestore (`fromFirestore`)
/// ✅ Incluye `fromMap`, `toMap`, `copyWith`
/// ✅ Manejo seguro de tipos y valores nulos.
/// ✅ Preparado para futuras expansiones (geo, privacidad, tags, etc.)
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

  // ===========================================================================
  // 🔹 Constructor base
  // ===========================================================================
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

  // ===========================================================================
  // 🔹 Constructor desde Map (el más utilizado)
  // ===========================================================================
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
      createdAt: data['createdAt'] ?? Timestamp.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      visibility: data['visibility'] ?? 'public',
      city: data['city'] ?? '',
      cityLat: (data['cityLat'] as num?)?.toDouble(),
      cityLng: (data['cityLng'] as num?)?.toDouble(),
      countryCode: data['countryCode'],
      deleted: (data['deleted'] ?? false) == true,
    );
  }

  // ===========================================================================
  // 🔹 Constructor desde DocumentSnapshot (para compatibilidad directa)
  // ===========================================================================
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Post.fromMap(data, doc.id);
  }

  // ===========================================================================
  // 🔹 Convierte el Post a un Map (para guardar en Firestore)
  // ===========================================================================
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

  // ===========================================================================
  // 🔹 Copia el Post modificando solo ciertos campos
  // ===========================================================================
  Post copyWith({
    String? id,
    String? authorId,
    String? type,
    List<String>? mediaUrls,
    String? thumbUrl,
    double? aspectRatio,
    String? caption,
    List<String>? tags,
    List<String>? mentions,
    Timestamp? createdAt,
    int? likeCount,
    int? commentCount,
    String? visibility,
    String? city,
    double? cityLat,
    double? cityLng,
    String? countryCode,
    bool? deleted,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      mentions: mentions ?? this.mentions,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      visibility: visibility ?? this.visibility,
      city: city ?? this.city,
      cityLat: cityLat ?? this.cityLat,
      cityLng: cityLng ?? this.cityLng,
      countryCode: countryCode ?? this.countryCode,
      deleted: deleted ?? this.deleted,
    );
  }

  // ===========================================================================
  // 🔹 Representación legible (para depuración)
  // ===========================================================================
  @override
  String toString() {
    return 'Post(id: $id, authorId: $authorId, caption: $caption, mediaUrls: ${mediaUrls.length}, likes: $likeCount, comments: $commentCount)';
  }
}
