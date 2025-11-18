import 'package:flutter/material.dart';

/// ============================================================================
/// 🧩 LockerCategoryFilterBar
/// ============================================================================
/// Barra horizontal de categorías.
/// Se usa en LockerPage para filtrar productos por categoría principal.
///
/// NOTA:
/// Este widget es totalmente UI. La lógica de filtrado se maneja desde afuera:
///
/// - onCategorySelected(String?)
/// - categorySelected (estado actual)
///
/// Esto permite integrarlo con un Controller (Riverpod/PVN) después.
/// ============================================================================

class LockerCategoryFilterBar extends StatelessWidget {
  final String? selectedCategory;
  final Function(String? category) onCategorySelected;

  const LockerCategoryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  /// 🔥 Categorías principales recomendadas para DraftClub
  List<String> get categories => const [
        'Guayos',
        'Balones',
        'Camisetas',
        'Conjuntos',
        'Sudaderas',
        'Accesorios',
        'Fitness',
        'Porteros',
        'Equipos',
        'Mujer',
        'Hombre',
        'Unisex',
        'Ofertas',
      ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildChip(
            label: "Todo",
            isSelected: selectedCategory == null,
            onTap: () => onCategorySelected(null),
          ),
          const SizedBox(width: 8),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                label: c,
                isSelected: selectedCategory == c,
                onTap: () => onCategorySelected(c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🎨 CHIP PERSONALIZADO
  // ===========================================================================
  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white10,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 0),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
