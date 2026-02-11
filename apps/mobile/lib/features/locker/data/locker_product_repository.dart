import 'package:cloud_firestore/cloud_firestore.dart';
import 'locker_product_model.dart';

/// ============================================================================
/// 🏛️ LockerProductRepository
/// ============================================================================
/// Se encarga de TODA la comunicación con Firestore:
/// - Crear, obtener, editar y eliminar productos del Locker.
/// - Consultas con filtros por categoría, subcategoría, género, talla.
/// - Consultas por ciudad.
/// - Búsqueda por keywords.
/// - Productos destacados / patrocinados.
/// - Popularidad / ranking básico (sin IA).
///
/// Colección utilizada:
///   productsLocker/{productId}
/// ============================================================================

class LockerProductRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Nombre de la colección en Firestore
  static const String collectionName = 'productsLocker';

  /// Referencia a la colección
  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(collectionName);

  // ==========================================================================
  // 🟩 Crear producto
  // ==========================================================================
  Future<String> createProduct(LockerProductModel product) async {
    final doc = _ref.doc(); // crea ID nuevo

    await doc.set(
      product.toMap()..addAll({'id': doc.id}), // inserta el ID aquí
    );

    return doc.id;
  }

  // ==========================================================================
  // 🟦 Actualizar producto existente
  // ==========================================================================
  Future<void> updateProduct(
      String productId, Map<String, dynamic> data) async {
    await _ref.doc(productId).update(data);
  }

  // ==========================================================================
  // 🟥 Eliminar producto (solo Admin o VIP con permisos)
  // ==========================================================================
  Future<void> deleteProduct(String productId) async {
    await _ref.doc(productId).delete();
  }

  // ==========================================================================
  // 🟨 Obtener un producto por ID
  // ==========================================================================
  Future<LockerProductModel?> getById(String productId) async {
    final doc = await _ref.doc(productId).get();
    if (!doc.exists) return null;
    return LockerProductModel.fromFirestore(doc);
  }

  // ==========================================================================
  // 🟪 LISTADO GENERAL (con filtros simples)
  // ==========================================================================
  Stream<List<LockerProductModel>> getAllVisibleProducts() {
    return _ref
        .where('visibility', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => LockerProductModel.fromFirestore(doc))
              .toList(),
        );
  }

  // ==========================================================================
  // 🔍 Filtrar por categoría principal
  // ==========================================================================
  Stream<List<LockerProductModel>> getByMainCategory(String category) {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('mainCategory', isEqualTo: category)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 🔍 Filtrar por subcategoría
  // ==========================================================================
  Stream<List<LockerProductModel>> getBySubCategory(String subCat) {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('subCategory', isEqualTo: subCat)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 🏷️ Filtrar por género
  // ==========================================================================
  Stream<List<LockerProductModel>> getByGender(String gender) {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('gender', isEqualTo: gender)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 📏 Filtrar por talla
  // ==========================================================================
  Stream<List<LockerProductModel>> getBySize(String size) {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('size', isEqualTo: size)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 🌍 Filtrar por ubicación (ciudad o "Global")
  // ==========================================================================
  Stream<List<LockerProductModel>> getByLocation(String location) {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('location', isEqualTo: location)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // ⭐ Productos destacados (admin)
  // ==========================================================================
  Stream<List<LockerProductModel>> getFeatured() {
    return _ref
        .where('visibility', isEqualTo: true)
        .where('featured', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 📈 Productos más populares
  // ==========================================================================
  Stream<List<LockerProductModel>> getPopular() {
    return _ref
        .where('visibility', isEqualTo: true)
        .orderBy('popularity', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 🔍 Búsqueda por keywords
  // ==========================================================================
  Stream<List<LockerProductModel>> searchProducts(String query) {
    final normalized = query.trim().toLowerCase();

    return _ref
        .where('visibility', isEqualTo: true)
        .where('searchKeywords', arrayContains: normalized)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LockerProductModel.fromFirestore(doc))
            .toList());
  }

  // ==========================================================================
  // 🔄 Incrementar popularidad (cada clic / view / addToCart)
  // ==========================================================================
  Future<void> incrementPopularity(String productId, {int amount = 1}) async {
    await _ref.doc(productId).update({
      'popularity': FieldValue.increment(amount),
      'updatedAt': Timestamp.now(),
    });
  }

  // ==========================================================================
  // 🎯 Actualizar boostScore (para adminBoost o campañas)
  // ==========================================================================
  Future<void> updateBoostScore(String productId, double score) async {
    await _ref.doc(productId).update({
      'boostScore': score,
      'updatedAt': Timestamp.now(),
    });
  }
}
