import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
/// Controla toda la navegación global de la app:
/// - Redirige según autenticación (ProfileGate).
/// - Mantiene consistencia entre módulos (feed / social / rooms).
/// - Evita rutas huérfanas tras logout.
/// 
/// ✅ Compatible con go_router v14+
/// ===============================================================
final GoRouter router = GoRouter(
  // 👇 Pantalla inicial por defecto
  initialLocation: '/',

  // ===============================================================
  // 🔹 LISTA DE RUTAS
  // ===============================================================
  routes: [
    // 🟦 Pantalla de inicio de sesión
    GoRoute(
      path: '/',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // 🟦 Puerta de perfil (controla flujo tras login)
    GoRoute(
      path: '/profile-gate',
      name: 'profile-gate',
      builder: (context, state) => const ProfileGate(),
    ),

    // 🟦 Feed actual (versión MVP)
    GoRoute(
      path: '/feed',
      name: 'feed',
      builder: (context, state) => const FeedPage(),
    ),

    // 🟦 Rutas del módulo social
    ...socialRoutes,
  ],

  // ===============================================================
  // 🔁 REDIRECCIONES CONDICIONALES
  // ===============================================================
  redirect: (context, state) {
    // Si más adelante quieres activar control de sesión:
    //
    // final user = FirebaseAuth.instance.currentUser;
    // final loggingIn = state.matchedLocation == '/';
    //
    // if (user == null && !loggingIn) return '/';
    // if (user != null && loggingIn) return '/profile-gate';
    //
    // Por ahora no redirige, solo devuelve null.
    return null;
  },

  // ===============================================================
  // 🧪 CONFIGURACIÓN DE DEPURACIÓN / ERRORES
  // ===============================================================
  debugLogDiagnostics: true,
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Text(
        '⚠️ Ruta no encontrada:\n${state.uri.toString()}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    ),
  ),
);

