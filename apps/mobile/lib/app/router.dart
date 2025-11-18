import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 🧩 Features principales
import '../features/auth/presentation/login_page.dart';
import '../features/profile/presentation/profile_gate.dart';
import '../features/feed/presentation/feed_page.dart';

// 🧩 Módulo social
import '../features/social/social_routes.dart';

// 🛒 Módulo Locker (Marketplace)
import '../features/locker/locker_routes.dart';

/// ===============================================================
/// 🚦 Router global de DraftClub
/// ===============================================================
/// Control central de navegación:
/// - Maneja login / profile gate.
/// - Integra todos los módulos (feed, social, locker).
/// - Prepara base para reglas futuras (auth, deep links, app_links, etc).
///
/// Compatible con go_router v14+.
/// ===============================================================
final GoRouter router = GoRouter(
  // 👇 Pantalla de inicio
  initialLocation: '/',

  // ===============================================================
  // 🔹 LISTA COMPLETA DE RUTAS
  // ===============================================================
  routes: [
    // ---------------------------------------------------------------
    // 🟦 LOGIN (punto de entrada)
    // ---------------------------------------------------------------
    GoRoute(
      path: '/',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // ---------------------------------------------------------------
    // 🟦 Puerta lógica tras login
    // Maneja la redirección al feed, onboarding, etc.
    // ---------------------------------------------------------------
    GoRoute(
      path: '/profile-gate',
      name: 'profile-gate',
      builder: (context, state) => const ProfileGate(),
    ),

    // ---------------------------------------------------------------
    // 🟦 FEED (pantalla principal del MVP)
    // ---------------------------------------------------------------
    GoRoute(
      path: '/feed',
      name: 'feed',
      builder: (context, state) => const FeedPage(),
    ),

    // ---------------------------------------------------------------
    // 🟪 MÓDULO SOCIAL (comentarios, posts, perfiles sociales)
    // ---------------------------------------------------------------
    ...socialRoutes,

    // ---------------------------------------------------------------
    // 🛒 MÓDULO LOCKER (Marketplace completo)
    // ---------------------------------------------------------------
    ...lockerRoutes,
  ],

  // ===============================================================
  // 🔁 REDIRECCIONES CONDICIONALES (si activas auth)
  // ===============================================================
  redirect: (context, state) {
    // ⚠️ Inactivo por ahora, pero 100% funcional si quieres activarlo luego.
    //
    // final user = FirebaseAuth.instance.currentUser;
    // final isLoggingIn = state.matchedLocation == '/';
    //
    // if (user == null && !isLoggingIn) return '/';
    // if (user != null && isLoggingIn) return '/profile-gate';
    //
    return null;
  },

  // ===============================================================
  // 🧪 DEBUG / PÁGINA DE ERROR GLOBAL
  // ===============================================================
  debugLogDiagnostics: true,

  errorBuilder: (context, state) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Text(
        '⚠️ Ruta no encontrada:\n${state.uri}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    ),
  ),
);
