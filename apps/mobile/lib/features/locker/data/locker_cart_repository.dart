import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================================
/// 🧺 LockerCartItem — Item del carrito
/// ============================================================================
class LockerCartItem {
  final String id;
  final String productId;
  final int quantity;
  final DateTime addedAt;

  LockerCartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.addedAt,
  });

  factory LockerCartItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return LockerCartItem(
      id: doc.id,
      productId: data['productId']?.toString() ?? '',
      quantity: (data['quantity'] ?? 1) is int
          ? data['quantity'] as int
          : int.tryParse(data['quantity'].toString()) ?? 1,
      addedAt: (data['addedAt'] is Timestamp)
          ? (data['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}

/// ============================================================================
/// 🧺 LockerCartRepository — Manejo del carrito del usuario
/// ============================================================================
/// Estructura en Firestore:
/// users/{uid}/locker_cart/{cartItemId}
/// ============================================================================
class LockerCartRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _cartRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('locker_cart');
  }

  // ==========================================================================
  // 👀 Escuchar cambios del carrito en tiempo real
  // ==========================================================================
  Stream<List<LockerCartItem>> watchCart() {
    final ref = _cartRef;
    if (ref == null) {
      // Usuario no autenticado → carrito vacío
      return Stream.value(const []);
    }

    return ref.orderBy('addedAt', descending: false).snapshots().map(
          (snap) => snap.docs
              .map((doc) => LockerCartItem.fromFirestore(doc))
              .toList(),
        );
  }

  // ==========================================================================
  // ➕ Añadir producto al carrito (incrementa si ya existe)
  // ==========================================================================
  Future<void> addToCart(String productId, {int quantity = 1}) async {
    final ref = _cartRef;
    if (ref == null) return;

    // Buscar si ya existe item con ese productId
    final existing =
        await ref.where('productId', isEqualTo: productId).limit(1).get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final currentQty = (doc.data()['quantity'] ?? 1) as int;
      await doc.reference.update({
        'quantity': currentQty + quantity,
        'addedAt': Timestamp.now(),
      });
    } else {
      await ref.add({
        'productId': productId,
        'quantity': quantity,
        'addedAt': Timestamp.now(),
      });
    }
  }

  // ==========================================================================
  // 🔁 Actualizar cantidad
  // ==========================================================================
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    final ref = _cartRef;
    if (ref == null) return;
    if (quantity <= 0) {
      await removeItem(cartItemId);
      return;
    }

    await ref.doc(cartItemId).update({
      'quantity': quantity,
      'addedAt': Timestamp.now(),
    });
  }

  // ==========================================================================
  // ❌ Eliminar un item
  // ==========================================================================
  Future<void> removeItem(String cartItemId) async {
    final ref = _cartRef;
    if (ref == null) return;

    await ref.doc(cartItemId).delete();
  }

  // ==========================================================================
  // 🧹 Vaciar carrito
  // ==========================================================================
  Future<void> clearCart() async {
    final ref = _cartRef;
    if (ref == null) return;

    final snap = await ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
