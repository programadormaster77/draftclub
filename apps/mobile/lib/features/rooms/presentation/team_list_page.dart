import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/room_model.dart';
import '../models/team_model.dart';
import '../data/team_service.dart';
import 'chat/chat_team_page.dart';
import 'team_detail_page.dart';

/// ====================================================================
/// 👥 TeamListPage — Equipos de la sala (versión mejorada)
/// ====================================================================
/// 🔹 Diseño vertical profesional, con tarjetas dinámicas.
/// 🔹 Muestra color del equipo, jugadores y botones claros.
/// 🔹 Indica si es tu equipo o si está lleno.
/// 🔹 Enlace directo al detalle o chat del equipo.
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

  /// ================================================================
  /// 🔹 Carga el equipo actual del usuario
  /// ================================================================
  Future<void> _loadMyTeam() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final id = await _service.getUserTeamId(widget.room.id, uid);
    if (mounted) setState(() => _myTeamId = id);
  }

  /// ================================================================
  /// 🔹 Permite unirse o cambiar de equipo (con redirección automática)
  /// ================================================================
  Future<void> _join(Team t) async {
    if (_loadingJoin) return;
    setState(() => _loadingJoin = true);

    try {
      final msg = await _service.joinTeam(
        roomId: widget.room.id,
        teamId: t.id,
      );

      await _loadMyTeam();

      if (!mounted) return;

      if (msg.toLowerCase().contains('te uniste')) {
        // ✅ Si se unió correctamente, lo redirige al panel del equipo
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TeamDetailPage(room: widget.room, team: t),
          ),
        );
      } else {
        // ⚠️ Si no fue unión exitosa, muestra el mensaje
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

  /// ================================================================
  /// 🔹 Abre el chat del equipo
  /// ================================================================
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

  /// ================================================================
  /// 🔹 Abre detalles del equipo
  /// ================================================================
  void _openTeamDetail(Team t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailPage(room: widget.room, team: t),
      ),
    );
  }

  /// ================================================================
  /// 🎨 Convierte HEX a Color
  /// ================================================================
  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Equipos — ${room.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (_, i) {
              final t = teams[i];
              final isMine = _myTeamId == t.id;
              final isFull = t.isFull;
              final color = _parseColor(t.color);
              final fullText = '${t.count}/${t.maxPlayers}';

              return GestureDetector(
                onTap: () => _openTeamDetail(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.12),
                        Colors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          isMine ? Colors.blueAccent : color.withOpacity(0.35),
                      width: isMine ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isMine)
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============ ENCABEZADO ============ //
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withOpacity(0.4),
                                child: const Icon(Icons.groups,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                t.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (isMine)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.blueAccent, width: 1),
                              ),
                              child: const Text(
                                'TU EQUIPO',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ============ INFO LINEA ============ //
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jugadores: $fullText',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            isFull ? 'Equipo completo' : 'Disponible',
                            style: TextStyle(
                              color: isFull
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ============ BOTONES ============ //
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: (uid == null ||
                                      (isFull && !isMine) ||
                                      room.phase == 'finished')
                                  ? null
                                  : () => _join(t),
                              icon: Icon(
                                isMine ? Icons.check_circle : Icons.login,
                                size: 18,
                              ),
                              label: Text(
                                isMine
                                    ? 'Seleccionado'
                                    : (isFull ? 'Lleno' : 'Unirme'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMine
                                    ? Colors.grey
                                    : (isFull
                                        ? Colors.redAccent.withOpacity(0.6)
                                        : Colors.blueAccent),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: () => _openChat(t),
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 18),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // 🏆 Widget de Resultado en la Tarjeta
  // ================================================================
  Widget _buildMatchResult(Room room, int index, Team team) {
    // Asumimos index 0 = Team A, index 1 = Team B
    final scoreA = room.scoreTeamA ?? 0;
    final scoreB = room.scoreTeamB ?? 0;

    int myScore = 0;
    int opponentScore = 0;
    bool isWinner = false;
    bool isDraw = scoreA == scoreB;

    if (index == 0) {
      myScore = scoreA;
      opponentScore = scoreB;
      isWinner = scoreA > scoreB;
    } else {
      myScore = scoreB;
      opponentScore = scoreA;
      isWinner = scoreB > scoreA;
    }

    if (isDraw) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.handshake, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              'EMPATE ($myScore - $opponentScore)',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isWinner) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              'GANADOR ($myScore - $opponentScore)',
              style: const TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.thumb_down_off_alt,
                color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text(
              'PERDEDOR ($myScore - $opponentScore)',
              style: const TextStyle(
                  color: Colors.white38, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
  }
}
