import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📦 Importaciones locales (rutas relativas desde /presentation/chat)
import '../../models/room_model.dart';
import '../../models/message_model.dart';
import '../../data/chat_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';

class ChatRoomPage extends StatelessWidget {
  final Room room;
  ChatRoomPage({super.key, required this.room});

  final _auth = FirebaseAuth.instance;
  final _chat = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Chat — ${room.name}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chat.streamRoomChat(room.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay mensajes',
                        style: TextStyle(color: Colors.white54)),
                  );
                }
                final myId = _auth.currentUser?.uid;
                return ListView.builder(
                  reverse: true, // los más nuevos arriba
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMine = m.senderId == myId;
                    return MessageBubble(message: m, isMine: isMine);
                  },
                );
              },
            ),
          ),
          MessageInput(
            onSend: (text) async => _chat.sendRoomMessage(
              roomId: room.id,
              text: text,
              senderName: _auth.currentUser?.displayName ?? 'Usuario',
            ),
          ),
        ],
      ),
    );
  }
}
