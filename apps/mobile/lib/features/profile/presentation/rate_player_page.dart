import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../rooms/models/room_model.dart';
import '../domain/user_profile.dart'; // Local import if available, or assume typical structure

class RatePlayerPage extends StatefulWidget {
  final Room room;
  const RatePlayerPage({super.key, required this.room});

  @override
  State<RatePlayerPage> createState() => _RatePlayerPageState();
}

class _RatePlayerPageState extends State<RatePlayerPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Mapa: userId -> Calificación (1.0 - 5.0)
  final Map<String, double> _ratings = {};
  // Mapa: userId -> [Badges]
  final Map<String, Set<String>> _badges = {};

  final List<String> _availableBadges = ['Puntual', 'MVP', 'FairPlay', 'Crack'];

  bool _submitting = false;
  String? _selectedMvpId; // 🆕

  Widget _buildMvpSection(List<String> players) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border(
            bottom: BorderSide(color: Colors.blueAccent.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆 ¿QUIÉN FUE EL MVP?',
              style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final uid = players[index];
                final isSelected = _selectedMvpId == uid;

                return GestureDetector(
                  onTap: () => setState(() => _selectedMvpId = uid),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSelected
                                    ? Colors.amber
                                    : Colors.transparent,
                                width: 3),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: Colors.amber.withOpacity(0.5),
                                        blurRadius: 10)
                                  ]
                                : [],
                          ),
                          child: FutureBuilder<DocumentSnapshot>(
                            future:
                                _firestore.collection('users').doc(uid).get(),
                            builder: (context, snapshot) {
                              String? photoUrl;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                photoUrl = snapshot.data!.get('photoUrl');
                              }
                              return CircleAvatar(
                                radius: 28,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                backgroundColor: Colors.grey[800],
                                child: photoUrl == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white)
                                    : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isSelected)
                          const Text('MVP',
                              style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar al usuario actual de la lista
    final currentUserId = _auth.currentUser?.uid;
    final playersToRate =
        widget.room.players.where((id) => id != currentUserId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: const Text('Calificar Jugadores',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _submitting
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
              children: [
                // 🆕 SECCIÓN MVP
                if (playersToRate.isNotEmpty) _buildMvpSection(playersToRate),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: playersToRate.length,
                    itemBuilder: (context, index) {
                      final playerId = playersToRate[index];
                      return _buildPlayerRatingCard(playerId);
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submitRatings,
                        child: const Text('Enviar Calificaciones',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlayerRatingCard(String userId) {
    // En una app real, aquí haríamos un fetch del UserProfile para mostrar nombre y foto
    // Por ahora usamos el ID o un dummy name
    double currentRating = _ratings[userId] ?? 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(userId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      return Text(
                        data['name'] ?? 'Jugador',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      );
                    }
                    return const Text('Cargando...',
                        style: TextStyle(color: Colors.white54));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Calificación:', style: TextStyle(color: Colors.white70)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < currentRating ? Icons.star : Icons.star_border,
                  color: Colors.amberAccent,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _ratings[userId] = index + 1.0;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text('Reconocimientos (Opcional):',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _availableBadges.map((badge) {
              final isSelected = _badges[userId]?.contains(badge) ?? false;
              return FilterChip(
                label: Text(badge),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _badges.putIfAbsent(userId, () => {}).add(badge);
                    } else {
                      _badges[userId]?.remove(badge);
                    }
                  });
                },
                backgroundColor: Colors.white10,
                selectedColor: Colors.blueAccent.withOpacity(0.3),
                labelStyle: TextStyle(
                    color: isSelected ? Colors.blueAccent : Colors.white70),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color:
                            isSelected ? Colors.blueAccent : Colors.white12)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRatings() async {
    setState(() => _submitting = true);
    try {
      final batch = _firestore.batch();
      final raterId = _auth.currentUser!.uid;

      for (var entry in _ratings.entries) {
        final ratedUserId = entry.key;
        final rating = entry.value;
        final badges = _badges[ratedUserId]?.toList() ?? [];

        final ratingRef = _firestore.collection('ratings').doc();
        batch.set(ratingRef, {
          'raterId': raterId,
          'ratedUserId': ratedUserId,
          'roomId': widget.room.id,
          'rating': rating,
          'badges': badges,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Opcional: Actualizar promedio en UserProfile (Cloud Function es mejor, pero aquí localmente también se puede)
        // Por simplicidad, solo guardamos el rating individual
      }

      // 🏆 Guardar Voto MVP
      if (_selectedMvpId != null) {
        final mvpRef = _firestore
            .collection('matches')
            .doc(widget.room.id)
            .collection('votes')
            .doc(); // O rooms/{id}/votes
        batch.set(mvpRef, {
          'voterId': raterId,
          'votedUserId': _selectedMvpId,
          'type': 'mvp',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // También podemos agregarlo como badge directo si queremos simplificar
        // Pero lo correcto es contar votos en backend. Lo enviaremos como rating especial también.
        final mvpRatingRef = _firestore.collection('ratings').doc();
        batch.set(mvpRatingRef, {
          'raterId': raterId,
          'ratedUserId': _selectedMvpId,
          'roomId': widget.room.id,
          'rating': 5.0, // MVP cuenta como 5 automático extra? O independiente.
          'badges': ['MVP_VOTE'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Calificaciones enviadas'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
