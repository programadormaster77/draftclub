// 📦 Dependencias principales
import 'package:draftclub_mobile/features/notifications/services/topic_manage.dart';
import 'package:draftclub_mobile/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Riverpod base
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:draftclub_mobile/features/profile/domain/xp_bootstrap.dart';
import 'package:draftclub_mobile/features/notifications/presentation/admin_notification_page.dart';

// 🌐 Configuración de Firebase

// 🎨 Tema visual global (nuevo Arena Pro)
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

// 🧩 Páginas del flujo
import 'package:draftclub_mobile/features/auth/presentation/login_page.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_gate.dart';
import 'package:draftclub_mobile/features/feed/presentation/dashboard_page.dart';
import 'package:draftclub_mobile/features/rooms/presentation/room_detail_page.dart';
import 'package:draftclub_mobile/features/rooms/models/room_model.dart';

// 🔔 Servicios de notificaciones (nuevo módulo)
import 'package:draftclub_mobile/features/notifications/services/fcm_service.dart';
import 'package:draftclub_mobile/features/notifications/services/local_notification_service.dart';

// 🛒 IMPORTANTE → necesarias para Navigator.push()
import 'package:draftclub_mobile/features/locker/presentation/pages/locker_cart_page.dart';
import 'package:draftclub_mobile/features/locker/admin/locker_admin_page.dart';

/// ============================================================================
/// 🚀 PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
/// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 Inicializamos notificaciones locales
  await LocalNotificationService.initialize();

  // 🧩 Inicializa servicios globales
  await LocalNotificationService.initialize();
  await FcmService.initialize();

  // ProviderScope global
  runApp(
    const ProviderScope(
      child: DraftClubApp(),
    ),
  );
}

/// ============================================================================
/// 🎯 DraftClubApp — Configuración global + manejo de deep links + notificaciones
/// ============================================================================
class DraftClubApp extends StatefulWidget {
  const DraftClubApp({super.key});

  @override
  State<DraftClubApp> createState() => _DraftClubAppState();
}

class _DraftClubAppState extends State<DraftClubApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  StreamSubscription<Uri>? _notifSub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _listenNotificationLinks();
  }

  // 🔗 Inicializa el sistema de deep links
  Future<void> _initAppLinks() async {
    try {
      _appLinks = AppLinks();

      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingLink(initialUri);

      _sub = _appLinks.uriLinkStream.listen(
        (Uri uri) => _handleIncomingLink(uri),
        onError: (err) => debugPrint('⚠️ Error al procesar deep link: $err'),
      );
    } on PlatformException catch (e) {
      debugPrint('⚠️ Error al inicializar AppLinks: $e');
    }
  }

  void _listenNotificationLinks() {
    _notifSub = FcmService.linkStream.listen(
      (Uri uri) {
        debugPrint('🔔 Deep link recibido desde notificación: $uri');
        _handleIncomingLink(uri);
      },
      onError: (err) =>
          debugPrint('⚠️ Error al procesar enlace de notificación: $err'),
    );
  }

  /// 🧭 Manejo de enlaces entrantes
  Future<void> _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 Enlace recibido: $uri');

    if (uri.scheme == 'draftclub' && uri.host == 'room') {
      final roomId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;

      if (roomId != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        );

        try {
          final snap = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(roomId)
              .get();

          if (!mounted) return;
          Navigator.of(context).pop();

          if (!snap.exists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ No se encontró la sala con ese ID.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          final data = snap.data()!;
          final room = Room.fromMap(data);

          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
          );
        } catch (e) {
          if (mounted) Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abrir la sala: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DraftClub ⚽',
      theme: AppTheme.darkTheme,
      routes: {
        '/admin_notifications': (context) => const AdminNotificationPage(),
      },
      home: const AuthStateHandler(),
    );
  }
}

/// ============================================================================
/// 🔐 AuthStateHandler — Controla el flujo global de autenticación
/// ============================================================================
class AuthStateHandler extends StatelessWidget {
  const AuthStateHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(text: 'Verificando sesión...');
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginPage();
        }

        final user = authSnapshot.data!;
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        return StreamBuilder<DocumentSnapshot>(
          stream: userDoc.snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(text: 'Cargando tu perfil...');
            }

            if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
              return const ProfileGate();
            }

            XPBootstrap.ensureUserXP();

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!FcmService.isInitialized) {
                await FcmService.initialize();
              }

              await TopicManager.syncUserTopics(user.uid);
            });

            return const DashboardPage();
          },
        );
      },
    );
  }
}

/// ============================================================================
/// ⏳ _LoadingScreen — Pantalla de carga reutilizable
/// ============================================================================
class _LoadingScreen extends StatelessWidget {
  final String text;
  const _LoadingScreen({required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 18),
            Text(
              text,
              style: AppTextStyles.subtitle,
            ),
          ],
        ),
      ),
    );
  }
}
