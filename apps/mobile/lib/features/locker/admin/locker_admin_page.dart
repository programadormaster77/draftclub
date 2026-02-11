import 'package:flutter/material.dart';
import '../data/locker_product_model.dart';
import '../services/locker_service.dart';
import 'locker_admin_product_form.dart';

/// ============================================================================
/// 🛠️ LockerAdminPage
/// ============================================================================
/// Panel principal del administrador del Locker:
/// - Lista de productos creados por el administrador.
/// - Botón para crear nuevo producto.
/// - Acceso al formulario de edición.
/// - Permite eliminar o destacar productos.
/// ============================================================================

class LockerAdminPage extends StatefulWidget {
  const LockerAdminPage({super.key});

  @override
  State<LockerAdminPage> createState() => _LockerAdminPageState();
}

class _LockerAdminPageState extends State<LockerAdminPage> {
  final LockerService _lockerService = LockerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Administrador – Locker',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LockerAdminProductForm(),
                ),
              );
            },
            tooltip: 'Crear nuevo producto',
          ),
        ],
      ),

      // =========================================================================
      // 🔄 LISTA DE PRODUCTOS QUE EL ADMIN HA CREADO
      // =========================================================================
      body: StreamBuilder<List<LockerProductModel>>(
        stream: _getAdminProductsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final products = snapshot.data!;

          if (products.isEmpty) {
            return const Center(
              child: Text(
                'Aún no has creado productos.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];
              return _buildProductTile(p);
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 🟦 Cargar solo productos creados por el ADMIN
  // ===========================================================================
  Stream<List<LockerProductModel>> _getAdminProductsStream() {
    // En tu modelo ya tenemos ownerUid y ownerRole
    return _lockerService.getFilteredProducts(mainCategory: null).map(
      (allProducts) {
        return allProducts.where((p) => p.ownerRole == 'admin').toList();
      },
    );
  }

  // ===========================================================================
  // 🔹 TILE de lista del admin
  // ===========================================================================
  Widget _buildProductTile(LockerProductModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product.images.isNotEmpty
                ? product.images.first
                : 'https://via.placeholder.com/60x60.png?text=IMG',
            height: 55,
            width: 55,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          product.title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '\$${product.price.toStringAsFixed(0)} · ${product.location}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⭐ Destacar
            IconButton(
              icon: Icon(
                product.featured ? Icons.star : Icons.star_border,
                color: product.featured ? Colors.amberAccent : Colors.white38,
              ),
              tooltip: product.featured ? "Quitar destacado" : "Destacar",
              onPressed: () async {
                await _lockerService.updateProduct(product.id, {
                  'featured': !product.featured,
                });
              },
            ),

            // ✏️ Editar
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              tooltip: "Editar producto",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LockerAdminProductForm(
                      existingProduct: product,
                    ),
                  ),
                );
              },
            ),

            // 🗑️ Eliminar
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Eliminar producto",
              onPressed: () {
                _confirmDelete(product);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 🗑️ Confirmación de eliminación
  // ===========================================================================
  void _confirmDelete(LockerProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Eliminar producto",
            style: TextStyle(color: Colors.white)),
        content: Text(
          "¿Seguro que deseas eliminar \"${product.title}\"?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child:
                const Text("Cancelar", style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Eliminar",
                style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              await _lockerService.deleteProduct(product.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
