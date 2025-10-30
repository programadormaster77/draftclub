import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message_model.dart';

/// ====================================================================
/// 💬 ChatService — Servicio de chat "Arena Chat Pro"
/// ====================================================================
/// 🔹 Maneja todos los mensajes (sala y equipo) con Firestore.
/// 🔹 Soporta texto, imagen, voz y mensajes de sistema.
/// 🔹 Envía avatar, rango y nombre del jugador.
/// 🔹 Incluye subida automática a Firebase Storage.
/// 🔹 100 % compatible con tu estructura actual.
/// ====================================================================
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ================================================================
  // 🧩 STREAM DE CHAT DE SALA
  // ================================================================
  Stream<List<Message>> streamRoomChat(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  // ================================================================
  // 📨 ENVIAR MENSAJE DE TEXTO — SALA
  // ================================================================
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
    required String senderName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 🔹 Obtener avatar y rango del usuario
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final avatarUrl = userData['photoUrl'] ?? user.photoURL ?? '';
    final rank = userData['rank'] ?? 'Bronce';

    final docRef = _db.collection('rooms').doc(roomId).collection('chat').doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      senderId: user.uid,
      senderName: senderName,
      text: text.trim(),
      type: 'text',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // 🧩 STREAM DE CHAT DE EQUIPO
  // ================================================================
  Stream<List<Message>> streamTeamChat(String roomId, String teamId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  // ================================================================
  // 📨 ENVIAR MENSAJE DE TEXTO — EQUIPO
  // ================================================================
  Future<void> sendTeamMessage({
    required String roomId,
    required String teamId,
    required String text,
    required String senderName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // 🔹 Obtener avatar y rango del usuario
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final avatarUrl = userData['photoUrl'] ?? user.photoURL ?? '';
    final rank = userData['rank'] ?? 'Bronce';

    final docRef = _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat')
        .doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      teamId: teamId,
      senderId: user.uid,
      senderName: senderName,
      text: text.trim(),
      type: 'text',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // 🖼️ ENVIAR IMAGEN — SALA
  // ================================================================
  Future<void> sendRoomImage({
    required String roomId,
    required File file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Subir imagen
    final ref = _storage.ref().child(
        'chat_media/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = await ref.putFile(file);
    final imageUrl = await uploadTask.ref.getDownloadURL();

    // Datos del usuario
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final avatarUrl = data['photoUrl'] ?? user.photoURL ?? '';
    final rank = data['rank'] ?? 'Bronce';

    final docRef = _db.collection('rooms').doc(roomId).collection('chat').doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      senderId: user.uid,
      senderName: data['name'] ?? user.displayName ?? 'Jugador',
      text: imageUrl,
      type: 'image',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // 🖼️ ENVIAR IMAGEN — EQUIPO
  // ================================================================
  Future<void> sendTeamImage({
    required String roomId,
    required String teamId,
    required File file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Subir imagen
    final ref = _storage.ref().child(
        'chat_media/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = await ref.putFile(file);
    final imageUrl = await uploadTask.ref.getDownloadURL();

    // Datos del usuario
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final avatarUrl = data['photoUrl'] ?? user.photoURL ?? '';
    final rank = data['rank'] ?? 'Bronce';

    final docRef = _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat')
        .doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      teamId: teamId,
      senderId: user.uid,
      senderName: data['name'] ?? user.displayName ?? 'Jugador',
      text: imageUrl,
      type: 'image',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // 🎙️ ENVIAR AUDIO — SALA
  // ================================================================
  Future<void> sendRoomAudio({
    required String roomId,
    required File file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final ref = _storage.ref().child(
        'chat_audio/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a');
    final uploadTask = await ref.putFile(file);
    final audioUrl = await uploadTask.ref.getDownloadURL();

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final avatarUrl = data['photoUrl'] ?? user.photoURL ?? '';
    final rank = data['rank'] ?? 'Bronce';

    final docRef = _db.collection('rooms').doc(roomId).collection('chat').doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      senderId: user.uid,
      senderName: data['name'] ?? user.displayName ?? 'Jugador',
      text: audioUrl,
      type: 'voice',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // 🎙️ ENVIAR AUDIO — EQUIPO
  // ================================================================
  Future<void> sendTeamAudio({
    required String roomId,
    required String teamId,
    required File file,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final ref = _storage.ref().child(
        'chat_audio/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a');
    final uploadTask = await ref.putFile(file);
    final audioUrl = await uploadTask.ref.getDownloadURL();

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final avatarUrl = data['photoUrl'] ?? user.photoURL ?? '';
    final rank = data['rank'] ?? 'Bronce';

    final docRef = _db
        .collection('rooms')
        .doc(roomId)
        .collection('teams')
        .doc(teamId)
        .collection('chat')
        .doc();

    final msg = Message(
      id: docRef.id,
      roomId: roomId,
      teamId: teamId,
      senderId: user.uid,
      senderName: data['name'] ?? user.displayName ?? 'Jugador',
      text: audioUrl,
      type: 'voice',
      avatarUrl: avatarUrl,
      rank: rank,
      timestamp: Timestamp.now(),
    );

    await docRef.set(msg.toMap());
  }

  // ================================================================
  // ⚙️ MENSAJE DE SISTEMA
  // ================================================================
  Future<void> sendSystemMessage({
    required String roomId,
    String? teamId,
    required String text,
  }) async {
    final col = teamId == null
        ? _db.collection('rooms').doc(roomId).collection('chat')
        : _db
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
      senderId: 'system',
      senderName: 'Sistema',
      text: text.trim(),
      type: 'system',
      avatarUrl: null,
      rank: null,
      timestamp: Timestamp.now(),
    );

    await doc.set(msg.toMap());
  }
}
