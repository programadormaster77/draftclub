import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/locker_product_model.dart';
import '../../services/locker_service.dart';
import '../pages/locker_product_detail_page.dart';

/// ============================================================================
/// 🟥 LockerProductCard — Tarjeta individual del producto (OPTIMIZADA)
/// ============================================================================
/// - SIN overflow (bottom overflow FIXED)
/// - Imagen totalmente responsiva
/// - Contenido inferior en layout flexible
/// - Mantiene todo tu diseño original
/// ============================================================================

class LockerProductCard extends StatelessWidget {
  final LockerProductModel product;
  LockerProductCard({super.key, required this.product});

  final LockerService _lockerService = LockerService();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _lockerService.increasePopularity(product.id, amount: 1);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LockerProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================================================================
            // 🖼️ Imagen principal (RESPONSIVA, evita overflow)
            // ===================================================================
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 1, // 🔥 se ajusta según tamaño disponible
                child: CachedNetworkImage(
                  imageUrl: product.images.isNotEmpty
                      ? product.images.first
                      : 'https://via.placeholder.com/300x300.png?text=Sin+Imagen',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            // ===================================================================
            // 🏷️ Etiquetas (Destacado / Admin / VIP)
            // ===================================================================
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 10, right: 10),
              child: Row(
                children: [
                  if (product.featured)
                    _buildTag('Destacado', Colors.blueAccent),
                  if (product.ownerRole == 'admin')
                    _buildTag('ADMIN', Colors.amberAccent),
                  if (product.ownerRole == 'vip')
                    _buildTag('VIP', Colors.purpleAccent),
                ],
              ),
            ),

            // ===================================================================
            // 🔤 Título (NUNCA hace overflow)
            // ===================================================================
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, top: 6),
              child: Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),

            // ===================================================================
            // 💰 Precio (flexible / responsivo)
            // ===================================================================
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 4),
              child: Text(
                '\$${product.price.toStringAsFixed(0)} ${product.currency}',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // ===================================================================
            // 📍 Ciudad (también limita overflow)
            // ===================================================================
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2, bottom: 8),
              child: Text(
                product.location,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ======================================================================
  /// 🏷️ Constructor de etiquetas
  /// ======================================================================
  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
