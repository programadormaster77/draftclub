import 'package:flutter/material.dart';
import '../widgets/locker_category_tile.dart';

/// ============================================================================
/// 🗂️ LockerCategoryPage
/// ============================================================================
/// Pantalla de exploración por categorías.
/// Desde aquí el usuario elige:
/// - Categoría principal
/// - Subcategorías (futuro)
/// - Filtros rápidos
/// ============================================================================

class LockerCategoryPage extends StatelessWidget {
  const LockerCategoryPage({super.key});

  // Lista temporal de categorías principales
  // (más adelante vendrá desde Firestore)
  final List<Map<String, String>> categories = const [
    {"name": "Guayos", "icon": "⚽"},
    {"name": "Camisetas", "icon": "👕"},
    {"name": "Pantalonetas", "icon": "🩳"},
    {"name": "Accesorios", "icon": "🎒"},
    {"name": "Balones", "icon": "🏀"},
    {"name": "Ropa deportiva", "icon": "👟"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: const Text("Categorías"),
        backgroundColor: Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (_, i) {
          final c = categories[i];
          return LockerCategoryTile(
            icon: c["icon"]!,
            title: c["name"]!,
            onTap: () {
              // FUTURO:
              // Navegar a subcategoría o a productos filtrados
              debugPrint("Categoría seleccionada: ${c["name"]}");
            },
          );
        },
      ),
    );
  }
}
