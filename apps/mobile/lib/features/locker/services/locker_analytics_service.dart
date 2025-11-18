import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 📊 LockerAnalyticsService
/// ============================================================================
/// Registra eventos y métricas internas del módulo Locker.
///
/// Eventos incluidos:
/// - viewProduct(productId)
/// - search(query)
/// - useFilter(category)
/// - addToCart(productId)
///
/// Más adelante se integrará BigQuery o un dashboard interno.
/// ============================================================================

class LockerAnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Registrar vista de producto
  Future<void> logProductView(String productId) async {
    await _db.collection("locker_analytics").add({
      "event": "product_view",
      "productId": productId,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// Registrar búsqueda
  Future<void> logSearch(String query) async {
    await _db.collection("locker_analytics").add({
      "event": "search",
      "query": query,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// Registrar filtro aplicado
  Future<void> logFilter(String category) async {
    await _db.collection("locker_analytics").add({
      "event": "filter",
      "category": category,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// Registrar que se añadió un producto al carrito
  Future<void> logAddToCart(String productId) async {
    await _db.collection("locker_analytics").add({
      "event": "add_to_cart",
      "productId": productId,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
}
