import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../data/locker_product_model.dart';
import '../services/locker_service.dart';

/// ============================================================================
/// 📝 LockerAdminProductForm
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

  // ============================
  // LISTAS DE OPCIONES NUEVAS
  // ============================
  final List<String> categories = [
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

  final Map<String, List<String>> subcategoriesMap = {
    'Guayos': ['FG', 'AG', 'MG', 'IC', 'TF'],
    'Balones': ['Profesional', 'Entrenamiento', 'Futsal'],
    'Camisetas': ['Jugador', 'Aficionado', 'Entrenamiento', 'Retro'],
    'Conjuntos': ['Entrenamiento', 'Competición', 'Infantil'],
    'Sudaderas': ['Capucha', 'Cremallera', 'Térmica'],
    'Accesorios': ['Canilleras', 'Medias', 'Gorras', 'Mochilas'],
    'Fitness': ['Pesas', 'Bandas', 'Guantes', 'Ropa fitness'],
    'Porteros': ['Guantes', 'Pantalón', 'Camiseta'],
    'Equipos': ['Colombia', 'Europa', 'MLS'],
    'Mujer': ['Camisetas', 'Sudaderas', 'Conjuntos'],
    'Hombre': ['Camisetas', 'Sudaderas', 'Conjuntos'],
    'Unisex': ['Camisetas', 'Sudaderas'],
    'Ofertas': ['Descuentos', 'Liquidación'],
  };

  final List<String> genders = ['Caballero', 'Dama', 'Unisex', 'Infantil'];

  final List<String> clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  final List<String> shoeSizes = [
    '20',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '29',
    '30',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
    '43',
    '44',
    '45',
  ];

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
  // Subir imágenes
  // ===========================================================================
  Future<void> pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

      if (picked == null) return;

      final File file = File(picked.path);

      final String fileName =
          'locker_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('locker_products')
          .child(fileName);

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snap = await uploadTask;
      final String downloadUrl = await snap.ref.getDownloadURL();

      setState(() => images.add(downloadUrl));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al subir imagen: $e")),
      );
    }
  }

  // ===========================================================================
  // Guardar producto
  // ===========================================================================
  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (images.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Debes subir imágenes")));
      return;
    }

    setState(() => isLoading = true);

    final double parsedPrice = double.tryParse(price.replaceAll('.', '')) ?? 0;

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
      storeType: storeType,
      location: location,
      cityData: cityData,
      type: type,
      externalLink: type == 'external' ? externalLink : null,
      tags: tags,
      searchKeywords: _buildSearchKeywords(),
      stock: 10,
      visibility: true,
      featured: featured,
      isSponsored: isSponsored,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    }

    setState(() => isLoading = false);
  }

  // ===========================================================================
  // Keywords
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
      if (p.isNotEmpty) keywords.add(p.toLowerCase().trim());
    }

    return keywords.toSet().toList();
  }

  // ===========================================================================
  // Lista inteligente de tallas
  // ===========================================================================
  List<String> _availableSizes() {
    if (mainCategory == 'Guayos') return shoeSizes;

    if (['Camisetas', 'Conjuntos', 'Sudaderas', 'Hombre', 'Mujer', 'Unisex']
        .contains(mainCategory)) {
      return clothingSizes;
    }

    return [];
  }

  // ===========================================================================
  // Formato de precio
  // ===========================================================================
  String _formatNumber(int number) {
    String s = number.toString();
    String result = '';
    int count = 0;

    for (int i = s.length - 1; i >= 0; i--) {
      result = s[i] + result;
      count++;
      if (count == 3 && i != 0) {
        result = '.$result';
        count = 0;
      }
    }
    return result;
  }

  // ===========================================================================
  // PICKER UNIVERSAL (dentro de la clase, ahora funciona)
  // ===========================================================================
  Widget _picker({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AbsorbPointer(
        child: _input(
          label: label,
          initial: value.isEmpty ? "Seleccionar..." : value,
          onChanged: (_) {},
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM SHEET SELECTOR (dentro de la clase, ahora funciona)
  // ===========================================================================
  Future<String?> _openPicker(String title, List<String> items) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    return ListTile(
                      title: Text(items[i],
                          style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.pop(sheetContext, items[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget selectorInput({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? Colors.white24 : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? label : value,
                style: TextStyle(
                  color: value.isEmpty ? Colors.white54 : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          ],
        ),
      ),
    );
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
              // ====================
              // IMÁGENES
              // ====================
              Text("Imágenes", style: _sectionTitle()),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...images.map((url) => _imagePreview(url)),
                  _addImageButton(),
                ],
              ),

              const SizedBox(height: 22),

              // ====================
              // INFORMACIÓN BÁSICA
              // ====================
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

              TextFormField(
                controller: TextEditingController(text: price),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Precio",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (value) {
                  final clean = value.replaceAll('.', '');
                  if (clean.isEmpty) {
                    setState(() => price = '');
                    return;
                  }
                  final number = int.parse(clean);
                  setState(() => price = _formatNumber(number));
                },
              ),

              _input(
                label: "Moneda (COP, USD...)",
                initial: currency,
                onChanged: (v) => currency = v,
              ),

              const SizedBox(height: 22),

              // ====================
// CATEGORÍAS
// ====================
              Text("Categorías", style: _sectionTitle()),

// CATEGORÍA PRINCIPAL
              selectorInput(
                label: "Categoría principal",
                value: mainCategory,
                onTap: () async {
                  final selected =
                      await _openPicker("Categoría principal", categories);

                  if (selected != null) {
                    setState(() {
                      mainCategory = selected;
                      subCategory = '';
                      size = '';
                    });
                  }
                },
              ),

// SUBCATEGORÍA
              selectorInput(
                label: "Subcategoría",
                value: subCategory,
                enabled: mainCategory.isNotEmpty,
                onTap: () async {
                  final list = subcategoriesMap[mainCategory] ?? [];
                  final selected = await _openPicker("Subcategoría", list);
                  if (selected != null) {
                    setState(() => subCategory = selected);
                  }
                },
              ),

// GÉNERO
              selectorInput(
                label: "Género",
                value: gender,
                onTap: () async {
                  final selected = await _openPicker("Género", genders);
                  if (selected != null) {
                    setState(() => gender = selected);
                  }
                },
              ),

// TALLA
              selectorInput(
                label: "Talla",
                value: size,
                enabled: _availableSizes().isNotEmpty,
                onTap: () async {
                  final selected =
                      await _openPicker("Talla", _availableSizes());
                  if (selected != null) {
                    setState(() => size = selected);
                  }
                },
              ),

// UBICACIÓN (TEMPORAL - SECCIÓN B LA REEMPLAZA)
              _input(
                label: "Ubicación (ciudad)",
                initial: location,
                onChanged: (v) => location = v,
              ),

              const SizedBox(height: 22),

// ====================
// TIPO DE TIENDA
// ====================
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

// ====================
// TIPO DE PRODUCTO
// ====================
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

// ====================
// TAGS
// ====================
              Text("Tags (separados por coma)", style: _sectionTitle()),

              _input(
                label: "Ej: guayos, nike, futbol",
                initial: tags.join(", "),
                onChanged: (v) =>
                    tags = v.split(",").map((e) => e.trim()).toList(),
              ),

              const SizedBox(height: 22),

// ====================
// DESTACADO / PATROCINADO
// ====================
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
          clipBehavior: Clip.hardEdge,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: () => setState(() => images.remove(url)),
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
