// 📦 Dependencias principales
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/services.dart';

// 🌐 Configuración de Firebase
import '../firebase_options.dart';

// 🎨 Tema visual global (nuevo Arena Pro)
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

// 🧩 Páginas del flujo
import '../features/auth/presentation/login_page.dart';
import '../features/profile/presentation/profile_gate.dart';
import '../features/feed/presentation/dashboard_page.dart';
import '../features/rooms/presentation/room_detail_page.dart';
import 'package:draftclub_mobile/features/rooms/models/room_model.dart';

// 🔗 Sistema de enlaces (deep links)
import 'package:app_links/app_links.dart';

/// ============================================================================
/// 🚀 PUNTO DE ENTRADA PRINCIPAL DE LA APLICACIÓN
/// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DraftClubApp());
}

/// ============================================================================
/// 🎯 DraftClubApp — Configuración global + manejo de deep links
/// ============================================================================
class DraftClubApp extends StatefulWidget {
  const DraftClubApp({super.key});

  @override
  State<DraftClubApp> createState() => _DraftClubAppState();
}

class _DraftClubAppState extends State<DraftClubApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  // 🔗 Inicializa el sistema de enlaces "draftclub://room/<ID>"
  Future<void> _initAppLinks() async {
    try {
      _appLinks = AppLinks();

      // Si la app se abrió desde un enlace (app cerrada)
      final initialUri = await _appLinks.getInitialLink();
      _sub = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleIncomingLink(uri);
      });

      // Si la app ya está abierta y llega un nuevo enlace
      _sub = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleIncomingLink(uri);
      }, onError: (err) {
        debugPrint('⚠️ Error al procesar deep link: $err');
      });
    } on PlatformException catch (e) {
      debugPrint('⚠️ Error al inicializar AppLinks: $e');
    }
  }

  /// 🧭 Maneja el enlace entrante y abre la sala real de Firestore
  Future<void> _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 Enlace recibido: $uri');

    if (uri.scheme == 'draftclub' && uri.host == 'room') {
      final roomId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;

      if (roomId != null && mounted) {
        // Loader mientras obtenemos la sala
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

          Navigator.of(context).pop(); // Cierra loader

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
            MaterialPageRoute(
              builder: (_) => RoomDetailPage(room: room),
            ),
          );
        } catch (e) {
          Navigator.of(context).pop();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DraftClub ⚽',
      theme: AppTheme.darkTheme, // 🎨 Aplica el nuevo tema Arena Pro
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
