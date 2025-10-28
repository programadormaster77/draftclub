import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================================================
/// 📰 FeedPage — Enlazada a Firestore (solo UI del feed)
/// ===============================================================
/// IMPORTANTE:
/// - NO contiene botón de "Cerrar sesión".
/// - NO hace navegación. El flujo global lo maneja AuthStateHandler/ProfileGate.
/// - Así evitamos caer al "feed viejo" tras logout.
/// ===============================================================
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),

      // Solo un AppBar simple (sin logout)
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'DRAFT·APP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),

      // Lista de posts en tiempo real
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '⚽ Aún no hay publicaciones.\nSé el primero en compartir tu jugada.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;

              final usuario = post['usuario'] ?? 'Jugador';
              final descripcion = post['descripcion'] ?? '';
              final ciudad = post['ciudad'] ?? '';
              final rango = post['rango'] ?? 'Amateur';
              final progreso = (post['progreso'] as String?);
              final imagenUrl = (post['imagenUrl'] as String?);

              final createdAt = post['createdAt'];
              DateTime fecha;
              if (createdAt is Timestamp) {
                fecha = createdAt.toDate();
              } else if (createdAt is String) {
                fecha = DateTime.tryParse(createdAt) ?? DateTime.now();
              } else {
                fecha = DateTime.now();
              }

              return _PostCard(
                usuario: usuario,
                ciudad: ciudad,
                descripcion: descripcion,
                rango: rango,
                progreso: progreso,
                imagenUrl: imagenUrl,
                fecha: fecha,
              );
            },
          );
        },
      ),

      // Botón de acción (placeholder)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crear publicación (próximamente) ⚡'),
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String usuario;
  final String ciudad;
  final String descripcion;
  final String rango;
  final String? progreso;
  final String? imagenUrl;
  final DateTime fecha;

  const _PostCard({
    required this.usuario,
    required this.ciudad,
    required this.descripcion,
    required this.rango,
    required this.progreso,
    required this.imagenUrl,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    final fechaFmt =
        '${fecha.day}/${fecha.month}/${fecha.year} · ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white12,
                  child: Icon(Icons.person, color: Colors.white70, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('$fechaFmt · $ciudad',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Imagen o placeholder
            if (imagenUrl != null && imagenUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(imagenUrl!, fit: BoxFit.cover),
              )
            else
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.sports_soccer,
                      size: 40, color: Colors.white30),
                ),
              ),
            const SizedBox(height: 10),

            // Descripción
            Text(
              descripcion,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 8),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 16, color: Colors.white54),
                    SizedBox(width: 6),
                    Text('—',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    SizedBox(width: 16),
                    Icon(Icons.comment_outlined,
                        size: 16, color: Colors.white54),
                    SizedBox(width: 6),
                    Text('—',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    SizedBox(width: 16),
                    Icon(Icons.share_outlined, size: 16, color: Colors.white54),
                    SizedBox(width: 6),
                    Text('Compartir',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
                Text(
                  progreso == null
                      ? 'Rango: $rango'
                      : 'Rango: $rango · $progreso',
                  style: TextStyle(
                    color: progreso == null
                        ? Colors.amberAccent
                        : Colors.blueAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
