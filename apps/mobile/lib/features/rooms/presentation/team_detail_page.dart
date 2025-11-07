import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/room_model.dart';
import '../models/team_model.dart';
import '../data/team_service.dart';
import 'chat/chat_team_page.dart';
import '../../../core/ui/field_pitch_widget.dart';
import 'widgets/roster_side_panel.dart';

/// ====================================================================
/// 🧩 TeamDetailPage — Vista avanzada del equipo (Arena Pro)
/// ====================================================================
/// 🔹 Muestra info completa y visual del equipo.
/// 🔹 Integra fotos, nombres y rangos reales en el campo.
/// 🔹 Añade barra lateral de plantilla (RosterSidePanel).
/// 🔹 Diseño moderno, adaptable y profesional.
/// 🔹 Incluye compatibilidad con salas nuevas y fallback dinámico.
/// ====================================================================
class TeamDetailPage extends StatefulWidget {
  final Room room;
  final Team team;

  const TeamDetailPage({
    super.key,
    required this.room,
    required this.team,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _service = TeamService();

  bool _editingName = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.team.name;
  }

  // ================================================================
  // ✏️ Actualiza el nombre del equipo
  // ================================================================
  Future<void> _updateTeamName() async {
    try {
      await _firestore
          .collection('rooms')
          .doc(widget.room.id)
          .collection('teams')
          .doc(widget.team.id)
          .update({'name': _nameCtrl.text.trim()});
      setState(() => _editingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre del equipo actualizado correctamente.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar nombre: $e')),
      );
    }
  }

  // ================================================================
  // 🚪 Salir del equipo
  // ================================================================
  Future<void> _leaveTeam() async {
    await _service.leaveCurrentTeam(widget.room.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has salido del equipo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ================================================================
  // 🧠 Genera posiciones tácticas automáticas
  // ================================================================
  List<Map<String, double>> _generateLayout(int count) {
    final formations = <int, List<Map<String, double>>>{
      5: [
        {'x': 0.5, 'y': 0.1},
        {'x': 0.3, 'y': 0.35},
        {'x': 0.7, 'y': 0.35},
        {'x': 0.35, 'y': 0.75},
        {'x': 0.65, 'y': 0.75},
      ],
      7: [
        {'x': 0.5, 'y': 0.1},
        {'x': 0.3, 'y': 0.25},
        {'x': 0.7, 'y': 0.25},
        {'x': 0.2, 'y': 0.5},
        {'x': 0.8, 'y': 0.5},
        {'x': 0.35, 'y': 0.8},
        {'x': 0.65, 'y': 0.8},
      ],
      9: [
        {'x': 0.5, 'y': 0.08},
        {'x': 0.25, 'y': 0.25},
        {'x': 0.75, 'y': 0.25},
        {'x': 0.15, 'y': 0.45},
        {'x': 0.85, 'y': 0.45},
        {'x': 0.3, 'y': 0.65},
        {'x': 0.7, 'y': 0.65},
        {'x': 0.4, 'y': 0.85},
        {'x': 0.6, 'y': 0.85},
      ],
      11: [
        {'x': 0.5, 'y': 0.08},
        {'x': 0.25, 'y': 0.18},
        {'x': 0.75, 'y': 0.18},
        {'x': 0.15, 'y': 0.35},
        {'x': 0.85, 'y': 0.35},
        {'x': 0.3, 'y': 0.55},
        {'x': 0.7, 'y': 0.55},
        {'x': 0.2, 'y': 0.75},
        {'x': 0.8, 'y': 0.75},
        {'x': 0.4, 'y': 0.9},
        {'x': 0.6, 'y': 0.9},
      ],
    };
    return formations[count] ?? formations[5]!;
  }

  // ================================================================
  // 🔍 Funciones auxiliares
  // ================================================================
  String _getPhotoUrl(Map<String, dynamic> userData) {
    return (userData['photoUrl'] ??
            userData['avatar'] ??
            userData['pothoUrl'] ??
            '')
        .toString();
  }

  String _getRank(Map<String, dynamic> userData) {
    return (userData['rank'] ?? 'Bronce').toString();
  }

  // ================================================================
  // 🧩 INTERFAZ PRINCIPAL
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _editingName
            ? TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nuevo nombre...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _updateTeamName(),
              )
            : Text(widget.team.name),
        actions: [
          if (!_editingName)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              tooltip: 'Editar nombre del equipo',
              onPressed: () => setState(() => _editingName = true),
            ),
          IconButton(
            icon:
                const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
            tooltip: 'Chat del equipo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatTeamPage(
                    roomId: widget.room.id,
                    teamId: widget.team.id,
                    teamName: widget.team.name,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ======================== CONTENIDO PRINCIPAL ========================
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('rooms')
            .doc(widget.room.id)
            .collection('teams')
            .doc(widget.team.id)
            .snapshots(),
        builder: (context, teamSnap) {
          if (!teamSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final teamData = teamSnap.data!.data() ?? {};
          final team = Team.fromMap(teamData);
          final colorHex = team.color;
          final Color teamColor = _parseColor(colorHex);
          final players = List<String>.from(teamData['players'] ?? []);
          final isWide = MediaQuery.of(context).size.width >= 720;

          // ================================================================
          // 🔁 Fallback dinámico: si players está vacío, busca por teamId
          // ================================================================
          if (players.isEmpty) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rooms')
                  .doc(widget.room.id)
                  .collection('players')
                  .where('teamId', isEqualTo: widget.team.id)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent));
                }
                if (snap.data!.docs.isEmpty) {
                  return _emptyTeamLayout(teamColor);
                }

                final fallbackPlayers =
                    snap.data!.docs.map((d) => d.id.toString()).toList();

                return _buildMainLayout(
                    context, teamColor, isWide, fallbackPlayers);
              },
            );
          }

          // ================================================================
          // 🧩 Layout principal cuando players[] ya existe
          // ================================================================
          return _buildMainLayout(context, teamColor, isWide, players);
        },
      ),
    );
  }

  // ================================================================
  // 🧩 Layout principal (cancha + panel)
  // ================================================================
  Widget _buildMainLayout(BuildContext context, Color teamColor, bool isWide,
      List<String> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: teamColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: teamColor.withOpacity(0.3),
                child: const Icon(Icons.groups, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _nameCtrl.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                tooltip: 'Salir del equipo',
                onPressed: _leaveTeam,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ⚽ Campo sincronizado en tiempo real con Firestore
                      Expanded(
                        flex: 3,
                        child: FieldPitchWidget(
                          teamColor: teamColor,
                          roomId: widget.room.id,
                          teamId: widget.team.id,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 📋 Panel lateral (titulares/suplentes)
                      Expanded(
                        flex: 2,
                        child: RosterSidePanel(
                          titulares: players,
                          suplentes: const [],
                          accent: teamColor,
                          roomId: widget.room.id,
                          teamId: widget.team.id,
                          isWide: isWide,
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        FieldPitchWidget(
                          teamColor: teamColor,
                          roomId: widget.room.id,
                          teamId: widget.team.id,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: SingleChildScrollView(
                            child: RosterSidePanel(
                              titulares: players,
                              suplentes: const [],
                              accent: teamColor,
                              roomId: widget.room.id,
                              teamId: widget.team.id,
                              isWide: isWide,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // 🧩 Layout vacío (sin jugadores)
  // ================================================================
  Widget _emptyTeamLayout(Color teamColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: teamColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: teamColor.withOpacity(0.3),
                child: const Icon(Icons.groups, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _nameCtrl.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                tooltip: 'Salir del equipo',
                onPressed: _leaveTeam,
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Aún no hay jugadores en este equipo.',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // 🎨 Convierte código HEX a Color
  // ================================================================
  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
