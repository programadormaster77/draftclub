import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SoccerFieldWidget extends StatelessWidget {
  final Map<String, String>
      playerPositions; // userId -> position (GK, DEF, MID, FWD)
  final List<String> allPlayers; // List of all userIds in the room
  final double width;
  final double height;
  final Function(String position)? onPositionTap;

  const SoccerFieldWidget({
    super.key,
    required this.playerPositions,
    required this.allPlayers,
    this.width = 330,
    this.height = 480,
    this.onPositionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: FieldPainter(),
          child: Stack(
            children: [
              // GOALKEEPER (bottom center)
              _buildPositionZone(context, 'GK', const Alignment(0.0, 0.85)),

              // DEFENDERS (row above GK)
              _buildPositionZone(context, 'DEF', const Alignment(-0.6, 0.45)),
              _buildPositionZone(context, 'DEF', const Alignment(0.6, 0.45)),
              _buildPositionZone(context, 'DEF', const Alignment(0.0, 0.45)),

              // MIDFIELDERS (middle row)
              _buildPositionZone(context, 'MID', const Alignment(-0.5, 0.0)),
              _buildPositionZone(context, 'MID', const Alignment(0.5, 0.0)),
              _buildPositionZone(context, 'MID', const Alignment(0.0, -0.1)),

              // FORWARDS (top row)
              _buildPositionZone(context, 'FWD', const Alignment(-0.4, -0.6)),
              _buildPositionZone(context, 'FWD', const Alignment(0.4, -0.6)),
              _buildPositionZone(context, 'FWD', const Alignment(0.0, -0.75)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionZone(
      BuildContext context, String position, Alignment alignment) {
    // 1. Filtrar jugadores que tienen esta posición
    final playersInPos = playerPositions.entries
        .where((e) => e.value == position)
        .map((e) => e.key)
        .toList();

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () => onPositionTap?.call(position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar o Placeholder
            _buildAvatarForPosition(playersInPos, position, alignment),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                position,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarForPosition(
      List<String> userIds, String position, Alignment alignment) {
    // Determinista: Slot index basado en alineación horizontal
    int slotIndex = 0;
    if (alignment.x < -0.1)
      slotIndex = 0; // Izquierda
    else if (alignment.x > 0.1)
      slotIndex = 1; // Derecha
    else
      slotIndex = 2; // Centro

    // Ajuste si hay más jugadores que slots "visuales"
    // Si tenemos 4 delanteros y solo 3 slots, el 4to se mostrará en el slot del centro (index 2)
    // O simplemente hacemos modulo si excede?
    if (userIds.length > 3) {
      slotIndex = slotIndex % userIds.length;
    }

    // Si no hay jugador para este slot específico
    if (slotIndex >= userIds.length) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
              style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add, color: Colors.white70, size: 20),
      );
    }

    final userId = userIds[slotIndex];

    return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          String? photoUrl;
          String initials = '?';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            photoUrl = data['photoUrl'];
            final name = data['name'] as String? ?? 'U';
            initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
          }

          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: (photoUrl != null && photoUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(photoUrl), fit: BoxFit.cover)
                  : null,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Center(
                    child: Text(initials,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)))
                : null,
          );
        });
  }
}

class FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Césped (Patrón de rayas)
    final grassPaint = Paint()..color = Colors.black.withOpacity(0.08);
    for (double i = 0; i < size.height; i += size.height / 10) {
      canvas.drawRect(
          Rect.fromLTWH(0, i, size.width, size.height / 20), grassPaint);
    }

    // Borde exterior
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Línea central
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Círculo central
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.15, paint);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);

    // Áreas
    final goalWidth = size.width * 0.45;
    final areaHeight = size.height * 0.15;
    final smallAreaHeight = size.height * 0.06;
    final smallAreaWidth = size.width * 0.22;

    // Área grande (Arriba)
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, 0),
          width: goalWidth,
          height: areaHeight * 2),
      paint,
    );
    // Área chica (Arriba)
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, 0),
          width: smallAreaWidth,
          height: smallAreaHeight * 2),
      paint,
    );

    // Área grande (Abajo)
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height),
          width: goalWidth,
          height: areaHeight * 2),
      paint,
    );
    // Área chica (Abajo)
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height),
          width: smallAreaWidth,
          height: smallAreaHeight * 2),
      paint,
    );

    // Arcos
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(size.width / 2, 0),
            width: goalWidth * 0.6,
            height: 40),
        0,
        3.14159,
        false,
        paint);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height),
            width: goalWidth * 0.6,
            height: 40),
        3.14159,
        3.14159,
        false,
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
