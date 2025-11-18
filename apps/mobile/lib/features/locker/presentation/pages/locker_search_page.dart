import 'package:flutter/material.dart';
import '../../data/locker_product_model.dart';
import '../../services/locker_service.dart';
import '../widgets/locker_product_card.dart';

/// ============================================================================
/// 🔍 LockerSearchPage — Buscador avanzado
/// ============================================================================
/// Permite buscar productos por:
/// - Texto (título, tags, keywords)
/// - Categoría
/// - Subcategoría
/// - Tipo local/external
/// - Rango de precios (futuro)
///
/// TODO: integrar categoría y filtros avanzados con la barra superior.
/// ============================================================================

class LockerSearchPage extends StatefulWidget {
  final String initialQuery;

  const LockerSearchPage({
    super.key,
    this.initialQuery = '',
  });

  @override
  State<LockerSearchPage> createState() => _LockerSearchPageState();
}

class _LockerSearchPageState extends State<LockerSearchPage> {
  final LockerService _lockerService = LockerService();

  String query = '';
  bool isLoading = false;
  List<LockerProductModel> results = [];

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;

    if (query.isNotEmpty) {
      _performSearch(query);
    }
  }

  // ===========================================================================
  // 🔍 Ejecutar búsqueda
  // ===========================================================================
  Future<void> _performSearch(String text) async {
    if (text.trim().isEmpty) {
      setState(() => results = []);
      return;
    }

    setState(() => isLoading = true);

    try {
      // CORRECCIÓN IMPORTANTE:
      // searchProducts() devuelve un STREAM → hay que tomar la PRIMERA emisión
      final data = await _lockerService.searchProducts(text.trim()).first;

      setState(() => results = data);
    } catch (e) {
      debugPrint("Error al buscar productos: $e");
    }

    setState(() => isLoading = false);
  }

  // ===========================================================================
  // 🔄 UI PRINCIPAL
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _buildSearchField(),
      ),
      body: _buildBody(),
    );
  }

  // ===========================================================================
  // 🔤 Barra superior con input
  // ===========================================================================
  Widget _buildSearchField() {
    return TextField(
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.blueAccent,
      decoration: const InputDecoration(
        hintText: 'Buscar productos…',
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
      onChanged: (t) {
        query = t;
        _performSearch(query);
      },
    );
  }

  // ===========================================================================
  // 📦 Resultados
  // ===========================================================================
  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Empieza a escribir para buscar productos…',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron productos.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: results.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (_, i) {
        final product = results[i];
        return LockerProductCard(product: product);
      },
    );
  }
}
