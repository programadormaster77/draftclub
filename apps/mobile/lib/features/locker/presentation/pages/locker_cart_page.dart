import 'package:flutter/material.dart';
import '../../data/locker_cart_repository.dart';
import '../../data/locker_product_model.dart';
import '../../services/locker_service.dart';

/// ============================================================================
/// 🧺 LockerCartPage — Carrito básico local del Locker
/// ============================================================================
/// - Muestra los productos añadidos al carrito.
/// - Permite aumentar/disminuir cantidad.
/// - Calcula el total.
/// - Permite eliminar items.
/// - Preparado para integrar pasarela de pago en el futuro.
/// ============================================================================

class LockerCartPage extends StatefulWidget {
  LockerCartPage({super.key});

  @override
  State<LockerCartPage> createState() => _LockerCartPageState();
}

class _LockerCartPageState extends State<LockerCartPage> {
  final LockerCartRepository _cartRepo = LockerCartRepository();
  final LockerService _lockerService = LockerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Carrito',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // =======================================================================
      // BODY: escucha el carrito en tiempo real
      // =======================================================================
      body: StreamBuilder<List<LockerCartItem>>(
        stream: _cartRepo.watchCart(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final cartItems = snapshot.data!;

          if (cartItems.isEmpty) {
            return const Center(
              child: Text(
                'Tu carrito está vacío.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // Obtener IDs de productos
          final productIds = cartItems.map((e) => e.productId).toList();

          // FutureBuilder para cargar detalles de productos
          return FutureBuilder<List<LockerProductModel>>(
            future: _lockerService.getProductsByIds(productIds),
            builder: (context, productSnap) {
              if (!productSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                );
              }

              final products = productSnap.data!;
              double total = 0;

              // Mapear items + productos
              final cartView = cartItems.map((item) {
                final product = products.firstWhere(
                  (p) => p.id == item.productId,
                  orElse: () => products.first,
                );
                final subtotal = product.price * item.quantity;
                total += subtotal;
                return _CartLine(
                  item: item,
                  product: product,
                  subtotal: subtotal,
                );
              }).toList();

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: cartView.length,
                      itemBuilder: (_, i) {
                        final line = cartView[i];
                        return _buildCartTile(line);
                      },
                    ),
                  ),

                  // TOTAL + BOTONES
                  _buildBottomBar(total),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // =======================================================================
  // ITEM DEL CARRITO (UI)
  // =======================================================================
  Widget _buildCartTile(_CartLine line) {
    final item = line.item;
    final product = line.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼️ Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              product.images.isNotEmpty
                  ? product.images.first
                  : 'https://via.placeholder.com/70x70.png?text=IMG',
              height: 70,
              width: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),

          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${product.price.toStringAsFixed(0)} ${product.currency}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: \$${line.subtotal.toStringAsFixed(0)} ${product.currency}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Controles de cantidad + eliminar
          Column(
            children: [
              // Botón eliminar
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 22),
                onPressed: () => _cartRepo.removeItem(item.id),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white70, size: 22),
                    onPressed: () {
                      _cartRepo.updateQuantity(item.id, item.quantity - 1);
                    },
                  ),
                  Text(
                    item.quantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.blueAccent, size: 22),
                    onPressed: () {
                      _cartRepo.updateQuantity(item.id, item.quantity + 1);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // BARRA INFERIOR: TOTAL + BOTÓN
  // =======================================================================
  Widget _buildBottomBar(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Aquí en el futuro conectamos con pasarela de pago
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Proceso de pago pendiente de integrar.'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Finalizar compra',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================================================================
/// Clase auxiliar para tener item + producto + subtotal juntos
/// ==========================================================================
class _CartLine {
  final LockerCartItem item;
  final LockerProductModel product;
  final double subtotal;

  _CartLine({
    required this.item,
    required this.product,
    required this.subtotal,
  });
}
