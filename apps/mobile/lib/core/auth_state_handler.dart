import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/profile/presentation/profile_gate.dart';

/// ===============================================================
/// 🔐 AuthStateHandler — Control global de autenticación.
/// ===============================================================
/// ✅ Decide qué pantalla mostrar según el estado actual:
///   - 🔴 No autenticado → LoginPage.
///   - 🟢 Autenticado → ProfileGate (que lleva a Dashboard o crear perfil).
/// ===============================================================
class AuthStateHandler extends StatelessWidget {
  const AuthStateHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🕓 Cargando estado de autenticación
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(text: 'Verificando sesión...');
        }

        // ❌ Sin sesión → ir al Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage();
        }

        // ✅ Sesión activa → dejar que ProfileGate decida
        return const ProfileGate();
      },
    );
  }
}

/// Pantalla de carga simple
class _LoadingScreen extends StatelessWidget {
  final String text;
  const _LoadingScreen({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 18),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
