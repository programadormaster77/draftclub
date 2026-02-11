import 'package:flutter/material.dart';
import '../pages/locker_search_page.dart';

/// ============================================================================
/// 🔍 LockerSearchBar
/// ============================================================================
/// Barra compacta de búsqueda que aparece en la parte superior del Locker.
/// Cuando el usuario toca, redirige a LockerSearchPage.
/// ============================================================================
class LockerSearchBar extends StatelessWidget {
  const LockerSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LockerSearchPage(),
          ),
        );
      },
      child: Container(
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: Colors.white38, size: 20),
            SizedBox(width: 10),
            Text(
              "Buscar productos…",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
