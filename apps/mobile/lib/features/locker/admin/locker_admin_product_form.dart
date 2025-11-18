import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data/locker_product_model.dart';
import '../services/locker_service.dart';

/// ============================================================================
/// 📝 LockerAdminProductForm
/// ============================================================================
/// Formulario para:
/// - Crear productos
/// - Editar productos
///
/// Incluye:
/// - Subida de imágenes
/// - Categorías
/// - Tipo local/external
/// - Tipo de tienda (storeType)
/// - Producto patrocinado (isSponsored)
/// - Destacado
///
/// Totalmente compatible con LockerProductModel actualizado.
/// ============================================================================

class LockerAdminProductForm extends StatefulWidget {
  final LockerProductModel? existingProduct;

  const LockerAdminProductForm({super.key, this.existingProduct});

  @override
  State<LockerAdminProductForm> createState() => _LockerAdminProductFormState();
}

class _LockerAdminProductFormState extends State<LockerAdminProductForm> {
  final _formKey = GlobalKey<FormState>();
  final LockerService _lockerService = LockerService();

  // Campos principales
  String title = '';
  String description = '';
  String price = '';
  String currency = 'COP';

  String mainCategory = '';
  String subCategory = '';
  String gender = '';
  String size = '';
  String location = '';
  String type = 'local';
  String externalLink = '';

  /// 🏪 Tipo de tienda
  String storeType = 'official';

  /// ⭐ Producto patrocinado
  bool isSponsored = false;

  List<String> tags = [];
  bool featured = false;

  List<String> images = [];
  bool isLoading = false;

// ======= NUEVAS VARIABLES PARA UBICACIÓN =======
  Map<String, dynamic>? cityData;
  final TextEditingController _locationController = TextEditingController();
// ==============================================

  @override
  void initState() {
    super.initState();

    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      title = p.title;
      description = p.description;
      price = p.price.toString();
      currency = p.currency;
      mainCategory = p.mainCategory;
      subCategory = p.subCategory;
      gender = p.gender;
      size = p.size;
      location = p.location;
      type = p.type;
      externalLink = p.externalLink ?? '';
      tags = List<String>.from(p.tags);
      images = List<String>.from(p.images);
      featured = p.featured;
      storeType = p.storeType;
      isSponsored = p.isSponsored;
    }
  }

  // ===========================================================================
