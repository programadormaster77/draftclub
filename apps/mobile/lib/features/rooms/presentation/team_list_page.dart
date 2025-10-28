import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/room_model.dart';
import '../models/team_model.dart';
import '../data/team_service.dart';
import 'chat/chat_team_page.dart';
import 'team_detail_page.dart';

/// ====================================================================
/// 👥 TeamListPage — Equipos de la sala (tiempo real)
/// ====================================================================
/// 🔹 Muestra todos los equipos creados dentro de una sala.
/// 🔹 Permite unirse a un equipo (si hay cupo disponible).
/// 🔹 Muestra el equipo actual del usuario.
/// 🔹 Permite abrir el chat o ver el detalle del equipo.
/// 🔹 Diseño optimizado sin overflow ni saturación visual.
/// ====================================================================
class TeamListPage extends StatefulWidget {
  final Room room;
  const TeamListPage({super.key, required this.room});

  @override
  State<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends State<TeamListPage> {
  final _auth = FirebaseAuth.instance;
  final _service = TeamService();
  String? _myTeamId;
  bool _loadingJoin = false;

  @override
  void initState() {
    super.initState();
    _loadMyTeam();
  }

  /// 🔹 Obtiene el equipo actual del usuario desde Firestore
  Future<void> _loadMyTeam() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final id = await _service.getUserTeamId(widget.room.id, uid);
    if (mounted) setState(() => _myTeamId = id);
  }

  /// 🔹 Permite unirse o cambiar de equipo
  Future<void> _join(Team t) async {
    if (_loadingJoin) return;
    setState(() => _loadingJoin = true);

    try {
      final msg = await _service.joinTeam(roomId: widget.room.id, teamId: t.id);
      await _loadMyTeam(); // 🔁 actualiza el estado visual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.blueAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al unirse: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingJoin = false);
    }
  }

  /// 🔹 Abre el chat del equipo (solo si pertenece)
  void _openChat(Team t) {
    if (_myTeamId == t.id) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatTeamPage(
            roomId: widget.room.id,
            teamId: t.id,
            teamName: t.name,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solo puedes abrir el chat de tu equipo actual'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  /// 🔹 Abre los detalles del equipo (jugadores, chat, etc.)
  void _openTeamDetail(Team t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailPage(room: widget.room, team: t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Equipos'),
        elevation: 2,
      ),
      body: StreamBuilder<List<Team>>(
        stream: _service.streamTeams(room.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final teams = snap.data ?? [];
          if (teams.isEmpty) {
            return const Center(
              child: Text(
                'Aún no hay equipos creados.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final uid = _auth.currentUser?.uid;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: teams.length,
            itemBuilder: (_, i) {
              final t = teams[i];
              final isMine = _myTeamId == t.id;
              final fullText = '${t.count}/${t.maxPlayers}';

              return GestureDetector(
                onTap: () => _openTeamDetail(t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800, width: 0.8),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.groups, color: Colors.white),
                    ),

                    // ================== NOMBRE + INFO ==================
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isMine)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tu equipo',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Text(
                              'Jugadores: $fullText',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // ================== BOTONES DERECHA ==================
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (uid == null || (t.isFull && !isMine))
                                  ? null
                                  : () => _join(t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isMine ? Colors.grey : Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 10),
                                minimumSize: const Size(40, 38),
                              ),
                              child: FittedBox(
                                child: _loadingJoin && isMine
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isMine ? 'Seleccionado' : 'Unirme',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: Colors.white70),
                            tooltip: 'Chat del equipo',
                            onPressed: () => _openChat(t),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
