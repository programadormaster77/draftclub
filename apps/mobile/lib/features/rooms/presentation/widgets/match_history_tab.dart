import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart'; // Intento usar RxDart si está, si no, manual.
// Ah, RxDart no está en pubspec. Haré una implementación manual de 'combineLatest'.

import '../../models/room_model.dart';
import '../../models/match_model.dart' as m;
import 'match_card.dart';

class MatchHistoryTab extends StatefulWidget {
  const MatchHistoryTab({super.key});

  @override
  State<MatchHistoryTab> createState() => _MatchHistoryTabState();
}

class _MatchHistoryTabState extends State<MatchHistoryTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<List<Room>>? _roomsStream;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _roomsStream = _firestore
          .collection('rooms')
          .where('players', arrayContains: uid)
          .snapshots()
          .map((s) => s.docs.map((d) => Room.fromMap(d.data())).toList());
    }
  }

  // Combina los streams de partidos de cada sala en una sola lista
  Stream<List<_MatchWithRoom>> _combinedMatchesStream(List<Room> rooms) {
    if (rooms.isEmpty) {
      return Stream.value([]);
    }

    List<Stream<List<_MatchWithRoom>>> streams = rooms.map((room) {
      return _firestore
          .collection('rooms')
          .doc(room.id)
          .collection('matches')
          .where('isFinished', isEqualTo: true) // Solo finalizados
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((doc) => _MatchWithRoom(
                  match: m.Match.fromMap(doc.data(), doc.id),
                  room: room,
                ))
            .toList();
      });
    }).toList();

    // Combinar manualmente (simple merge)
    // Como no tenemos RxDart, usaremos StreamZip o similar?
    // Flutter/Dart async no tiene combineLatest para listas dinámicas fácilmente.
    // Usaremos una solución con StreamGroup si estuviera, pero haremos un custom merger.

    return _FilesStreamMerger(streams).stream;
  }

  @override
  Widget build(BuildContext context) {
    if (_roomsStream == null) {
      return const Center(
          child: Text('Debes iniciar sesión.',
              style: TextStyle(color: Colors.white54)));
    }

    return StreamBuilder<List<Room>>(
      stream: _roomsStream,
      builder: (context, roomSnap) {
        if (roomSnap.hasError) {
          return Center(
              child: Text('Error: ${roomSnap.error}',
                  style: const TextStyle(color: Colors.red)));
        }
        if (roomSnap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        final rooms = roomSnap.data ?? [];
        if (rooms.isEmpty) {
          return _buildEmptyState();
        }

        // Ahora nos suscribimos a los partidos de estas salas
        return StreamBuilder<List<_MatchWithRoom>>(
          stream: _combinedMatchesStream(rooms),
          builder: (context, matchSnap) {
            if (matchSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent));
            }

            final allMatches = matchSnap.data ?? [];
            if (allMatches.isEmpty) {
              return _buildEmptyState();
            }

            // Ordenar por fecha descendente
            allMatches
                .sort((a, b) => b.match.dateTime.compareTo(a.match.dateTime));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allMatches.length,
              itemBuilder: (context, index) {
                final item = allMatches[index];
                return MatchCard(
                  match: item.match,
                  roomName: item.room.name,
                  onTap: () {
                    // Opcional: navegar al detalle de la sala
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Sin historial de partidos',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando juegues y finalices partidos en tus salas,\naparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _MatchWithRoom {
  final m.Match match;
  final Room room;
  _MatchWithRoom({required this.match, required this.room});
}

// Clase auxiliar para combinar streams de listas
class _FilesStreamMerger {
  final List<Stream<List<_MatchWithRoom>>> streams;
  final StreamController<List<_MatchWithRoom>> _controller = StreamController();
  final List<List<_MatchWithRoom>?> _lastValues;
  int _activeStreams = 0;

  _FilesStreamMerger(this.streams)
      : _lastValues = List.filled(streams.length, null) {
    if (streams.isEmpty) {
      _controller.close();
      return;
    }

    for (int i = 0; i < streams.length; i++) {
      _activeStreams++;
      streams[i].listen(
        (data) {
          _lastValues[i] = data;
          _emit();
        },
        onError: (e) {
          // Si una sala falla, ignoramos o emitimos error? Mejor ignorar esa sala.
          print('Error en stream de sala: $e');
        },
        onDone: () {
          _activeStreams--;
          if (_activeStreams == 0) _controller.close();
        },
      );
    }
  }

  void _emit() {
    if (_controller.isClosed) return;
    final List<_MatchWithRoom> aggregated = [];
    for (final list in _lastValues) {
      if (list != null) {
        aggregated.addAll(list);
      }
    }
    _controller.add(aggregated);
  }

  Stream<List<_MatchWithRoom>> get stream => _controller.stream;
}
