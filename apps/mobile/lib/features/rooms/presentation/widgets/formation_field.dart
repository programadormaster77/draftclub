import 'package:flutter/material.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

/// ===============================================================
/// 🏟️ FormationField — Cancha visual con animaciones de entrada
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

  /// 🎯 Distribución base según número de jugadores
  List<Offset> _getFormationPositions() {
    switch (playersPerTeam) {
      case 5:
        return const [
          Offset(0.5, 0.1),
          Offset(0.3, 0.4),
          Offset(0.7, 0.4),
          Offset(0.35, 0.7),
          Offset(0.65, 0.7),
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
          Offset(0.5, 0.08),
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
        // Fondo del campo
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

        // Jugadores con animación
        ...List.generate(players.length, (i) {
          final p = players[i];
          final pos = positions[i % positions.length];
          final screenWidth = MediaQuery.of(context).size.width;
          final fieldHeight = 400.0;

          return AnimatedPositioned(
            duration: Duration(milliseconds: 600 + (i * 100)),
            curve: Curves.easeOutBack,
            left: pos.dx * screenWidth * 0.9 - 30,
            top: pos.dy * fieldHeight - 30,
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 800),
              child: _PlayerSlot(
                player: p,
                isMyTeam: isMyTeam,
                onTap: onTapPlayer,
              ),
            ),
          );
        }),

        // Suplentes (sin animación)
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
/// 🧍 _PlayerSlot — Jugador con glow, nombre lateral y animación
/// ===============================================================
class _PlayerSlot extends StatefulWidget {
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
  State<_PlayerSlot> createState() => _PlayerSlotState();
}

class _PlayerSlotState extends State<_PlayerSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        return const Color(0xFFCD7F32); // Bronce
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final avatarSize = widget.small ? 40.0 : 56.0;
    final rankColor =
        player.rank != null ? _rankColor(player.rank!) : Colors.white;
    final teamColor =
        widget.isMyTeam ? AppColors.accentBlue : AppColors.accentRed;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          children: [
            // Círculo con glow y foto
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: teamColor.withOpacity(0.6),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: teamColor,
                backgroundImage:
                    (player.photoUrl != null && player.photoUrl!.isNotEmpty)
                        ? NetworkImage(player.photoUrl!)
                        : null,
                onBackgroundImageError: (_, __) {},
                child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                    ? Text(
                        player.name.isNotEmpty
                            ? player.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 6),

            // Nombre horizontal centrado
            SizedBox(
              width: 80,
              child: Text(
                player.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.small ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  shadows: const [
                    Shadow(
                      offset: Offset(0.5, 0.5),
                      blurRadius: 1,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Rango
            if (player.rank != null && player.rank!.isNotEmpty)
              Text(
                player.rank!,
                style: TextStyle(
                  color: rankColor,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// 🟩 FieldLinesPainter — Líneas del campo
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
      Offset(size.width / 2, size.height / 2),
      size.width * 0.12,
      paint,
    );

    // Línea central
    canvas.drawLine(
      Offset(size.width / 2, 10),
      Offset(size.width / 2, size.height - 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// ===============================================================
/// 🧠 Modelo del jugador
/// ===============================================================
class PlayerSlotData {
  final String name;
  final String? photoUrl;
  final String? position;
  final String? rank;

  const PlayerSlotData({
    required this.name,
    this.photoUrl,
    this.position,
    this.rank,
  });
}
