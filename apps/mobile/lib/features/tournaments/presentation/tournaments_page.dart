import 'package:flutter/material.dart';

class TournamentsPage extends StatelessWidget {
  const TournamentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockTournaments = [
      {
        'nombre': 'Torneo Relámpago El Dorado',
        'ciudad': 'Bogotá',
        'fecha': '25 Oct – 27 Oct',
        'equipos': '16 equipos',
        'estado': 'Inscripciones abiertas',
        'color': Colors.amberAccent,
      },
      {
        'nombre': 'Liga DraftClub Norte',
        'ciudad': 'Bogotá',
        'fecha': 'Nov 2025',
        'equipos': '10 equipos',
        'estado': 'En curso',
        'color': Colors.blueAccent,
      },
      {
        'nombre': 'Torneo de Campeones ⚽',
        'ciudad': 'Chía',
        'fecha': 'Finales de Dic',
        'equipos': '8 equipos',
        'estado': 'Finalizado',
        'color': Colors.grey,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Torneos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF0E0E0E),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockTournaments.length,
        itemBuilder: (context, index) {
          final torneo = mockTournaments[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade800, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: torneo['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      torneo['estado'] as String,
                      style: TextStyle(
                        color: torneo['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  torneo['nombre'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${torneo['ciudad']} · ${torneo['fecha']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      torneo['equipos'] as String,
                      style: const TextStyle(color: Colors.white60),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: navegar a detalle del torneo
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.blueGrey.shade900,
                            content: Text(
                              'Abriendo "${torneo['nombre']}"...',
                              style: const TextStyle(color: Colors.white),
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                      ),
                      child: const Text('Ver más'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
