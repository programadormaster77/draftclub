import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Stream del chat de SALA (rooms/{roomId}/chat)
  Stream<List<Message>> streamRoomChat(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('chat')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => Message.fromMap(d.data())).toList());
  }

  /// Enviar mensaje a SALA
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
    required String senderName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final col = _db.collection('rooms').doc(roomId).collection('chat');
    final doc = col.doc();
    final msg = Message(
      id: doc.id,
      roomId: roomId,
      teamId: null,
      senderId: uid,
      senderName: senderName,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    await doc.set(msg.toMap());
  }

  /// Stream del chat de EQUIPO (rooms/{roomId}/teams/{teamId}/chat)
  Stream<List<Message>> streamTeamChat(String roomId, String teamId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => Message.fromMap(d.data())).toList());
  }

  /// Enviar mensaje a EQUIPO
  Future<void> sendTeamMessage({
    required String roomId,
    required String teamId,
    required String text,
    required String senderName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final col = _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat');
    final doc = col.doc();
    final msg = Message(
      id: doc.id,
      roomId: roomId,
      teamId: teamId,
      senderId: uid,
      senderName: senderName,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    await doc.set(msg.toMap());
  }
}
