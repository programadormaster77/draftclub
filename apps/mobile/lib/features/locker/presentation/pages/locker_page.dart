import 'package:flutter/material.dart';

// 📌 Páginas a navegar con MaterialRoute
import '../pages/locker_cart_page.dart';
import '../../admin/locker_admin_page.dart';

// 📌 Controladores y widgets
import '../controllers/locker_controller.dart';
import '../widgets/locker_category_filter_bar.dart';
import '../widgets/locker_search_bar.dart';
import '../widgets/locker_product_card.dart';

// 📌 Modelos
import '../../data/locker_product_model.dart';

/// ============================================================================
/// 🏬 LockerPage — Página principal del Marketplace Locker
/// ============================================================================
class LockerPage extends StatefulWidget {
  const LockerPage({super.key});

  @override
  State<LockerPage> createState() => _LockerPageState();
}

class _LockerPageState extends State<LockerPage> {
  final LockerController controller = LockerController();

  @override
  void initState() {
    super.initState();
    controller.init();
    controller.addListener(_refresh);
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double _calculateAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // 🔥 Cada tarjeta tendrá el ancho menos márgenes del grid
    final cardWidth = (width - 14 * 3) / 2;

    // 🔥 Calculamos la altura REAL aproximada de tu tarjeta
    // Imagen (proporción 1:1) → igual al ancho
    // Espacio debajo: tags + título + precio + ciudad + padding
    const extraHeight = 110;

    final cardHeight = cardWidth + extraHeight;

    return cardWidth / cardHeight;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = controller.isLoading;
    final category = controller.selectedCategory;
    final products = controller.products;
    final error = controller.errorMessage;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // =========================================================================
      // 🧭 APPBAR SUPERIOR
      // =========================================================================
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Locker',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // 🛒 Icono carrito
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LockerCartPage()),
              );
            },
          ),

          // 🛠️ Icono admin
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LockerAdminPage()),
              );
            },
          ),
        ],
      ),

      // =========================================================================
      // BODY
      // =========================================================================
      body: RefreshIndicator(
        backgroundColor: Colors.black,
        color: Colors.blueAccent,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            // 🔍 Barra de búsqueda
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 14, bottom: 6),
                child: LockerSearchBar(),
              ),
            ),

            // 🏷️ Barra de categorías
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LockerCategoryFilterBar(
                  selectedCategory: category,
                  onCategorySelected: controller.setCategory,
                ),
              ),
            ),

            // Loader
            if (isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ),
              ),

            // Error
            if (!isLoading && error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    "Ocurrió un error:\n$error",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

            // Sin productos
            if (!isLoading && error == null && products.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    "No hay productos para mostrar.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),

            // 🛒 GRID DE PRODUCTOS
            if (!isLoading && products.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final LockerProductModel p = products[index];
                      return LockerProductCard(product: p);
                    },
                    childCount: products.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,

                    /// ✅ ALTURA FIJA / RESPONSIVA (SIN OVERFLOW)
                    mainAxisExtent: MediaQuery.of(context).size.height * 0.39,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
