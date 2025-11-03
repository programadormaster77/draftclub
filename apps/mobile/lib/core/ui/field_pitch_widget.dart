import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// ⚽ FieldPitchWidget — Persistencia 100% en Firestore (Versión Final)
/// ====================================================================
/// ✅ Sin dependencias de datos iniciales en memoria.
/// ✅ Lee y actualiza directamente desde Firestore.
/// ✅ Mantiene posiciones entre sesiones y recargas.
/// ✅ Compatible con drag, reset, y animaciones.
/// ====================================================================
class FieldPitchWidget extends StatefulWidget {
  final Color teamColor;
  final String roomId;
  final bool enableLighting;

  const FieldPitchWidget({
    super.key,
    required this.teamColor,
    required this.roomId,
    this.enableLighting = true,
  });

  @override
  State<FieldPitchWidget> createState() => _FieldPitchWidgetState();
}

class _FieldPitchWidgetState extends State<FieldPitchWidget> {
  static const double _kFieldPadding = 8.0;

  /// ⚙️ Generador de formación base si aún no hay jugadores creados.
  List<Map<String, double>> _generateBalancedFormation(int count) {
    final formations = {
      5: [
        {'x': 0.10, 'y': 0.50},
        {'x': 0.28, 'y': 0.25},
        {'x': 0.28, 'y': 0.75},
        {'x': 0.55, 'y': 0.35},
        {'x': 0.55, 'y': 0.65},
      ],
      7: [
        {'x': 0.08, 'y': 0.50},
        {'x': 0.23, 'y': 0.22},
        {'x': 0.23, 'y': 0.78},
        {'x': 0.42, 'y': 0.30},
        {'x': 0.42, 'y': 0.70},
        {'x': 0.67, 'y': 0.40},
        {'x': 0.67, 'y': 0.60},
      ],
      9: [
        {'x': 0.08, 'y': 0.50},
        {'x': 0.20, 'y': 0.22},
        {'x': 0.20, 'y': 0.78},
        {'x': 0.35, 'y': 0.18},
        {'x': 0.35, 'y': 0.82},
        {'x': 0.50, 'y': 0.35},
        {'x': 0.50, 'y': 0.65},
        {'x': 0.70, 'y': 0.45},
        {'x': 0.70, 'y': 0.55},
      ],
    };
    return formations[count] ?? formations[7]!;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🔹 Si no hay jugadores aún, muestra la cancha vacía
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyPitch(context);
        }

