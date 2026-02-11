import 'package:flutter/material.dart';
import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';
import 'package:draftclub_mobile/features/social/presentation/sheets/create_post_sheet.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_list_page.dart';
import 'package:draftclub_mobile/features/social/data/chat_service.dart';
import 'package:draftclub_mobile/features/rooms/presentation/rooms_page.dart';
import 'package:draftclub_mobile/features/rooms/presentation/create_room_page.dart';
import 'package:draftclub_mobile/features/tournaments/presentation/tournaments_page.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';

// ⭐ NUEVO IMPORT NECESARIO PARA LOCKER
import 'package:draftclub_mobile/features/locker/presentation/pages/locker_page.dart';

// ⭐⭐ NUEVOS IMPORTS PARA LEER match_history
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 🧭 DashboardPage — Control global de navegación inferior (Versión PRO++)
/// ====================================================================
/// 🔹 Centro principal de la app después del login.
/// 🔹 Secciones: Feed, Salas, Crear (+), Locker (nuevo), Perfil.
/// 🔹 Ícono 💬 con contador de mensajes no leídos (solo en Inicio y Perfil).
/// 🔹 Transición fluida hacia ChatListPage.
/// 🔹 Diseño limpio, coherente y profesional.
/// ====================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, String? highlightPostId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ChatService _chatService = ChatService();
  int _currentIndex = 0;

  // ================================================================
  // 🆕 PASO 2 — MOSTRAR TARJETA DE ÚLTIMO PARTIDO AL ENTRAR A LA APP
  // ================================================================

  @override
  void initState() {
    super.initState();
    _checkLastMatchAndShowCard(); // 👈 aquí se dispara la revisión de historial
  }

  /// Lee el último partido del usuario en `users/{uid}/match_history`
  /// y si `wasSeen == false`, muestra la tarjeta de victoria/derrota
  /// y lo marca como visto.
  Future<void> _checkLastMatchAndShowCard() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('match_history')
          .orderBy('timestamp',
              descending: true) // usamos el campo que guardaste
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final data = doc.data();

      final wasSeen = (data['wasSeen'] ?? false) as bool;
      if (wasSeen == true) {
        return; // ya se mostró antes, no se repite
      }

      final bool teamWon = (data['teamWon'] ?? false) as bool;
      final String teamName = (data['teamNameWon'] ?? 'Tu equipo')
          .toString(); // mismo campo que guardas

      // Esperamos un poco a que se pinte el Dashboard y luego mostramos la tarjeta
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (teamWon) {
          _showVictoryCard(teamName);
        } else {
          _showDefeatCard(teamName);
        }
      });

      // Marcar como visto
      await doc.reference.update({'wasSeen': true});
    } catch (e) {
      debugPrint('⚠️ Error leyendo match_history en Dashboard: $e');
    }
  }

  /// Tarjeta simple de victoria (puedes mejorar el diseño luego)
  void _showVictoryCard(String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF050812),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '🏆 ¡Victoria!',
          style:
              TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tu equipo **$teamName** ganó su último partido.\n\nSigue sumando partidos para subir de nivel en DraftClub.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cerrar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  /// Tarjeta simple de derrota
  void _showDefeatCard(String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF120508),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '❌ Derrota',
          style:
              TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'El equipo **$teamName** ganó ese partido.\n\nNo pasa nada, sigue jugando para mejorar tus estadísticas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // 📄 PÁGINAS PRINCIPALES — ACTUALIZADAS
  // ================================================================
  final List<Widget> _pages = const [
    SocialFeedPage(), // 🏠 Inicio
    RoomsPage(), // ⚽ Salas
    SizedBox(), // (+) Crear
    LockerPage(), // 🛒 Locker (nuevo)
    ProfilePage(), // 👤 Perfil
  ];

  // ================================================================
  // 🏷️ TÍTULOS APPBAR — ACTUALIZADOS
  // ================================================================
  final List<String> _titles = [
    'Inicio',
    'Salas',
    '',
    'Locker', // 🛒 reemplaza “Torneos”
    'Perfil',
  ];

  // ================================================================
  // 🔁 CONTROL DE NAVEGACIÓN
  // ================================================================
  void _onTabTapped(int index) {
    if (index == 2) {
      _openCreateModal();
    } else {
      setState(() => _currentIndex = index);
    }
  }

  // ================================================================
  // 🧩 MODAL DE CREACIÓN DE CONTENIDO
  // ================================================================
  void _openCreateModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              runSpacing: 12,
              children: [
                // ===========================================================
                // 📹 Subir clip — CreatePostSheet
                // ===========================================================
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blueAccent),
                  title: const Text(
                    'Subir clip',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.9,
                        minChildSize: 0.6,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (_, scrollCtrl) => SingleChildScrollView(
                          controller: scrollCtrl,
                          child: const CreatePostSheet(),
                        ),
                      ),
                    );
                  },
                ),

                // ===========================================================
                // ⚽ Crear sala — CreateRoomPage
                // ===========================================================
                ListTile(
                  leading: const Icon(Icons.sports_soccer,
                      color: Colors.greenAccent),
                  title: const Text(
                    'Crear sala',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateRoomPage(),
                      ),
                    );

                    if (result == true && mounted) {
                      setState(() => _currentIndex = 1); // Ir a Salas
                    }
                  },
                ),

                // ===========================================================
                // 🛍️ Publicar producto — Locker (Marketplace)
                // ===========================================================
                ListTile(
                  leading: const Icon(Icons.store_mall_directory_rounded,
                      color: Colors.purpleAccent),
                  title: const Text(
                    'Publicar producto (Locker)',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Sube productos de tu tienda o artículos deportivos',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/locker/admin/create');
                  },
                ),

                // ===========================================================
                // 🏆 Crear torneo — futuro módulo
                // ===========================================================
                ListTile(
                  leading:
                      const Icon(Icons.emoji_events, color: Colors.amberAccent),
                  title: const Text(
                    'Crear torneo',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: conectar con creación de torneo
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // 🖥️ INTERFAZ PRINCIPAL
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final currentTitle = _titles[_currentIndex];

    // Mostrar ícono de chat solo en Inicio o Perfil
    final showChatIcon = currentTitle == 'Inicio' || currentTitle == 'Perfil';

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // ===================== APPBAR =====================
      appBar: _currentIndex == 4
          ? null
          : (currentTitle.isNotEmpty
              ? AppBar(
                  backgroundColor: Colors.black,
                  elevation: 2,
                  centerTitle: false,
                  title: Text(
                    currentTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  actions: showChatIcon
                      ? [
                          StreamBuilder<int>(
                            stream: _chatService.getUnreadCount(),
                            builder: (context, snapshot) {
                              final unread = snapshot.data ?? 0;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline,
                                        color: Colors.white70),
                                    tooltip: 'Mensajes',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ChatListPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unread > 0)
                                    Positioned(
                                      right: 10,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          unread.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ]
                      : null,
                )
              : null),

      // ===================== CUERPO =====================
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),

      // ===================== BARRA INFERIOR =====================
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          border: Border(
            top: BorderSide(color: Colors.blueGrey, width: 0.2),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF111111),
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 13,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: Colors.blueAccent),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups, color: Colors.blueAccent),
              label: 'Salas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 38, color: Colors.blueAccent),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront, color: Colors.blueAccent),
              label: 'Locker',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person, color: Colors.blueAccent),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
