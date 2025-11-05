import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================================
/// 💬 ChatService — Lógica central de mensajería (Firestore)
/// ============================================================================
/// ✅ Crea chats o busca si ya existen.
/// ✅ Envía mensajes (texto o imagen).
/// ✅ Escucha en tiempo real los chats del usuario.
/// ✅ Actualiza metadatos (lastMessage, updatedAt, unread por usuario).
/// ✅ Soporta contador de mensajes no leídos.
/// ✅ Resetea contador al abrir chat.
/// ============================================================================
class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 🔹 Obtiene todos los chats del usuario actual
  // ============================================================
  Stream<QuerySnapshot> getUserChats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // 🔹 Busca o crea un chat entre el usuario actual y otro
  // ============================================================
  Future<String?> createOrGetChat(String otherUserId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid == otherUserId) return null;

    try {
      final existingChat = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUid)
          .get();

      for (var doc in existingChat.docs) {
        final participants =
            (doc['participants'] as List).map((e) => e.toString()).toList();
        if (participants.contains(otherUserId)) {
          return doc.id; // ✅ Ya existe chat entre ambos
        }
      }

      // ✅ Si no existe, crea nuevo chat con estructura base de "unread"
      final newChat = await _firestore.collection('chats').add({
        'participants': [currentUid, otherUserId],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'unread': {
          currentUid: 0,
          otherUserId: 0,
        },
      });

      return newChat.id;
    } catch (e) {
      print('Error creando/obteniendo chat: $e');
      return null;
    }
  }

  // ============================================================
  // 🔹 Envía un mensaje (texto o imagen)
  // ============================================================
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String imageUrl = '',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || (text.trim().isEmpty && imageUrl.isEmpty)) return;

    try {
      final msgData = {
        'senderId': uid,
        'text': text.trim(),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Añadir mensaje
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(msgData);

      final chatRef = _firestore.collection('chats').doc(chatId);

      // ✅ Actualiza metadatos y contador de "unread" para el otro usuario
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(chatRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        final unreadMap = Map<String, dynamic>.from(data['unread'] ?? {});

        for (var p in participants) {
          if (p != uid) {
            unreadMap[p] = (unreadMap[p] ?? 0) + 1; // 🔺 Incrementa contador
          }
        }

        tx.update(chatRef, {
          'lastMessage': imageUrl.isNotEmpty ? '📸 Imagen' : text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unread': unreadMap,
        });
      });
    } catch (e) {
      print('Error enviando mensaje: $e');
    }
  }

  // ============================================================
  // 🔹 Marca los mensajes del chat como leídos para el usuario actual
  // ============================================================
  Future<void> markChatAsRead(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final chatRef = _firestore.collection('chats').doc(chatId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(chatRef);
        if (!snap.exists) return;

        final data = snap.data()!;
        final unread = Map<String, dynamic>.from(data['unread'] ?? {});
        unread[uid] = 0; // 🔄 Reset del contador para el usuario actual

        tx.update(chatRef, {'unread': unread});
      });
    } catch (e) {
      print('Error marcando como leído: $e');
    }
  }

  // ============================================================
  // 🔹 Escucha en tiempo real los mensajes de un chat
  // ============================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // 🔹 Elimina un chat completo (opcional)
  // ============================================================
  Future<void> deleteChat(String chatId) async {
    try {
      final msgsRef =
          _firestore.collection('chats').doc(chatId).collection('messages');
      final msgs = await msgsRef.get();
      for (var m in msgs.docs) {
        await m.reference.delete();
      }
      await _firestore.collection('chats').doc(chatId).delete();
    } catch (e) {
      print('Error eliminando chat: $e');
    }
  }

  // ============================================================
  // 🔔 Stream del número total de chats con mensajes no leídos
  // ============================================================
  Stream<int> getUnreadCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int count = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        final unreadMap = (data['unread'] ?? {}) as Map<String, dynamic>;
        final unread = unreadMap[uid];
        if (unread != null && unread is int && unread > 0) count++;
      }
      return count;
    });
  }
}