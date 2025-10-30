import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 💬 Message — Modelo de mensaje completo (Arena Chat Pro)
/// ====================================================================
/// 🔹 Compatible con Firestore (rooms/{roomId}/teams/{teamId}/chat)
/// 🔹 Soporta:
///   - type: 'text' | 'system' | 'image' | 'voice'
///   - avatarUrl: foto del jugador
///   - rank: nivel del jugador (Bronce, Plata, Oro, etc.)
///   - timestamp: control automático de hora
/// 🔹 Totalmente integrado con ChatTeamPage y MessageBubble.
/// ====================================================================
class Message {
  final String id;
  final String roomId;
  final String? teamId; // null si es chat general de sala
  final String senderId;
  final String senderName;
  final String text;
  final String type; // 'text', 'system', 'image', 'voice'
  final String? avatarUrl; // foto del jugador
  final String? rank; // rango o nivel del jugador
  final Timestamp timestamp; // orden y hora del mensaje

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.teamId,
    this.type = 'text',
    this.avatarUrl,
    this.rank,
  });

  /// ==================== 🔄 Conversión a Map ====================
  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'teamId': teamId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type,
        'avatarUrl': avatarUrl,
        'rank': rank,
        'timestamp': timestamp,
      };

  /// ==================== 🧩 Creación desde Firestore ====================
  factory Message.fromMap(Map<String, dynamic> map) {
    // Compatibilidad: Firestore puede guardar 'timestamp' o 'createdAt'
    final dynamic timeField = map['timestamp'] ?? map['createdAt'];
    final Timestamp safeTimestamp =
        timeField is Timestamp ? timeField : Timestamp.fromDate(DateTime.now());

    return Message(
      id: (map['id'] ?? '') as String,
      roomId: (map['roomId'] ?? '') as String,
      teamId: map['teamId'] as String?,
      senderId: (map['senderId'] ?? '') as String,
      senderName: (map['senderName'] ?? 'Jugador') as String,
      text: (map['text'] ?? '') as String,
      type: (map['type'] ?? 'text') as String,
      avatarUrl: (map['avatarUrl'] ?? '') as String?,
      rank: (map['rank'] ?? 'Bronce') as String?,
      timestamp: safeTimestamp,
    );
  }

  /// ==================== 🧠 Utilidades ====================
  bool get isSystem => type == 'system';
  bool get isImage => type == 'image';
  bool get isVoice => type == 'voice';
  bool get isText => type == 'text';
}
