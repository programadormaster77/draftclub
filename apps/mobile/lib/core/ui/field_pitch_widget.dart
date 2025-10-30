import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ====================================================================
/// ⚽ FieldPitchWidget — Versión PRO (vertical, responsivo, centrífugo)
/// ====================================================================
/// - Foto real o inicial.
/// - Nombre + rango en vertical, orientados hacia el centro del campo.
/// - Escala automática para 5/7/9/11 jugadores.
/// - Anti-desbordes y sombras sutiles.
/// ====================================================================
class FieldPitchWidget extends StatelessWidget {
  final List<Map<String, dynamic>> players; // {uid, name, rank, avatar, x, y}
  final Color teamColor;

  const FieldPitchWidget({
    super.key,
    required this.players,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    // Caja del campo (relación 16:9 aprox, se adapta a móvil)
    final screenW = MediaQuery.of(context).size.width;
    final width = screenW * 0.92;
    final height = width * 0.56;

    // Distribución táctica base si no viene x/y
    final layout = _ensureLayout(players);

    // Escala por densidad: 11 jugadores => elementos más pequeños
    final density = layout.length.clamp(5, 11);
    final scale = _lerp(1.0, 0.78, (density - 5) / 6.0); // 5 =>1.0, 11 =>0.78
    final avatarSize = 56.0 * scale;
    final labelGap = 10.0 * scale; // separación avatar <-> etiqueta
    final labelMax = 80.0 * scale; // alto asignado a etiqueta vertical
    final sidePadding = 10.0; // margen para evitar corte en bordes

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
              color: teamColor.withOpacity(0.20),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            CustomPaint(size: Size(width, height), painter: _PitchPainter()),
            // Jugadores
            ...layout.map((p) => _buildPlayer(
                  p,
                  fieldW: width,
                  fieldH: height,
                  avatarSize: avatarSize,
                  labelGap: labelGap,
                  labelMax: labelMax,
                  sidePadding: sidePadding,
                )),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Si no hay x/y en players, generar una formación 1-2-3-2-1
  // ------------------------------------------------------------------
  List<Map<String, dynamic>> _ensureLayout(List<Map<String, dynamic>> list) {
    final needGen = list.any((p) => p['x'] == null || p['y'] == null);
    if (!needGen) return list;

    final gen = _generateHorizontalFormation(list.length);
    return List.generate(list.length, (i) {
      return {
        ...list[i],
        'x': gen[i]['x'],
        'y': gen[i]['y'],
      };
    });
  }

  /// Formación horizontal simple 1-2-3-2-1 (hasta 11)
  List<Map<String, double>> _generateHorizontalFormation(int count) {
    final base = <Map<String, double>>[
      {'x': 0.06, 'y': 0.50}, // Portero
      {'x': 0.23, 'y': 0.28}, {'x': 0.23, 'y': 0.72},
      {'x': 0.42, 'y': 0.18}, {'x': 0.42, 'y': 0.50}, {'x': 0.42, 'y': 0.82},
      {'x': 0.62, 'y': 0.34}, {'x': 0.62, 'y': 0.66},
      {'x': 0.82, 'y': 0.22}, {'x': 0.82, 'y': 0.50}, {'x': 0.82, 'y': 0.78},
    ];
    return List.generate(count, (i) => base[i % base.length]);
  }

  // ------------------------------------------------------------------
  // Render del jugador con etiqueta vertical orientada al centro
  // ------------------------------------------------------------------
  Widget _buildPlayer(
    Map<String, dynamic> p, {
    required double fieldW,
    required double fieldH,
    required double avatarSize,
    required double labelGap,
    required double labelMax,
    required double sidePadding,
  }) {
    final xRel = (p['x'] ?? 0.5) as double;
    final yRel = (p['y'] ?? 0.5) as double;
    final name = (p['name'] ?? '') as String;
    final rank = (p['rank'] ?? '') as String;
    final avatar = (p['avatar'] ?? '') as String;
    final number = (p['number'] ?? 0) as int;

    // Posición base
    double x = xRel * fieldW;
    double y = yRel * fieldH;

    // Lado del campo para orientar texto hacia el centro
    final onLeftSide = xRel <= 0.5;
    final textTurns =
        onLeftSide ? 3 : 1; // 270° si está a la izq, 90° si a la der

    // Offsets
    final half = avatarSize / 2;
    final textOffset = (labelGap + labelMax / 2);

    // Evitar que el avatar se corte con los bordes
    x = x.clamp(sidePadding + half, fieldW - sidePadding - half);
    y = y.clamp(sidePadding + half, fieldH - sidePadding - half);

    // Posición del centro del avatar
    final avatarLeft = x - half;
    final avatarTop = y - half;

    // Posición del “centro” de la etiqueta vertical
    final labelCenterX =
        onLeftSide ? (x + half + textOffset) : (x - half - textOffset);
    final labelCenterY = y;

    // Contenedor de la etiqueta (alto = labelMax, ancho fijo)
    final labelBox = SizedBox(
      width: 16 * (avatarSize / 56.0), // ancho visual de la “columna” de texto
      height: labelMax,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _VerticalNameTag(
          name: name,
          rank: rank,
          color: teamColor,
          fontScale: avatarSize / 56.0,
        ),
      ),
    );

    return Stack(
      children: [
        // Avatar
        Positioned(
          left: avatarLeft,
          top: avatarTop,
          child: _AvatarBubble(
            size: avatarSize,
            teamColor: teamColor,
            avatar: avatar,
            number: number,
            name: name,
          ),
        ),
        // Etiqueta vertical mirando al centro
        Positioned(
          left: labelCenterX - (onLeftSide ? 0 : (16 * (avatarSize / 56.0))),
          top: labelCenterY - (labelMax / 2),
          child: RotatedBox(
            quarterTurns: textTurns,
            child: labelBox,
          ),
        ),
      ],
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ===================================================================
// Avatar redondo con sombra + fallback (inicial o #)
// ===================================================================
class _AvatarBubble extends StatelessWidget {
  final double size;
  final Color teamColor;
  final String avatar;
  final int number;
  final String name;

  const _AvatarBubble({
    required this.size,
    required this.teamColor,
    required this.avatar,
    required this.number,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [teamColor.withOpacity(0.9), Colors.black.withOpacity(0.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: teamColor.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar.isNotEmpty
          ? Image.network(
              avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final initial = name.isNotEmpty
        ? name.characters.first.toUpperCase()
        : number.toString();
    return Container(
      color: teamColor.withOpacity(0.9),
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

// ===================================================================
// Etiqueta vertical (Nombre + Rango) con estilo limpio
// ===================================================================
class _VerticalNameTag extends StatelessWidget {
  final String name;
  final String rank;
  final Color color;
  final double fontScale; // para acompañar el tamaño del avatar

  const _VerticalNameTag({
    required this.name,
    required this.rank,
    required this.color,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final nameStyle = TextStyle(
      color: Colors.white,
      fontSize: 12 * fontScale,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      height: 1.0,
    );
    final rankStyle = TextStyle(
      color: color.withOpacity(0.95),
      fontSize: 10 * fontScale,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nombre
        SizedBox(
          height: 48 * fontScale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(name.isEmpty ? 'Jugador' : name, style: nameStyle),
          ),
        ),
        const SizedBox(height: 6),
        // Rango
        if (rank.isNotEmpty)
          SizedBox(
            height: 28 * fontScale,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(rank, style: rankStyle),
            ),
          ),
      ],
    );
  }
}

/// ====================================================================
/// 🎨 _PitchPainter — Cancha profesional con trazos suaves
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
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(16)),
      paint,
    );

    // Línea central y círculo
    canvas.drawLine(Offset(w / 2, 8), Offset(w / 2, h - 8), paint);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.15, paint);

    // Áreas pequeñas
    canvas.drawRect(Rect.fromLTWH(8, h * 0.3, w * 0.08, h * 0.4), paint);
    canvas.drawRect(
      Rect.fromLTWH(w - w * 0.08 - 8, h * 0.3, w * 0.08, h * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
