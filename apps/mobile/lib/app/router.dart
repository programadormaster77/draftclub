import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// 🧩 Features principales
import '../features/auth/presentation/login_page.dart';
import '../features/profile/presentation/profile_gate.dart';
import '../features/feed/presentation/feed_page.dart';

// 🧩 Nuevo módulo social
import '../features/social/social_routes.dart';

/// ===============================================================
/// 🚦 Router global de DraftClub
/// ===============================================================
///
/// Controla toda la navegación de la app:
/// - Redirige según autenticación.
/// - Mantiene consistencia entre módulos (feed / social / rooms).
/// - Evita rutas huérfanas tras logout.
///
/// Usa go_router v14+
/// ===============================================================
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    // 🔹 Pantalla de inicio de sesión
    GoRoute(
      path: '/',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // 🔹 Controlador de flujo de perfil
    GoRoute(
      path: '/profile-gate',
      name: 'profile-gate',
      builder: (context, state) => const ProfileGate(),
    ),

    // 🔹 Feed actual (versión MVP)
    GoRoute(
      path: '/feed',
      name: 'feed',
      builder: (context, state) => const FeedPage(),
    ),

    // 🔹 Rutas del módulo social (feed, perfil público, crear post, etc.)
    ...socialRoutes,
  ],

  // 🚧 Redirección condicional (versión simple, ampliable)
  redirect: (context, state) {
    // Aquí puedes añadir lógica si integras FirebaseAuth:
    // final user = FirebaseAuth.instance.currentUser;
    // final loggingIn = state.matchedLocation == '/';
    // if (user == null && !loggingIn) return '/';
    // if (user != null && loggingIn) return '/profile-gate';
    return null;
  },

  // 🧠 Depuración
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Ruta no encontrada:\n${state.uri.toString()}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  ),
);
