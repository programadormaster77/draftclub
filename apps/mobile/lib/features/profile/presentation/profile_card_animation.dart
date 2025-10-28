import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// ===============================================================
/// 🎴 ProfileCardAnimation — Carta estilo FIFA con animación futurista
/// ===============================================================
/// Muestra los datos del jugador (nombre, rango, nivel, estadísticas)
/// con efecto de entrada y luces neón.
/// Se puede usar después de crear o editar el perfil.
///
/// Ejemplo de uso:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => ProfileCardAnimation(
///     name: "Juan Pérez",
///     nickname: "@juanfcb",
///     rank: "Bronce",
///     xp: 120,
///     victories: 10,
///     matches: 15,
///     photoUrl: "https://.../avatar.jpg",
///   ),
/// );
/// ```
class ProfileCardAnimation extends StatelessWidget {
  final String name;
  final String nickname;
  final String rank;
  final int xp;
  final int victories;
  final int matches;
  final String? photoUrl;

  const ProfileCardAnimation({
    super.key,
    required this.name,
    required this.nickname,
    required this.rank,
    required this.xp,
    required this.victories,
    required this.matches,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    switch (rank.toLowerCase()) {
      case 'oro':
        rankColor = const Color(0xFFFFD700);
        break;
      case 'plata':
        rankColor = const Color(0xFFC0C0C0);
        break;
      case 'bronce':
      default:
        rankColor = const Color(0xFFCD7F32);
        break;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                rankColor.withOpacity(0.5),
                Colors.black.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.7),
                blurRadius: 25,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LOGO Y CABECERA
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/draftclub_logo.png',
                    height: 38,
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(width: 8),
                  const Text(
                    "DraftClub",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(duration: 700.ms),
                ],
              ),
              const SizedBox(height: 20),

              // FOTO DEL JUGADOR
              CircleAvatar(
                radius: 48,
                backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? NetworkImage(photoUrl!)
                    : null,
                backgroundColor: Colors.white10,
                child: (photoUrl == null || photoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white54, size: 48)
                    : null,
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 14),

              // NOMBRE Y APODO
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 4),
              Text(
                nickname,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 16),

              // NIVEL Y RANGO
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: rankColor, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "RANGO: ${rank.toUpperCase()}",
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 20),

              // PROGRESO DE NIVEL
              LinearProgressIndicator(
                value: (xp % 1000) / 1000,
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: rankColor,
                borderRadius: BorderRadius.circular(10),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 10),
              Text(
                "XP: $xp / 1000",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 18),

              // ESTADÍSTICAS BÁSICAS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: "PARTIDOS", value: matches.toString()),
                  _Stat(label: "VICTORIAS", value: victories.toString()),
                  _Stat(label: "NIVEL", value: (xp ~/ 100).toString()),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 25),

              // BOTÓN CONTINUAR
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: rankColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CONTINUAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms),
            ],
          ),
        ).animate().fadeIn(duration: 800.ms).scale(duration: 700.ms),
      ),
    );
  }
}

/// Widget interno para mostrar estadísticas pequeñas
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
