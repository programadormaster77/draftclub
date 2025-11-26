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

// 💬 Módulo Chat (Mensajería)
import '../features/chat/presentation/chat_page.dart';

/// ===============================================================
/// 🚦 Router global de DraftClub
/// ===============================================================
/// Control central de navegación:
/// - Maneja login / profile gate.
/// - Integra todos los módulos (feed, social, locker, chat).
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
    // 🟦 LOGIN
    // ---------------------------------------------------------------
    GoRoute(
      path: '/',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    // ---------------------------------------------------------------
    // 🟦 Profile Gate (decide a dónde enviarte después de login)
    // ---------------------------------------------------------------
    GoRoute(
      path: '/profile-gate',
      name: 'profile-gate',
      builder: (context, state) => const ProfileGate(),
    ),

    // ---------------------------------------------------------------
    // 🟦 FEED PRINCIPAL
    // ---------------------------------------------------------------
    GoRoute(
      path: '/feed',
      name: 'feed',
      builder: (context, state) => const FeedPage(),
    ),

    // ---------------------------------------------------------------
    // 💬 CHAT (NUEVO — evita el error de "no generator for /chat")
    // ---------------------------------------------------------------
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) {
        final chatId = state.uri.queryParameters['chatId'];
        return ChatPage(chatId: chatId);
      },
    ),

    // ---------------------------------------------------------------
    // 🟥 CHAT INDIVIDUAL (con ID en path /chat/1234)
    // ---------------------------------------------------------------
    GoRoute(
      path: '/chat/:chatId',
      name: 'chat-detail',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId']!;
        return ChatPage(chatId: chatId);
      },
    ),

    // ---------------------------------------------------------------
    // 🟪 MÓDULO SOCIAL
    // ---------------------------------------------------------------
    ...socialRoutes,

    // ---------------------------------------------------------------
    // 🛒 MÓDULO LOCKER
    // ---------------------------------------------------------------
    ...lockerRoutes,
  ],

  // ===============================================================
  // 🔁 REDIRECCIONES OPCIONALES (auth)
  // ===============================================================
  redirect: (context, state) {
    // Desactivado de momento
    return null;
  },

  // ===============================================================
  // 🧪 DEBUG / ERROR GLOBAL
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
