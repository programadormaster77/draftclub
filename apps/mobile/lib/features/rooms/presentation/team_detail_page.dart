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
      body: StreamBuilder<DocumentSnapshot>(
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

          final teamData = teamSnap.data!.data() as Map<String, dynamic>? ?? {};
          final team = Team.fromMap(teamData);
          final colorHex = team.color;
          final Color teamColor = _parseColor(colorHex);
          final players = List<String>.from(teamData['players'] ?? []);

          final isWide = MediaQuery.of(context).size.width >= 720;

          return StreamBuilder<QuerySnapshot>(
            stream: players.isEmpty
                ? const Stream.empty()
                : _firestore
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: players)
                    .snapshots(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                );
              }

              final users = userSnap.data!.docs;
              final layout = _generateLayout(users.length);

              final playerData = List.generate(users.length, (i) {
                final u = users[i].data() as Map<String, dynamic>;
                return {
                  'uid': users[i].id,
                  'name': u['name'] ?? 'Jugador',
                  'avatar': u['avatar'] ?? '',
                  'rank': u['rank'] ?? 'Bronce',
                  'number': i + 1,
                  'x': layout[i % layout.length]['x'],
                  'y': layout[i % layout.length]['y'],
                };
              });

              final titulares = players; // simplificado, luego se separarán
              final suplentes = <String>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================== CABECERA ==================
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: teamColor.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: teamColor.withOpacity(0.3),
                          child:
                              const Icon(Icons.groups, color: Colors.white70),
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
                          icon: const Icon(Icons.exit_to_app,
                              color: Colors.redAccent),
                          tooltip: 'Salir del equipo',
                          onPressed: _leaveTeam,
                        ),
                      ],
                    ),
                  ),

                  // ================== CANCHA + PANEL ==================
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: FieldPitchWidget(
                                    teamColor: teamColor,
                                    players: playerData,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: RosterSidePanel(
                                    titulares: titulares,
                                    suplentes: suplentes,
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
                                    players: playerData,
                                  ),
                                  const SizedBox(height: 20),
                                  RosterSidePanel(
                                    titulares: titulares,
                                    suplentes: suplentes,
                                    accent: teamColor,
                                    roomId: widget.room.id,
                                    teamId: widget.team.id, // 👈 agrega esto
                                    isWide: isWide,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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