        final playerData = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'name': data['name'] ?? '',
            'rank': data['rank'] ?? '',
            'avatar': data['avatar'] ?? '',
            'x': (data['x'] ?? 0.5).toDouble(),
            'y': (data['y'] ?? 0.5).toDouble(),
          };
        }).toList();

        return LayoutBuilder(builder: (context, constraints) {
          final fieldW = constraints.maxWidth;
          final fieldH = fieldW * 0.65;

          final density = playerData.length.clamp(5, 11);
          final scale = _lerp(1.45, 0.78, (density - 3.5) / 6.0);
          final avatarSize = 35.0 * scale;

          return Center(
            child: Container(
              width: fieldW,
              height: fieldH,
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.teamColor.withOpacity(0.7),
                    blurRadius: 9,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  CustomPaint(
                      size: Size(fieldW, fieldH), painter: _PitchPainter()),
                  if (widget.enableLighting)
                    Positioned.fill(
                      child:
                          _DynamicLightingOverlay(teamColor: widget.teamColor),
                    ),
                  for (int i = 0; i < playerData.length; i++)
                    _AnimatedPlayerEditable(
                      index: i,
                      player: playerData[i],
                      teamColor: widget.teamColor,
                      fieldW: fieldW,
                      fieldH: fieldH,
                      avatarSize: avatarSize,
                      roomId: widget.roomId,
                      fieldPadding: _kFieldPadding,
                      onResetRequested: () {
                        final base =
                            _generateBalancedFormation(playerData.length);
                        final uid = playerData[i]['uid'];
                        FirebaseFirestore.instance
                            .collection('rooms')
                            .doc(widget.roomId)
                            .collection('players')
                            .doc(uid)
                            .set({
                          'x': base[i]['x'],
                          'y': base[i]['y'],
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                      },
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// Muestra la cancha vacía si aún no hay jugadores creados.
  Widget _buildEmptyPitch(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: const Center(
        child: Text(
          "Aún no hay jugadores en esta sala",
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

/// ===============================================================
/// 🧩 _AnimatedPlayerEditable — Jugador movible + persistencia
/// ===============================================================
class _AnimatedPlayerEditable extends StatefulWidget {
  final int index;
  final Map<String, dynamic> player;
  final Color teamColor;
  final double fieldW, fieldH, avatarSize;
  final String roomId;
  final double fieldPadding;
  final VoidCallback onResetRequested;

  const _AnimatedPlayerEditable({
    required this.index,
    required this.player,
    required this.teamColor,
    required this.fieldW,
    required this.fieldH,
    required this.avatarSize,
    required this.roomId,
    required this.fieldPadding,
    required this.onResetRequested,
  });

  @override
  State<_AnimatedPlayerEditable> createState() =>
      _AnimatedPlayerEditableState();
}

class _AnimatedPlayerEditableState extends State<_AnimatedPlayerEditable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeIn);

  late double _xPx;
  late double _yPx;

  @override
  void initState() {
    super.initState();
    final nx = (widget.player['x'] ?? 0.5).toDouble();
    final ny = (widget.player['y'] ?? 0.5).toDouble();
    _xPx = nx * widget.fieldW;
    _yPx = ny * widget.fieldH;
  }

  (double, double) _clampToField(double x, double y) {
    final half = widget.avatarSize / 2;
    final minX = widget.fieldPadding + half;
    final maxX = widget.fieldW - widget.fieldPadding - half;
    final minY = widget.fieldPadding + half;
    final maxY = widget.fieldH - widget.fieldPadding - half;
    return (x.clamp(minX, maxX), y.clamp(minY, maxY));
  }

  Future<void> _savePosition(double x, double y) async {
    final uid = widget.player['uid'];
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('players')
          .doc(uid)
          .set(
        {'x': x, 'y': y, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint("❌ Error al guardar posición: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.player['name'] ?? '';
    final rank = widget.player['rank'] ?? '';
    final avatar = widget.player['avatar'] ?? '';
    final half = widget.avatarSize / 2;

    return Positioned(
      left: _xPx - half,
      top: _yPx - half,
      child: GestureDetector(
        onPanUpdate: (details) {
          final nx = _xPx + details.delta.dx;
          final ny = _yPx + details.delta.dy;
          final (cx, cy) = _clampToField(nx, ny);
          setState(() {
            _xPx = cx;
            _yPx = cy;
          });
        },
        onPanEnd: (_) {
          final normX = _xPx / widget.fieldW;
          final normY = _yPx / widget.fieldH;
          _savePosition(normX, normY);
        },
        onLongPress: widget.onResetRequested,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: widget.avatarSize + 12,
                      height: widget.avatarSize + 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.teamColor.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    _AvatarBubble(
                      size: widget.avatarSize,
                      teamColor: widget.teamColor,
                      avatar: avatar,
                      name: name,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  name.isEmpty ? 'Jugador' : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rank.isNotEmpty)
                  Text(rank,
                      style: TextStyle(
                          color: widget.teamColor.withOpacity(0.9),
                          fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// 🧍 AvatarBubble — Avatar o inicial
/// ===============================================================
class _AvatarBubble extends StatelessWidget {
  final double size;
  final Color teamColor;
  final String avatar;
  final String name;

  const _AvatarBubble({
    required this.size,
    required this.teamColor,
    required this.avatar,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final bool invalid = avatar.isEmpty || !avatar.startsWith('http');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [teamColor.withOpacity(0.9), Colors.black.withOpacity(0.4)],
        ),
        border: Border.all(color: Colors.white24, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: invalid
          ? _fallback(name)
          : Image.network(
              avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(name),
            ),
    );
  }

  Widget _fallback(String name) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// ===============================================================
/// ✨ Iluminación dinámica del campo
/// ===============================================================
class _DynamicLightingOverlay extends StatefulWidget {
  final Color teamColor;
  const _DynamicLightingOverlay({required this.teamColor});

  @override
  State<_DynamicLightingOverlay> createState() =>
      _DynamicLightingOverlayState();
}

class _DynamicLightingOverlayState extends State<_DynamicLightingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final offset = (_controller.value - 0.5) * 2;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.3 * offset, -0.2),
              radius: 1.0,
              colors: [
                widget.teamColor.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ===============================================================
/// 🟩 _PitchPainter — Líneas del campo
/// ===============================================================
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const pad = 8.0;

    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTWH(pad, pad, w - pad * 2, h - pad * 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)), paint);
    canvas.drawLine(Offset(w / 2, pad), Offset(w / 2, h - pad), paint);
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.15, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
