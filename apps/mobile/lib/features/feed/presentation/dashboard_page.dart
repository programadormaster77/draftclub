import 'package:flutter/material.dart';
import '../../rooms/presentation/rooms_page.dart';
import '../../rooms/presentation/create_room_page.dart';
import '../../tournaments/presentation/tournaments_page.dart';
import '../../profile/presentation/profile_page.dart';
import 'feed_page.dart';

/// ====================================================================
/// 🧭 DashboardPage — Control principal de navegación inferior
/// ====================================================================
/// 🔹 Raíz visual tras el login.
/// 🔹 Contiene las secciones principales y la barra inferior.
/// 🔹 El botón central abre un modal con opciones de creación.
/// 🔹 Conecta directamente con CreateRoomPage.
/// 🔹 Refresca automáticamente RoomsPage al volver.
/// ====================================================================
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  // ================================================================
  // 📄 PÁGINAS PRINCIPALES
  // ================================================================
  final List<Widget> _pages = const [
    FeedPage(),
    RoomsPage(),
    SizedBox(), // botón central → modal de creación
    TournamentsPage(),
    ProfilePage(),
  ];

  // ================================================================
  // 🏷️ TÍTULOS PARA EL APPBAR
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
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blueAccent),
                  title: const Text(
                    'Subir clip',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: conectar con pantalla de subida de clips
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sports_soccer,
                      color: Colors.greenAccent),
                  title: const Text(
                    'Crear sala',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    // ✅ Navegar a CreateRoomPage y refrescar Salas al volver
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateRoomPage(),
                      ),
                    );

                    // Si se creó una sala, forzamos actualización en RoomsPage
                    if (result == true && mounted) {
                      setState(() {
                        _currentIndex = 1; // Cambia a "Salas"
                      });
                    }
                  },
                ),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // ===================== APPBAR DINÁMICO =====================
      appBar: currentTitle.isNotEmpty
          ? AppBar(
              title: Text(
                currentTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.black,
              elevation: 2,
              centerTitle: false,
            )
          : null,

      // ===================== CUERPO DINÁMICO =====================
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),

      // ===================== BARRA DE NAVEGACIÓN =====================
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
