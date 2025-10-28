import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 👥 Team Model — Representa un equipo dentro de una sala
/// ====================================================================
class Team {
  final String id;
  final String roomId;
  final String name;
  final List<String> players;
  final int maxPlayers; // normalmente = playersPerTeam de la sala
  final String color; // hex opcional para la UI
  final DateTime createdAt;

  Team({
    required this.id,
    required this.roomId,
    required this.name,
    required this.players,
    required this.maxPlayers,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'name': name,
        'players': players,
        'maxPlayers': maxPlayers,
        'color': color,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Team.fromMap(Map<String, dynamic> map) {
    DateTime created;
    final c = map['createdAt'];
    if (c is Timestamp) {
      created = c.toDate();
    } else if (c is String) {
      created = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return Team(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      name: map['name'] ?? 'Equipo',
      players: List<String>.from(map['players'] ?? []),
      maxPlayers: (map['maxPlayers'] is int)
          ? map['maxPlayers']
          : int.tryParse('${map['maxPlayers']}') ?? 0,
      color: map['color'] ?? '#3A86FF',
      createdAt: created,
    );
  }

  int get count => players.length;
  bool get isFull => count >= maxPlayers;
  bool hasPlayer(String uid) => players.contains(uid);
}