// Subir imágenes  (REEMPLAZAR TODA ESTA FUNCIÓN)
// ===========================================================================
  Future<void> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // optimiza carga
      );

      if (picked == null) {
        print("⚠ No se seleccionó ninguna imagen.");
        return;
      }

      final File file = File(picked.path);

      // Validar que el archivo existe
      if (!file.existsSync()) {
        print("❌ El archivo de imagen no existe.");
        return;
      }

      final String fileName =
          'locker_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('locker_products')
          .child(fileName);

      // Cargar con metadata para evitar errores en Android/iOS
      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final TaskSnapshot snap = await uploadTask;
      final String downloadUrl = await snap.ref.getDownloadURL();

      setState(() {
        images.add(downloadUrl);
      });

      print("✔ Imagen subida correctamente: $downloadUrl");
    } catch (e) {
      print("❌ Error al subir imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al subir imagen: $e")),
        );
      }
    }
  }

  // ===========================================================================
  // Guardar producto
  // ===========================================================================
  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes subir al menos una imagen")),
      );
      return;
    }

    setState(() => isLoading = true);

    final double parsedPrice = double.tryParse(price) ?? 0;

    final product = LockerProductModel(
      id: widget.existingProduct?.id ?? '',
      ownerUid: 'admin-0001',
      ownerRole: 'admin',

      title: title,
      description: description,
      price: parsedPrice,
      currency: currency,
      images: images,

      mainCategory: mainCategory,
      subCategory: subCategory,
      gender: gender,
      size: size,

      /// 🏪 Store type
      storeType: storeType,

      location: location,
      cityData:
          cityData, // ← AÑADE ESTO (puede ser null si aún no seleccionaron)
      type: type,
      externalLink: type == 'external' ? externalLink : null,

      tags: tags,
      searchKeywords: _buildSearchKeywords(),

      stock: 10,
      visibility: true, // 🔥 Campo requerido por el modelo
      featured: featured,
      isSponsored: isSponsored, // 🔥 Campo requerido por el modelo

      popularity: widget.existingProduct?.popularity ?? 0,
      boostScore: widget.existingProduct?.boostScore ?? 0,

      createdAt: widget.existingProduct?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.existingProduct == null) {
        await _lockerService.createFullProduct(product);
      } else {
        await _lockerService.updateProduct(product.id, product.toMap());
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  // ===========================================================================
  // Build keywords
  // ===========================================================================
  List<String> _buildSearchKeywords() {
    final parts = [
      title,
      mainCategory,
      subCategory,
      gender,
      size,
      ...tags,
    ];

    final keywords = <String>[];

    for (final p in parts) {
      if (p.isEmpty) continue;

      final normalized = p.toLowerCase().trim();
      keywords.add(normalized);
    }

    return keywords.toSet().toList();
  }

  // ===========================================================================
  // UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProduct != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          isEditing ? 'Editar producto' : 'Nuevo producto',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: saveProduct,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// =================================================================
              /// IMÁGENES
              /// =================================================================
              Text("Imágenes", style: _sectionTitle()),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...images.map((url) => _imagePreview(url)),
                  _addImageButton(),
                ],
              ),

              const SizedBox(height: 22),

              /// =================================================================
              /// INFORMACIÓN BÁSICA
              /// =================================================================
              Text("Información básica", style: _sectionTitle()),

              _input(
                label: "Título",
                initial: title,
                onChanged: (v) => title = v,
                validator: (v) => v!.isEmpty ? "Campo obligatorio" : null,
              ),

              _input(
                label: "Descripción",
                initial: description,
                onChanged: (v) => description = v,
                maxLines: 4,
              ),

              _input(
                label: "Precio",
                initial: price,
                onChanged: (v) => price = v,
              ),

              _input(
                label: "Moneda (COP, USD...)",
                initial: currency,
                onChanged: (v) => currency = v,
              ),

              const SizedBox(height: 22),

              /// =================================================================
              /// CATEGORÍAS
              /// =================================================================
              Text("Categorías", style: _sectionTitle()),

              _input(
                label: "Categoría principal",
                initial: mainCategory,
                onChanged: (v) => mainCategory = v,
              ),

              _input(
                label: "Subcategoría",
                initial: subCategory,
                onChanged: (v) => subCategory = v,
              ),

              _input(
                label: "Género",
                initial: gender,
                onChanged: (v) => gender = v,
              ),

              _input(
                label: "Talla",
                initial: size,
                onChanged: (v) => size = v,
              ),

              _input(
                label: "Ubicación (ciudad)",
                initial: location,
                onChanged: (v) => location = v,
              ),

              const SizedBox(height: 22),

              /// =================================================================
              /// TIPO DE TIENDA
              /// =================================================================
              Text("Tipo de tienda", style: _sectionTitle()),

              DropdownButtonFormField<String>(
                value: storeType,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: 'official',
                    child: Text("Tienda oficial",
                        style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'user',
                    child: Text("Usuario / Marketplace",
                        style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'local-store',
                    child: Text("Tienda local",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (v) => setState(() => storeType = v ?? 'official'),
              ),

              const SizedBox(height: 22),

              /// =================================================================
              /// TIPO DE PRODUCTO
              /// =================================================================
              Text("Tipo de producto", style: _sectionTitle()),

              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: 'local',
                    child: Text("Local (stock físico)",
                        style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'external',
                    child: Text("Externo (Amazon, tiendas…)",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (v) => setState(() => type = v ?? 'local'),
              ),

              if (type == 'external') ...[
                const SizedBox(height: 12),
                _input(
                  label: "Enlace externo",
                  initial: externalLink,
                  onChanged: (v) => externalLink = v,
                ),
              ],

              const SizedBox(height: 22),

              /// =================================================================
              /// TAGS
              /// =================================================================
              Text("Tags (separados por coma)", style: _sectionTitle()),

              _input(
                label: "Ej: guayos, nike, futbol",
                initial: tags.join(", "),
                onChanged: (v) =>
                    tags = v.split(",").map((e) => e.trim()).toList(),
              ),

              const SizedBox(height: 22),

              /// =================================================================
              /// DESTACADO / PATROCINADO
              /// =================================================================
              SwitchListTile(
                title: const Text("Destacar producto",
                    style: TextStyle(color: Colors.white)),
                value: featured,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => featured = v),
              ),

              SwitchListTile(
                title: const Text("Producto patrocinado",
                    style: TextStyle(color: Colors.white)),
                value: isSponsored,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => isSponsored = v),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
// WIDGETS
// ===========================================================================

  TextStyle _sectionTitle() => const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );

  Widget _input({
    required String label,
    required String initial,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: initial,
        onChanged: onChanged,
        validator: validator,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _imagePreview(String url) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black26,
          ),
          clipBehavior: Clip.hardEdge, // ← evita errores al recortar imagen
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: () {
              setState(() => images.remove(url));
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageButton() {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.add_a_photo, color: Colors.white38),
      ),
    );
  }
}
