import 'package:flutter/material.dart';

/// ====================================================================
/// ⚽ FieldPitchWidget — Diseño horizontal con avatares reales
/// ====================================================================
/// - Jugadores ordenados en líneas (portero, defensa, medio, ataque)
/// - Compatible con fotos, nombres y rangos
/// - Optimizado para pantallas móviles (layout horizontal limpio)
/// ====================================================================
class FieldPitchWidget extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Color teamColor;

  const FieldPitchWidget({
    super.key,
    required this.players,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.9;
    final height = width * 0.55;

    // 🔹 Agrupamos jugadores por líneas tácticas según su índice
    final layout = _generateHorizontalFormation(players.length);

    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: teamColor.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          children: [
            CustomPaint(size: Size(width, height), painter: _PitchPainter()),
            ...layout.map((p) => _buildPlayer(p, width, height)).toList(),
          ],
        ),
      ),
    );
  }

  /// ====================================================================
  /// 🎯 Genera posiciones horizontales (portero a delanteros)
  /// ====================================================================
  List<Map<String, dynamic>> _generateHorizontalFormation(int count) {
    // Estructura táctica simple 1-2-3-2-1 (para hasta 9 jugadores)
    final basePositions = [
      {'x': 0.05, 'y': 0.5}, // Portero
      {'x': 0.25, 'y': 0.3}, // Defensas
      {'x': 0.25, 'y': 0.7},
      {'x': 0.45, 'y': 0.2}, // Medios
      {'x': 0.45, 'y': 0.5},
      {'x': 0.45, 'y': 0.8},
      {'x': 0.65, 'y': 0.35}, // Delanteros
      {'x': 0.65, 'y': 0.65},
      {'x': 0.85, 'y': 0.5}, // Extremo o punta
    ];

    return List.generate(count, (i) {
      final pos = basePositions[i % basePositions.length];
      return {
        ...players[i],
        'x': pos['x'],
        'y': pos['y'],
      };
    });
  }

  /// ====================================================================
  /// 👤 Construye cada jugador en el campo
  /// ====================================================================
  Widget _buildPlayer(Map<String, dynamic> p, double w, double h) {
    final double x = (p['x'] ?? 0.5) * w;
    final double y = (p['y'] ?? 0.5) * h;
    final String name = p['name'] ?? '';
    final String rank = p['rank'] ?? '';
    final String avatar = p['avatar'] ?? '';
    final int number = p['number'] ?? 0;

    return Positioned(
      left: x - 24,
      top: y - 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: teamColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackCircle(number),
                    )
                  : _fallbackCircle(number),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (rank.isNotEmpty)
            Text(
              rank,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: teamColor.withOpacity(0.9),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackCircle(int number) {
    return Container(
      color: teamColor.withOpacity(0.9),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// ====================================================================
/// 🎨 _PitchPainter — Cancha horizontal elegante
/// ====================================================================
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;

    // Contorno
    final fieldRect = Rect.fromLTWH(8, 8, w - 16, h - 16);
    canvas.drawRRect(
        RRect.fromRectAndRadius(fieldRect, const Radius.circular(16)), paint);

    // Línea central
    canvas.drawLine(Offset(w / 2, 8), Offset(w / 2, h - 8), paint);

    // Círculo central
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.15, paint);

    // Áreas pequeñas
    canvas.drawRect(Rect.fromLTWH(8, h * 0.3, w * 0.08, h * 0.4), paint);
    canvas.drawRect(
        Rect.fromLTWH(w - w * 0.08 - 8, h * 0.3, w * 0.08, h * 0.4), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
