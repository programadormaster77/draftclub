import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'user_role_service.dart';

/// ===============================================================
/// 🛡️ AdminGuard — Protección de rutas exclusivas para administradores
/// ===============================================================
/// Compatible con go_router 14.x+
/// En lugar de extender una clase inexistente, usa un método estático
/// para aplicar el chequeo en el redirect.
/// ===============================================================
class AdminGuard {
  static Future<String?> check(BuildContext context) async {
    final roleService = UserRoleService();
    final isAdmin = await roleService.isAdmin();

    if (!isAdmin) {
      // 🔒 Usuario sin permisos → mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso restringido: solo administradores.'),
          backgroundColor: Colors.redAccent,
        ),
      );

      // 🔁 Redirige al home
      return '/home';
    }

    // ✅ Si es admin, permitir acceso
    return null;
  }
}
