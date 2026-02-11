import 'package:flutter/material.dart';
import '../../models/match_model.dart' as m;

class MatchCard extends StatelessWidget {
  final m.Match match;
  final String roomName; // Nombre de la sala o equipo local
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.match,
    required this.roomName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Definir colores y estado basado en el resultado
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.sports_soccer;
    String statusText = 'Pendiente';

    if (match.isFinished) {
      if (match.hasReferee) {
        if (match.result == 'win') {
          statusColor = Colors.greenAccent;
          statusIcon = Icons.emoji_events;
          statusText = 'Victoria';
        } else if (match.result == 'loss') {
          statusColor = Colors.redAccent;
          statusIcon = Icons.thumb_down;
          statusText = 'Derrota';
        } else {
          statusColor = Colors.orangeAccent;
          statusIcon = Icons.handshake;
          statusText = 'Empate';
        }
      } else {
        statusColor = Colors.blueGrey;
        statusIcon = Icons.info_outline;
        statusText = 'Finalizado';
      }
    } else {
      statusColor = Colors.blueAccent;
      statusIcon = Icons.calendar_today;
      statusText = 'Programado';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Indicador de Estado
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Fecha
                Text(
                  '${match.dateTime.day}/${match.dateTime.month} - ${match.dateTime.hour}:${match.dateTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Marcador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    roomName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    match.score,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.opponentName ?? 'Rival',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (match.location != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      match.location!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
