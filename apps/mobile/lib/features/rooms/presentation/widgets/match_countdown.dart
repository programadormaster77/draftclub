import 'dart:async';
import 'package:flutter/material.dart';

class MatchCountdown extends StatefulWidget {
  final DateTime eventDate; // Fecha del partido

  const MatchCountdown({super.key, required this.eventDate});

  @override
  State<MatchCountdown> createState() => _MatchCountdownState();
}

class _MatchCountdownState extends State<MatchCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    // Actualizar cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final diff = widget.eventDate.difference(now);

    if (diff.isNegative) {
      // El partido ya empezó o pasó
      // Podríamos manejar lógica de "En juego" vs "Finalizado" (ej: +2 horas)
      if (mounted) setState(() => _remaining = diff);
    } else {
      if (mounted) setState(() => _remaining = diff);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Caso: Partido ya inició
    if (_remaining.isNegative) {
      // Si hace menos de 2 horas que "empezó", mostramos "EN JUEGO"
      if (_remaining.abs().inHours < 2) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.greenAccent.shade700,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                '¡EN JUEGO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      } else {
        // Ya terminó
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'FINALIZADO',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }
    }

    // 2. Caso: Faltan días (> 24 horas)
    if (_remaining.inHours > 24) {
      return _buildChip(
        icon: Icons.calendar_today,
        text: 'Faltan: ${_remaining.inDays}d ${_remaining.inHours % 24}h',
        color: Colors.blueAccent,
      );
    }

    // 3. Caso: Falta menos de 24 horas (formato HH:MM:SS)
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    // Color rojo si falta menos de 1 hora
    final isUrgent = _remaining.inHours < 1;

    return _buildChip(
      icon: Icons.timer_outlined,
      text: 'Faltan: $hours:$minutes:$seconds',
      color: isUrgent ? Colors.redAccent : Colors.orangeAccent,
      animate: isUrgent, // Animar si es urgente
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    required Color color,
    bool animate = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2), // Fondo translúcido
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: animate
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color, // Texto del mismo color
              fontWeight: FontWeight.bold,
              fontSize: 13, // Ligeramente más grande
              fontFamily:
                  'monospace', // Fuente monoespaciada para evitar saltos
            ),
          ),
        ],
      ),
    );
  }
}
