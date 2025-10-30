import 'package:flutter/material.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

/// ===============================================================
/// 🏟️ FormationField — Cancha visual para ubicar jugadores
/// ===============================================================
/// Muestra una cancha con posiciones dinámicas según el tipo
/// de sala (Fútbol 5, 7, 9 o 11). Admite portero, defensa,
/// medio y delanteros, más suplentes.
/// ===============================================================
class FormationField extends StatelessWidget {
  final int playersPerTeam;
  final List<PlayerSlotData> players;
  final List<PlayerSlotData> substitutes;
  final bool isMyTeam;
  final VoidCallback? onTapPlayer;

  const FormationField({
    super.key,
    required this.playersPerTeam,
    required this.players,
    required this.substitutes,
    this.isMyTeam = true,
    this.onTapPlayer,
  });

  /// =======================
  /// 🎯 Distribución base
  /// =======================
  List<Offset> _getFormationPositions() {
    switch (playersPerTeam) {
      case 5: // Portero + 2 defensas + 2 delanteros
        return const [
          Offset(0.5, 0.1), // Portero
          Offset(0.3, 0.4), // Defensa izq
          Offset(0.7, 0.4), // Defensa der
          Offset(0.35, 0.7), // Delantero izq
          Offset(0.65, 0.7), // Delantero der
        ];

      case 7:
        return const [
          Offset(0.5, 0.1),
          Offset(0.25, 0.35),
          Offset(0.75, 0.35),
          Offset(0.4, 0.55),
          Offset(0.6, 0.55),
          Offset(0.3, 0.75),
          Offset(0.7, 0.75),
        ];

      case 9:
        return const [
          Offset(0.5, 0.1),
          Offset(0.3, 0.25),
          Offset(0.7, 0.25),
          Offset(0.2, 0.45),
          Offset(0.5, 0.45),
          Offset(0.8, 0.45),
          Offset(0.3, 0.7),
          Offset(0.7, 0.7),
          Offset(0.5, 0.85),
        ];

      case 11:
      default:
        return const [
          Offset(0.5, 0.08), // Portero
          Offset(0.2, 0.25),
          Offset(0.4, 0.25),
          Offset(0.6, 0.25),
          Offset(0.8, 0.25),
          Offset(0.3, 0.5),
          Offset(0.7, 0.5),
          Offset(0.25, 0.7),
          Offset(0.5, 0.7),
          Offset(0.75, 0.7),
          Offset(0.5, 0.9),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = _getFormationPositions();

    return Stack(
      children: [
        // Fondo de la cancha
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade800,
                Colors.green.shade600,
                Colors.green.shade800,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Colors.white24, width: 1.2),
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        // Líneas del campo
        CustomPaint(
          painter: _FieldLinesPainter(),
          size: Size.infinite,
        ),

        // Jugadores en sus posiciones
        ...List.generate(players.length, (i) {
          final p = players[i];
          final pos = positions[i % positions.length];
          return Positioned(
            left: pos.dx * MediaQuery.of(context).size.width * 0.9 - 30,
            top: pos.dy * 400 - 30,
            child: _PlayerSlot(
              player: p,
              isMyTeam: isMyTeam,
              onTap: onTapPlayer,
            ),
          );
        }),

        // Suplentes
        if (substitutes.isNotEmpty)
          Positioned(
            right: 4,
            top: 8,
            child: Column(
              children: substitutes
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _PlayerSlot(
                        player: p,
                        isMyTeam: isMyTeam,
                        small: true,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// ===============================================================
/// 🧍 _PlayerSlot — Tarjeta visual del jugador
/// ===============================================================
class _PlayerSlot extends StatelessWidget {
  final PlayerSlotData player;
  final bool isMyTeam;
  final VoidCallback? onTap;
  final bool small;

  const _PlayerSlot({
    required this.player,
    required this.isMyTeam,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = small ? 40.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor:
                isMyTeam ? AppColors.accentBlue : AppColors.accentRed,
            backgroundImage:
                player.photoUrl != null ? NetworkImage(player.photoUrl!) : null,
            child: player.photoUrl == null
                ? Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            player.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(
                    offset: Offset(0.5, 0.5),
                    blurRadius: 1,
                    color: Colors.black54)
              ],
            ),
          ),
          if (player.position != null)
            Text(
              player.position!,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// 🟩 FieldLinesPainter — Dibuja las líneas de la cancha
/// ===============================================================
class _FieldLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRect(rect, paint);

    // Círculo central
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.12, paint);

    // Línea central
    canvas.drawLine(Offset(size.width / 2, 10),
        Offset(size.width / 2, size.height - 10), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// ===============================================================
/// 🧠 Modelo del jugador (solo para renderizar)
/// ===============================================================
class PlayerSlotData {
  final String name;
  final String? photoUrl;
  final String? position;

  const PlayerSlotData({
    required this.name,
    this.photoUrl,
    this.position,
  });
}
