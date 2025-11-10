import 'package:flutter/material.dart';
import 'user_role_service.dart';

/// ===============================================================
/// 🧩 AdminVisibilityWrapper
/// ===============================================================
/// Envuelve un widget y solo lo muestra si el usuario actual es admin.
/// Ideal para ocultar botones o secciones enteras del panel.
/// ===============================================================
class AdminVisibilityWrapper extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const AdminVisibilityWrapper({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserRoleService().isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final isAdmin = snapshot.data ?? false;
        return isAdmin ? child : (fallback ?? const SizedBox.shrink());
      },
    );
  }
}
