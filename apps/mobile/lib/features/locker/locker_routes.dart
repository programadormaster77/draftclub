import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ============================================================================
// 📄 Páginas del módulo Locker
// ============================================================================
import 'presentation/pages/locker_page.dart';
import 'presentation/pages/locker_search_page.dart';
import 'presentation/pages/locker_cart_page.dart';
import 'presentation/pages/locker_product_detail_page.dart';

// ============================================================================
// 🛠 Panel de administración
// ============================================================================
import 'admin/locker_admin_page.dart';
import 'admin/locker_admin_product_form.dart';

// ============================================================================
// 🔧 Servicios
// ============================================================================
import 'services/locker_service.dart';

/// ============================================================================
/// 📦 lockerRoutes — Todas las rutas del Marketplace Locker
/// ============================================================================
/// - Página principal
/// - Buscador
/// - Carrito
/// - Detalle de producto
/// - Admin: listar, crear y editar productos
/// ============================================================================

final List<GoRoute> lockerRoutes = [
  // ==========================================================================
  // 🏬 Página principal del Marketplace
  // ==========================================================================
  GoRoute(
    path: '/locker',
    name: 'locker',
    builder: (context, state) => const LockerPage(),
  ),

  // ==========================================================================
  // 🔍 Página de búsqueda
  // ==========================================================================
  GoRoute(
    path: '/locker/search',
    name: 'locker-search',
    builder: (context, state) => const LockerSearchPage(),
  ),

  // ==========================================================================
  // 🧺 Carrito
  // ==========================================================================
  GoRoute(
    path: '/locker/cart',
    name: 'locker-cart',
    builder: (context, state) => LockerCartPage(), // ← SIN CONST
  ),

  // ==========================================================================
  // 📄 Detalle de producto
  // ==========================================================================
  GoRoute(
    path: '/locker/product/:id',
    name: 'locker-product-detail',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';

      return FutureBuilder(
        future: LockerService().getProductById(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            );
          }

          final product = snapshot.data;
          if (product == null) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'Producto no encontrado',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return LockerProductDetailPage(product: product);
        },
      );
    },
  ),

  // ==========================================================================
  // 🛠 Panel de administración
  // ==========================================================================
  GoRoute(
    path: '/locker/admin',
    name: 'locker-admin',
    builder: (context, state) => const LockerAdminPage(),
  ),

  // ==========================================================================
  // ➕ Crear producto
  // ==========================================================================
  GoRoute(
    path: '/locker/admin/create',
    name: 'locker-admin-create',
    builder: (context, state) => const LockerAdminProductForm(),
  ),

  // ==========================================================================
  // ✏️ Editar producto
  // ==========================================================================
  GoRoute(
    path: '/locker/admin/edit/:id',
    name: 'locker-admin-edit',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';

      return FutureBuilder(
        future: LockerService().getProductById(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            );
          }

          final product = snapshot.data;
          if (product == null) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'Producto no encontrado',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return LockerAdminProductForm(existingProduct: product);
        },
      );
    },
  ),
];
