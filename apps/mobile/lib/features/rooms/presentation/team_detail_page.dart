import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/team_model.dart';
import '../data/team_service.dart';
import 'chat/chat_team_page.dart';

/// ====================================================================
/// 🧩 TeamDetailPage — Vista avanzada del equipo
/// ====================================================================
/// 🔹 Muestra información del equipo.
/// 🔹 Lista jugadores reales con nombre, avatar y rango.
/// 🔹 Permite salir del equipo.
/// 🔹 Permite editar nombre del equipo (si es creador/admin).
/// 🔹 Enlace directo al chat del equipo.
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

  /// 🔹 Actualiza el nombre del equipo en Firestore
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
          content: Text('Nombre del equipo actualizado.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar nombre: $e')),
      );
    }
  }

  /// 🔹 Salir del equipo actual
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

          final teamData = teamSnap.data!.data() as Map<String, dynamic>;
          final players = List<String>.from(teamData['players'] ?? []);
          final creatorId = teamData['creatorId'];
          final isCreator = currentUid == creatorId;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================== CABECERA DEL EQUIPO ==================
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade800, width: 0.8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: const Icon(Icons.groups, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _nameCtrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
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

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Jugadores en este equipo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ================== LISTA DE JUGADORES ==================
              Expanded(
                child: players.isEmpty
                    ? const Center(
                        child: Text(
                          'Aún no hay jugadores en este equipo.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: players)
                            .snapshots(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blueAccent),
                            );
                          }

                          final users = userSnap.data!.docs;

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white12),
                            itemCount: users.length,
                            itemBuilder: (_, i) {
                              final u = users[i].data() as Map<String, dynamic>;
                              final isMe = users[i].id == currentUid;
                              final name = u['name'] ?? 'Jugador';
                              final avatarUrl = u['avatar'] ?? '';
                              final rank = u['rank'] ?? 'Rango 1';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  backgroundColor:
                                      Colors.blueAccent.withOpacity(0.2),
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person,
                                          color: Colors.white)
                                      : null,
                                ),

                                // ================== NOMBRE + RANGO ==================
                                title: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      isMe ? '$name (Tú)' : name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blueAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        rank,
                                        style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),

                                subtitle: Text(
                                  users[i].id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),

                                // ================== ACCIONES DERECHA ==================
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    if (!isMe)
                                      IconButton(
                                        icon: const Icon(Icons.person_add_alt_1,
                                            color: Colors.white70, size: 20),
                                        tooltip:
                                            'Seguir jugador (próximamente)',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Pronto podrás seguir a $name'),
                                              backgroundColor:
                                                  Colors.blueAccent,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
