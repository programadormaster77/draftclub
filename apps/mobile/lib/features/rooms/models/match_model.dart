import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// ⚽ Match Model — Representa un partido individual dentro de una sala
/// ====================================================================
class Match {
  final String id;
  final String roomId;
  final DateTime dateTime;
  final String? location;
  final bool hasReferee;
  final bool isFinished;
  final String result; // 'win', 'loss', 'draw', 'unknown'
  final String score; // "4 - 2"
  final String? opponentName;

  Match({
    required this.id,
    required this.roomId,
    required this.dateTime,
    this.location,
    this.hasReferee = false,
    this.isFinished = false,
    this.result = 'unknown',
    this.score = '0 - 0',
    this.opponentName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'dateTime': Timestamp.fromDate(dateTime),
      if (location != null) 'location': location,
      'hasReferee': hasReferee,
      'isFinished': isFinished,
      'result': result,
      'score': score,
      if (opponentName != null) 'opponentName': opponentName,
    };
  }

  factory Match.fromMap(Map<String, dynamic> map, String docId) {
    DateTime dt = DateTime.now();
    if (map['dateTime'] is Timestamp) {
      dt = (map['dateTime'] as Timestamp).toDate();
    } else if (map['dateTime'] is String) {
      dt = DateTime.tryParse(map['dateTime']) ?? DateTime.now();
    }

    return Match(
      id: docId,
      roomId: map['roomId'] ?? '',
      dateTime: dt,
      location: map['location'],
      hasReferee: map['hasReferee'] ?? false,
      isFinished: map['isFinished'] ?? false,
      result: map['result'] ?? 'unknown',
      score: map['score'] ?? '0 - 0',
      opponentName: map['opponentName'],
    );
  }
}
