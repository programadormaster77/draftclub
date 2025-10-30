import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ====================================================================
/// 📋 RosterSidePanel — Barra lateral / panel de plantilla del equipo
/// ====================================================================
/// - Muestra jugadores con avatar, nombre, rango y rol (Titular/Suplente)
/// - Se adapta: como sidebar en pantallas anchas y como sección vertical en móvil.
/// - Pensado para integrarse en TeamDetailPage bajo el campo táctico.
/// ====================================================================

class RosterSidePanel extends StatelessWidget {
  final List<String> titulares; // UIDs
  final List<String> suplentes; // UIDs
  final Color accent; // color del equipo
  final String roomId; // para acciones futuras (promover/expulsar)
  final bool isWide; // layout: true => columna lateral

  const RosterSidePanel({
    super.key,
    required this.titulares,
    required this.suplentes,
    required this.accent,
    required this.roomId,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? 320 : null,
      margin: EdgeInsets.symmetric(horizontal: isWide ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18), width: 1),
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
            _PlayersList(uids: titulares, accent: accent, badgeText: 'Titular'),
            const Divider(color: Colors.white12, height: 16, thickness: 0.6),
            _sectionTitle('Suplentes', accent),
            _PlayersList(
                uids: suplentes, accent: accent, badgeText: 'Suplente'),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.groups, color: accent),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: accent,
              )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              )),
        ],
      ),
    );
  }
}

class _PlayersList extends StatelessWidget {
  final List<String> uids;
  final Color accent;
  final String badgeText;

  const _PlayersList({
    required this.uids,
    required this.accent,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text('— Vacío —', style: TextStyle(color: Colors.white38)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
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
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final name = (data['name'] ?? 'Jugador') as String;
            final avatar = (data['avatar'] ?? '') as String;
            final rank = (data['rank'] ?? 'Bronce') as String;
            final pos = (data['position'] ?? '') as String; // opcional

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12, width: 0.6),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withOpacity(0.25),
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            _Badge(text: badgeText, color: accent),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(rank,
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                            if (pos.isNotEmpty)
                              Text('• $pos',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Botonera “stub” para futura moderación
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pronto: acciones para $name'),
                          backgroundColor: accent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.more_horiz, color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
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
