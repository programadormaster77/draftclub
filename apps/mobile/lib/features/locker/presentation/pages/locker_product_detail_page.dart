import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/locker_product_model.dart';
import '../../services/locker_service.dart';

class LockerProductDetailPage extends StatefulWidget {
  final LockerProductModel product;

  const LockerProductDetailPage({
    super.key,
    required this.product,
  });

  @override
  State<LockerProductDetailPage> createState() =>
      _LockerProductDetailPageState();
}

class _LockerProductDetailPageState extends State<LockerProductDetailPage> {
  final LockerService _lockerService = LockerService();

  @override
  void initState() {
    super.initState();
    ;
    _lockerService.increasePopularity(widget.product.id, amount: 1);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Detalle del producto',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // ===============================================================
      // BODY RESPONSIVE — SIN SIZEDBOX TRAMPA
      // ===============================================================
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGENES
                SizedBox(
                  height: 340,
                  width: double.infinity,
                  child: PageView.builder(
                    itemCount:
                        product.images.isNotEmpty ? product.images.length : 1,
                    itemBuilder: (_, i) {
                      final img = product.images.isNotEmpty
                          ? product.images[i]
                          : "https://via.placeholder.com/400x400.png?text=Sin+Imagen";

                      return CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image,
                              size: 60, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // TAGS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (product.featured)
                        _buildTag("Destacado", Colors.blueAccent),
                      if (product.ownerRole == 'admin')
                        _buildTag("ADMIN", Colors.amberAccent),
                      if (product.ownerRole == 'vip')
                        _buildTag("VIP", Colors.purpleAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // TITULO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    product.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // PRECIO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "\$${product.price.toStringAsFixed(0)} ${product.currency}",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // DESCRIPCION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    product.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // INFORMACION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSection(
                    title: "Información",
                    children: [
                      _infoRow("Categoría", product.mainCategory),
                      _infoRow("Subcategoría", product.subCategory),
                      if (product.gender.isNotEmpty)
                        _infoRow("Género", product.gender),
                      if (product.size.isNotEmpty)
                        _infoRow("Talla", product.size),
                      _infoRow("Ubicación", product.location),
                      _infoRow(
                        "Tipo",
                        product.type == "external"
                            ? "Producto externo"
                            : "Producto local",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40), // suficiente espacio
              ],
            ),
          ),
        ],
      ),

      // ===============================================================
      // BARRA INFERIOR PREMIUM — FIJA Y SAFE AREA
      // ===============================================================
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              // AÑADIR AL CARRITO
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Añadido al carrito")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Añadir al carrito",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // COMPRAR / VER EN TIENDA
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    /// TODO: url_launcher
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    product.type == "external" ? "Ver en tienda" : "Comprar",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGETS -------------------------------------------------------

  Widget _buildTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            "$label:",
            style: const TextStyle(
                color: Colors.white60, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
