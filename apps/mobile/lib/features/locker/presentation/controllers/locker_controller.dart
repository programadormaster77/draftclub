import 'package:flutter/material.dart';
import '../../data/locker_product_model.dart';
import '../../services/locker_service.dart';
import '../../services/locker_recommendation_service.dart';

/// ============================================================================
/// 🧠 LockerController — Controlador principal del módulo Locker
/// ============================================================================
class LockerController extends ChangeNotifier {
  final LockerService _lockerService = LockerService();
  final LockerRecommendationService _recommendationService =
      LockerRecommendationService();

  // Estado principal
  List<LockerProductModel> products = [];
  String? selectedCategory;
  bool isLoading = false;
  String? errorMessage;

  /// Inicialización
  Future<void> init() async {
    await loadProducts();
  }

  /// ==========================================================================
  /// 🔄 Cargar productos (con recomendación incluida)
  /// ==========================================================================
  Future<void> loadProducts() async {
    try {
      isLoading = true;
      notifyListeners();

      // ----------------------------------------------------------------------
      // PARAMETROS POR DEFECTO — TEMPORALES HASTA QUE CONECTEMOS PERFIL REAL
      // ----------------------------------------------------------------------

      const String defaultCity = 'Bogotá';

      final List<String> defaultLikedCategories = [
        'guayos',
        'camisetas',
        'sudaderas',
        'accesorios',
      ];

      final List<String> defaultViewedSubcategories = [
        'nike',
        'adidas',
        'puma',
      ];

      // ----------------------------------------------------------------------
      // 🚀 Obtener recomendados (YA SIN ERRORES)
      // ----------------------------------------------------------------------
      final recommended = await _recommendationService.getRecommendedProducts(
        uid: 'admin-0001', // temporal
        userCity: defaultCity, // nuevo requerido
        likedCategories: defaultLikedCategories,
        viewedSubcategories: defaultViewedSubcategories,
      );

      // ----------------------------------------------------------------------
      // 📦 Obtener productos generales (stream → list una sola vez)
      // ----------------------------------------------------------------------
      final allProducts = await _lockerService.getFeaturedAndRecent().first;

      // ----------------------------------------------------------------------
      // 🧪 Mezclar 75% recomendado con 25% exploración
      // ----------------------------------------------------------------------
      products = _mixRecommendedAndExploration(
        recommended,
        allProducts,
        ratio: 0.75,
      );

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// ==========================================================================
  /// 🔁 Filtrar por categoría
  /// ==========================================================================
  Future<void> setCategory(String? category) async {
    selectedCategory = category;
    isLoading = true;
    notifyListeners();

    try {
      if (category == null) {
        await loadProducts();
      } else {
        // getFilteredProducts es STREAM → usamos first para obtener LISTA
        products = await _lockerService
            .getFilteredProducts(mainCategory: category)
            .first;
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  /// ==========================================================================
  /// 🔄 Refrescar
  /// ==========================================================================
  Future<void> refresh() async {
    await loadProducts();
  }

  /// ==========================================================================
  /// 🧪 Mezcla inteligente recomendado + exploración
  /// ==========================================================================
  List<LockerProductModel> _mixRecommendedAndExploration(
    List<LockerProductModel> recommended,
    List<LockerProductModel> general, {
    double ratio = 0.75,
  }) {
    if (general.isEmpty) return recommended;

    final int recommendedCount =
        (recommended.length * ratio).round().clamp(0, recommended.length);

    final int explorationCount =
        (general.length * (1 - ratio)).round().clamp(0, general.length);

    final List<LockerProductModel> mix = [];

    mix.addAll(recommended.take(recommendedCount));
    mix.addAll(general.take(explorationCount));

    final unique = mix.toSet().toList()..shuffle();

    return unique;
  }
}
