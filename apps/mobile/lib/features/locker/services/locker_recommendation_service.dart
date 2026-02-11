import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/locker_product_model.dart';
import 'locker_service.dart';

/// ============================================================================
/// 🤖 LockerRecommendationService
/// ============================================================================
/// Sistema de "feed inteligente" del Locker.
/// Mezcla:
/// - 75% contenido personalizado
/// - 25% exploración (descubrimiento)
/// - AdminBoost multiplicado (2.0x)
///
/// Calcula un "relevanceScore" basado en:
/// - Intereses del usuario (categorías, subcategorías)
/// - Ciudad / ubicación
/// - Histórico de vistas o clics
/// - Popularidad global
/// - Productos destacados
/// - AdminBoost
///
/// El resultado final es una lista ordenada por relevancia.
/// ============================================================================

class LockerRecommendationService {
  final LockerService _lockerService = LockerService();

  /// Porcentajes establecidos por ti
  static const double personalizedRatio = 0.75;
  static const double exploreRatio = 0.25;

  /// Boost de administrador (te asegura prioridad)
  static const double adminBoost = 2.0;

  /// ========================================================================
  /// 🎯 Obtener feed inteligente para un usuario
  /// ========================================================================
  Future<List<LockerProductModel>> getRecommendedProducts({
    required String uid,
    required String userCity,
    required List<String> likedCategories, // Ej: ['guayos', 'camisetas']
    required List<String> viewedSubcategories, // histórico: ['sudaderas']
  }) async {
    // Paso 1: traer los productos recientes del Locker
    final recentProductsStream = _lockerService.getFeaturedAndRecent();
    final recentProducts = await recentProductsStream.first;

    // Paso 2: crear una lista con "scores" asignados
    List<_RankedProduct> ranked = [];

    for (final p in recentProducts) {
      double score = 0;

      // ================================================================
      // 🟦 1. Coincidencia por categoría principal → peso fuerte
      // ================================================================
      if (likedCategories.contains(p.mainCategory)) {
        score += 40;
      }

      // ================================================================
      // 🟨 2. Coincidencia por subcategoría → peso medio
      // ================================================================
      if (viewedSubcategories.contains(p.subCategory)) {
        score += 25;
      }

      // ================================================================
      // 🟪 3. Coincidencia por ciudad (local > global)
      // ================================================================
      if (p.location == userCity) {
        score += 30;
      } else if (p.location == 'Global') {
        score += 10;
      }

      // ================================================================
      // ⭐ 4. Featured (Admin los marca)
      // ================================================================
      if (p.featured) {
        score += 30;
      }

      // ================================================================
      // 📈 5. Popularidad global
      // ================================================================
      score += min(p.popularity / 5, 25); // máx 25 puntos

      // ================================================================
      // 🔥 6. AdminBoost (2.0x dicho por ti)
      // ================================================================
      if (p.ownerRole == 'admin') {
        score *= adminBoost;
      }

      // ================================================================
      // 🧮 7. Aleatoriedad controlada para diversidad
      // ================================================================
      score += Random().nextDouble() * 5; // ruido leve

      ranked.add(_RankedProduct(product: p, score: score));
    }

    // ================================================================
    // 🧾 Ordenar por score (descendente)
    // ================================================================
    ranked.sort((a, b) => b.score.compareTo(a.score));

    // ================================================================
    // 🎯 División 75% personalizado / 25% exploración
    // ================================================================
    final total = ranked.length;

    final personalizedCount = (total * personalizedRatio).round();
    final exploreCount = (total * exploreRatio).round();

    final personalized = ranked.take(personalizedCount).toList();
    final explore = ranked.skip(personalizedCount).take(exploreCount).toList();

    // Mezcla final: primero personalizado, luego descubrimiento
    final result = [...personalized, ...explore].map((r) => r.product).toList();

    return result;
  }
}

/// ============================================================================
/// 📦 Clase interna para manejar score+producto
/// ============================================================================
class _RankedProduct {
  final LockerProductModel product;
  final double score;

  _RankedProduct({required this.product, required this.score});
}
