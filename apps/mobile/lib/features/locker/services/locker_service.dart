import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/locker_product_model.dart';
import '../data/locker_product_repository.dart';

/// ============================================================================
/// ⚙️ LockerService — Lógica principal de negocio del Locker
/// ============================================================================
/// Este servicio:
/// - Junta streams de productos destacados + recientes.
/// - Maneja filtros (categoría, subcategoría, género, talla, ubicación).
/// - Maneja búsquedas por keywords.
/// - Maneja popularidad, boostScore, carrito y CRUD.
///
/// IMPORTANTE:
/// Aquí agregamos el método faltante:
///     🔥 getProductById()
/// que es necesario para las rutas de detalle y edición.
/// ============================================================================

class LockerService {
  final LockerProductRepository _repo = LockerProductRepository();

  // ==========================================================================
  // ⭐ Obtener productos destacados + recientes (home del Locker)
  // ==========================================================================
  Stream<List<LockerProductModel>> getFeaturedAndRecent() async* {
    final featuredStream = _repo.getFeatured();
    final recentStream = _repo.getAllVisibleProducts();

    await for (final featured in featuredStream) {
      final recent = await recentStream.first;

      final combined = [
        ...featured,
        ...recent.where((p) => !featured.any((f) => f.id == p.id)),
      ];

      yield combined;
    }
  }

  // ==========================================================================
  // 🎯 Obtener productos por filtros múltiples
  // ==========================================================================
  Stream<List<LockerProductModel>> getFilteredProducts({
    String? mainCategory,
    String? subCategory,
    String? gender,
    String? size,
    String? location,
  }) {
    final baseStream = _repo.getAllVisibleProducts();

    return baseStream.map((products) {
      var filtered = products;

      if (mainCategory != null && mainCategory.isNotEmpty) {
        filtered =
            filtered.where((p) => p.mainCategory == mainCategory).toList();
      }

      if (subCategory != null && subCategory.isNotEmpty) {
        filtered = filtered.where((p) => p.subCategory == subCategory).toList();
      }

      if (gender != null && gender.isNotEmpty) {
        filtered = filtered.where((p) => p.gender == gender).toList();
      }

      if (size != null && size.isNotEmpty) {
        filtered = filtered.where((p) => p.size == size).toList();
      }

      if (location != null && location.isNotEmpty) {
        filtered = filtered.where((p) => p.location == location).toList();
      }

      return filtered;
    });
  }

  // ==========================================================================
  // 🔍 Búsqueda por texto (keywords)
  // ==========================================================================
  Stream<List<LockerProductModel>> searchProducts(String query) {
    return _repo.searchProducts(query);
  }

  // ==========================================================================
  // 🧺 Obtener lista de productos por IDs (carrito)
  // ==========================================================================
  Future<List<LockerProductModel>> getProductsByIds(List<String> ids) async {
    List<LockerProductModel> products = [];

    for (final id in ids) {
      final p = await _repo.getById(id);
      if (p != null) {
        products.add(p);
      }
    }

    return products;
  }

  // ==========================================================================
  // 🔥 **MÉTODO NUEVO Y OBLIGATORIO**
  // 🔍 Obtener producto por ID (para detalle y edición)
  // ==========================================================================
  Future<LockerProductModel> getProductById(String id) async {
    final result = await _repo.getById(id);

    if (result == null) {
      throw Exception("El producto con ID $id no existe en Firestore.");
    }

    return result;
  }

  // ==========================================================================
  // 🔁 Incrementar popularidad
  // ==========================================================================
  Future<void> increasePopularity(String productId, {int amount = 1}) async {
    await _repo.incrementPopularity(productId, amount: amount);
  }

  // ==========================================================================
  // 🎚️ Actualizar boostScore
  // ==========================================================================
  Future<void> setBoostScore(String productId, double score) async {
    await _repo.updateBoostScore(productId, score);
  }

  // ==========================================================================
  // 📦 Crear producto completo
  // ==========================================================================
  Future<String> createFullProduct(LockerProductModel product) async {
    return await _repo.createProduct(product);
  }

  // ==========================================================================
  // 📝 Editar producto
  // ==========================================================================
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _repo.updateProduct(id, data);
  }

  // ==========================================================================
  // ❌ Eliminar producto
  // ==========================================================================
  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
  }
}
