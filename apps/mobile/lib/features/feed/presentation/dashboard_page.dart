import 'package:flutter/material.dart';
import 'package:draftclub_mobile/features/social/presentation/page/social_feed_page.dart';
import 'package:draftclub_mobile/features/social/presentation/sheets/create_post_sheet.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_list_page.dart';
import 'package:draftclub_mobile/features/social/data/chat_service.dart';
import 'package:draftclub_mobile/features/rooms/presentation/rooms_page.dart';
import 'package:draftclub_mobile/features/rooms/presentation/create_room_page.dart';
import 'package:draftclub_mobile/features/tournaments/presentation/tournaments_page.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';

/// ====================================================================
/// 🧭 DashboardPage — Control global de navegación inferior (Versión PRO++)
/// ====================================================================
/// 🔹 Centro principal de la app después del login.
/// 🔹 Secciones: Feed, Salas, Crear (+), Torneos, Perfil.
/// 🔹 Ícono 💬 con contador de mensajes no leídos (solo en Inicio y Perfil).
/// 🔹 Transición fluida hacia ChatListPage.
/// 🔹 Diseño limpio, coherente y profesional.
/// ====================================================================

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ChatService _chatService = ChatService();
  int _currentIndex = 0;

  // ================================================================
  // 📄 PÁGINAS PRINCIPALES
  // ================================================================
  final List<Widget> _pages = const [
    SocialFeedPage(),  // 🏠 Inicio
    RoomsPage(),       // ⚽ Salas
    SizedBox(),        // (+) Crear
    TournamentsPage(), // 🏆 Torneos
    ProfilePage(),     // 👤 Perfil
  ];

  // ================================================================
  // 🏷️ TÍTULOS APPBAR
  // ================================================================
  final List<String> _titles = [
    'Inicio',
    'Salas',
    '',
    'Torneos',
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
                // 🏆 Crear torneo — futuro módulo
                // ===========================================================
                ListTile(
                  leading: const Icon(Icons.emoji_events,
                      color: Colors.amberAccent),
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
    final showChatIcon =
        currentTitle == 'Inicio' || currentTitle == 'Perfil';

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // ===================== APPBAR =====================
      appBar: currentTitle.isNotEmpty
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
                                      borderRadius: BorderRadius.circular(10),
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
          : null,

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
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events, color: Colors.blueAccent),
              label: 'Torneos',
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