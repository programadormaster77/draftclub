import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧱 LockerProductModel — Modelo principal de producto (con cityData)
/// ============================================================================
class LockerProductModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;

  /// 🖼 URLs de imágenes
  final List<String> images;

  /// 🗂️ Categorías
  final String mainCategory;
  final String subCategory;

  /// 🚻 Género
  final String gender;

  /// 📏 Talla
  final String size;

  /// 🏪 Tipo de tienda
  final String storeType;

  /// 📍 Ubicación (ciudad) - cadena legible
  final String location;

  /// 🗺️ Información detallada de la ciudad (mapa), puede ser null
  /// Ejemplo guardado:
  /// {
  ///   "name": "Bogotá, Colombia",
  ///   "placeId": "ChIJKcumLf2bP44RFDmjIFVjnSM",
  ///   "lat": 4.710988599999999,
  ///   "lng": -74.072092,
  ///   "ciudad": "Bogota"
  /// }
  final Map<String, dynamic>? cityData;

  /// 🔗 Tipo de producto (local | external)
  final String type;
  final String? externalLink;

  /// 🏷️ Tags
  final List<String> tags;

  /// 🔍 Keywords de búsqueda
  final List<String> searchKeywords;

  /// 📦 Stock
  final int stock;

  /// 👁️ Visibilidad interna
  final bool visibility;

  /// ⭐ Destacado
  final bool featured;

  /// 📊 Popularidad acumulada
  final int popularity;

  /// 🚀 Valor para boosts (admin)
  final double boostScore;

  /// 👤 Propietario
  final String ownerUid;
  final String ownerRole;

  /// 🕒 Fechas
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 💰 Producto patrocinado
  final bool isSponsored;

  const LockerProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.images,
    required this.mainCategory,
    required this.subCategory,
    required this.gender,
    required this.size,
    required this.storeType,
    required this.location,
    required this.cityData,
    required this.type,
    required this.externalLink,
    required this.tags,
    required this.searchKeywords,
    required this.stock,
    required this.visibility,
    required this.featured,
    required this.popularity,
    required this.boostScore,
    required this.ownerUid,
    required this.ownerRole,
    required this.createdAt,
    required this.updatedAt,
    required this.isSponsored,
  });

  /// ========================================================================
  /// 🔁 From Firestore
  /// ========================================================================
  factory LockerProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    List<String> safeList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, dynamic>? safeMap(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    return LockerProductModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'COP',
      images: safeList(data['images']),
      mainCategory: data['mainCategory'] ?? '',
      subCategory: data['subCategory'] ?? '',
      gender: data['gender'] ?? 'unisex',
      size: data['size'] ?? '',
      storeType: data['storeType'] ?? 'ninguna',
      location: data['location'] ?? 'Global',
      cityData: safeMap(data['cityData']),
      type: data['type'] ?? 'local',
      externalLink: data['externalLink'],
      tags: safeList(data['tags']),
      searchKeywords: safeList(data['searchKeywords']),
      stock: (data['stock'] ?? 0) is int
          ? data['stock']
          : int.tryParse(data['stock'].toString()) ?? 0,
      visibility: data['visibility'] ?? true,
      featured: data['featured'] ?? false,
      popularity: data['popularity'] ?? 0,
      boostScore: (data['boostScore'] ?? 1.0).toDouble(),
      ownerUid: data['ownerUid'] ?? '',
      ownerRole: data['ownerRole'] ?? 'user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSponsored: data['isSponsored'] ?? false,
    );
  }

  /// ========================================================================
  /// 📦 toMap
  /// ========================================================================
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'images': images,
      'mainCategory': mainCategory,
      'subCategory': subCategory,
      'gender': gender,
      'size': size,
      'storeType': storeType,
      'location': location,
      'cityData': cityData,
      'type': type,
      'externalLink': externalLink,
      'tags': tags,
      'searchKeywords': searchKeywords,
      'stock': stock,
      'visibility': visibility,
      'featured': featured,
      'popularity': popularity,
      'boostScore': boostScore,
      'ownerUid': ownerUid,
      'ownerRole': ownerRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isSponsored': isSponsored,
    };
  }

  /// ========================================================================
  /// 🔍 buildSearchKeywords (helper)
  /// ========================================================================
  static List<String> buildSearchKeywords({
    required String title,
    required String mainCategory,
    required String subCategory,
    List<String> extraTags = const [],
  }) {
    final list = [
      title,
      mainCategory,
      subCategory,
      ...extraTags,
    ];

    return list
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.toLowerCase())
        .toSet()
        .toList();
  }
}
