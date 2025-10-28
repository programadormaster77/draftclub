import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String roomId;
  final String? teamId; // null si es chat de sala
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.teamId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'teamId': teamId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Message.fromMap(Map<String, dynamic> map) {
    final createdField = map['createdAt'];
    DateTime created;
    if (createdField is Timestamp) {
      created = createdField.toDate();
    } else if (createdField is String) {
      created = DateTime.tryParse(createdField) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return Message(
      id: (map['id'] ?? '') as String,
      roomId: (map['roomId'] ?? '') as String,
      teamId: map['teamId'] as String?,
      senderId: (map['senderId'] ?? '') as String,
      senderName: (map['senderName'] ?? '') as String,
      text: (map['text'] ?? '') as String,
      createdAt: created,
    );
  }
}
