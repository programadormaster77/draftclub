import 'package:flutter/material.dart';

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mockRooms = [
      {
        'nombre': 'Partido en El Campín',
        'ciudad': 'Bogotá',
        'fecha': 'Hoy, 7:00 PM',
        'tipo': 'Público',
        'cupos': '8/10',
        'color': Colors.greenAccent,
      },
      {
        'nombre': 'Fútbol 7 - Zona Norte',
        'ciudad': 'Bogotá',
        'fecha': 'Mañana, 5:30 PM',
        'tipo': 'Privado',
        'cupos': '10/10',
        'color': Colors.redAccent,
      },
      {
        'nombre': 'Tarde de goles ⚽',
        'ciudad': 'Chía',
        'fecha': 'Domingo, 3:00 PM',
        'tipo': 'Público',
        'cupos': '6/10',
        'color': Colors.blueAccent,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Salas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF0E0E0E),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockRooms.length,
        itemBuilder: (context, index) {
          final room = mockRooms[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade800, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: room['color'] as Color,
                child: const Icon(Icons.sports_soccer, color: Colors.black),
              ),
              title: Text(
                room['nombre'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${room['ciudad']} · ${room['fecha']}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room['tipo'] as String,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room['cupos'] as String,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              onTap: () {
                // TODO: navegar a detalle de sala
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.blueGrey.shade900,
                    content: Text(
                      'Entrando a "${room['nombre']}"...',
                      style: const TextStyle(color: Colors.white),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
