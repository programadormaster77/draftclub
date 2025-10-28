import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🧩 Páginas del flujo
import '../../feed/presentation/dashboard_page.dart';
import 'profile_setup_page.dart';

/// ===============================================================
/// 🚪 ProfileGate — Controlador de flujo de perfil del usuario
/// ===============================================================
///
/// 🔹 Si el usuario está autenticado:
///    → Busca su documento en `users/<uid>`.
///    → Si NO existe → lo envía a `ProfileSetupPage()`.
///    → Si SÍ existe pero faltan datos esenciales (ej: sexo, nombre, ciudad, posición)
///      → lo envía a `ProfileSetupPage()` para completar.
///    → Si el perfil está completo → lo envía al `DashboardPage()`.
///
/// 🔹 Este widget se carga automáticamente desde AuthStateHandler.
///    Por tanto, **NO maneja login ni logout aquí**.
/// ===============================================================
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ⚠️ Caso muy raro: usuario no autenticado pero llegó aquí
    if (user == null) {
      return const _LoadingOrError(message: 'Error: usuario no autenticado.');
    }

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        // 🕓 Mientras carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingOrError(message: 'Cargando tu perfil...');
        }

        // ⚠️ Si ocurre un error de conexión
        if (snapshot.hasError) {
          return const _LoadingOrError(
            message: 'Error al cargar los datos del perfil.',
          );
        }

        // ⚠️ Si el documento no existe → redirigir a creación de perfil
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ProfileSetupPage();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        // 🧩 Si el documento está vacío o sin campos básicos
        if (data == null) return const ProfileSetupPage();

        final name = (data['name'] ?? '').toString().trim();
        final city = (data['city'] ?? '').toString().trim();
        final position = (data['position'] ?? '').toString().trim();
        final sex = (data['sex'] ?? '').toString().trim();

        // ⚠️ Si falta algún campo esencial, redirigir a la configuración inicial
        final perfilIncompleto =
            name.isEmpty || city.isEmpty || position.isEmpty || sex.isEmpty;

        if (perfilIncompleto) {
          return const ProfileSetupPage();
        }

        // ✅ Si todo está completo → Dashboard principal
        return const DashboardPage();
      },
    );
  }
}

/// ===============================================================
/// ⏳ _LoadingOrError — Pantalla para carga o errores
/// ===============================================================
class _LoadingOrError extends StatelessWidget {
  final String message;
  const _LoadingOrError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
