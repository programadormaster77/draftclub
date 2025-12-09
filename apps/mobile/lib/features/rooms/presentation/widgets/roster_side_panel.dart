import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/team_service.dart';

/// ====================================================================
/// 📋 RosterSidePanel — Versión PRO (sin bugs de layout)
/// ====================================================================
/// - Avatar circular con borde dinámico.
/// - Nombre, rango y posición.
/// - Menú admin (mover titular/suplente/expulsar).
/// - Lee correctamente `fotoUrl`.
/// - Incluye Historial del equipo.
/// ====================================================================

class RosterSidePanel extends StatelessWidget {
  final List<String> titulares;
  final List<String> suplentes;
  final Color accent;
  final String roomId;
  final String teamId;
  final bool isWide;

  const RosterSidePanel({
    super.key,
    required this.titulares,
    required this.suplentes,
    required this.accent,
    required this.roomId,
    required this.teamId,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? 320 : null,
      margin: EdgeInsets.symmetric(horizontal: isWide ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header('Plantilla', accent),
            _sectionTitle('Titulares', accent),
            _PlayersList(
              uids: titulares,
              accent: accent,
              badgeText: 'Titular',
              roomId: roomId,
              teamId: teamId,
            ),
            const Divider(color: Colors.white12, height: 20, thickness: 0.6),
            _sectionTitle('Suplentes', accent),
            _PlayersList(
              uids: suplentes,
              accent: accent,
              badgeText: 'Suplente',
              roomId: roomId,
              teamId: teamId,
            ),
            _logsTile(roomId, accent),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.18), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.groups, color: accent),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logsTile(String roomId, Color accent) {
    return Theme(
      data: ThemeData().copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: accent,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Icon(Icons.history, color: accent, size: 18),
            const SizedBox(width: 8),
            const Text('Historial del equipo',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        children: [
          SizedBox(
            height: 160,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(roomId)
                  .collection('system_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                final items = snap.data!.docs;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('— Sin eventos aún —',
                        style: TextStyle(color: Colors.white38)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final d = items[i].data() as Map<String, dynamic>;
                    final msg = (d['message'] ?? '').toString();
                    final ts = d['timestamp'];
                    final time =
                        (ts is Timestamp) ? _formatTime(ts.toDate()) : '';
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$msg  •  $time',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PlayersList extends StatelessWidget {
  final List<String> uids;
  final Color accent;
  final String badgeText;
  final String roomId;
  final String teamId;

  const _PlayersList({
    required this.uids,
    required this.accent,
    required this.badgeText,
    required this.roomId,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text('— Vacío —', style: TextStyle(color: Colors.white38)),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('rooms').doc(roomId).get(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          );
        }

        final data = roomSnap.data?.data();
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final roomOwner = data?['ownerId'];
        final isAdmin = (currentUid != null &&
            roomOwner != null &&
            currentUid == roomOwner);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: uids)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              );
            }

            final docs = snap.data!.docs;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final uid = docs[i].id;
                final data = docs[i].data();
                final name = (data['name'] ?? 'Jugador') as String;
                final avatar =
                    (data['pothoUrl'] ?? data['avatar'] ?? '') as String;
                final rank = (data['rank'] ?? 'Bronce') as String;
                final pos = (data['position'] ?? '') as String;

                return _PlayerCard(
                  uid: uid,
                  name: name,
                  avatar: avatar,
                  rank: rank,
                  position: pos,
                  badgeText: badgeText,
                  accent: accent,
                  isAdmin: isAdmin,
                  roomId: roomId,
                  teamId: teamId,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ====================================================================
// 🎨 _PlayerCard — Versión PRO (minimalista + neón + apodo)
// ====================================================================
class _PlayerCard extends StatelessWidget {
  final String uid;
  final String name;
  final String avatar;
  final String rank;
  final String position;
  final String badgeText;
  final Color accent;
  final bool isAdmin;
  final String roomId;
  final String teamId;

  const _PlayerCard({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.rank,
    required this.position,
    required this.badgeText,
    required this.accent,
    required this.isAdmin,
    required this.roomId,
    required this.teamId,
  });

  // 🎖 Color según rango
  Color _rankColor(String rank) {
    switch (rank.toLowerCase()) {
      case 'oro':
        return const Color(0xFFFFD700);
      case 'plata':
        return const Color(0xFFC0C0C0);
      case 'platino':
        return const Color(0xFF00C5D8);
      case 'diamante':
        return const Color(0xFF7DF9FF);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  // 🔍 Detecta nickname o fallback
  String _detectNickname(Map<String, dynamic> data) {
    return (data['nickname'] ?? data['apodo'] ?? data['name'] ?? "Jugador")
        .toString();
  }

  // 🔍 Detecta URL de foto (4 estándares distintos)
  String _detectAvatar(Map<String, dynamic> data) {
    return (data['photoUrl'] ??
            data['avatar'] ??
            data['fotourl'] ??
            data['pothoUrl'] ??
            "")
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColor(rank);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.data() ?? {};
        final nickname = _detectNickname(data);
        final photo = _detectAvatar(data);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // ================= AVATAR =================
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.black,
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? Text(
                          nickname.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(width: 12),

              // ================= INFO =================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Apodo (principal)
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    // Nombre + posición
                    Text(
                      "$name${position.isNotEmpty ? " • $position" : ""}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // BADGES
                    Row(
                      children: [
                        _Badge(text: badgeText, color: accent),
                        const SizedBox(width: 6),
                        _Badge(text: rank, color: rankColor),
                      ],
                    ),
                  ],
                ),
              ),

              // ================= MENÚ ADMIN =================
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  onSelected: (value) async {
                    final service = TeamService();
                    if (value == "titular") {
                      await service.promoteToStarter(
                        roomId: roomId,
                        teamId: teamId,
                        uid: uid,
                      );
                    } else if (value == "suplente") {
                      await service.demoteToBench(
                        roomId: roomId,
                        teamId: teamId,
                        uid: uid,
                      );
                    } else if (value == "expulsar") {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1C1C1C),
                          title: const Text("¿Expulsar jugador?",
                              style: TextStyle(color: Colors.white)),
                          content: Text(
                            "Jugador: $name",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancelar"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Expulsar"),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        await service.removePlayerFromTeam(
                          roomId: roomId,
                          teamId: teamId,
                          uid: uid,
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: "titular", child: Text("Mover a titular")),
                    PopupMenuItem(
                        value: "suplente", child: Text("Mover a suplente")),
                    PopupMenuItem(
                      value: "expulsar",
                      child: Text("Expulsar jugador",
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String name;
  final Color accent;
  const _FallbackAvatar({required this.name, required this.accent});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      color: accent.withOpacity(0.9),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.45), width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
