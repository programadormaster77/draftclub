import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📦 Importaciones locales (rutas relativas desde /presentation/chat)
import '../../data/chat_service.dart';
import '../../models/message_model.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';

/// ====================================================================
/// 💬 ChatTeamPage — Chat interno de cada equipo
/// ====================================================================
/// 🔹 Muestra mensajes en tiempo real de un equipo dentro de una sala.
/// 🔹 Permite enviar mensajes con el nombre del usuario autenticado.
/// 🔹 Sincroniza con Firestore → rooms/{roomId}/teams/{teamId}/messages.
/// ====================================================================
class ChatTeamPage extends StatelessWidget {
  final String roomId;
  final String teamId;
  final String teamName;

  ChatTeamPage({
    super.key,
    required this.roomId,
    required this.teamId,
    required this.teamName,
  });

  final _auth = FirebaseAuth.instance;
  final _chat = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Chat — $teamName'),
      ),
      body: Column(
        children: [
          // ====================== MENSAJES ======================
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chat.streamTeamChat(roomId, teamId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay mensajes',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final myId = _auth.currentUser?.uid;
                return ListView.builder(
                  reverse: true, // 📲 mensajes más recientes al final
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    return MessageBubble(
                      message: m,
                      isMine: m.senderId == myId,
                    );
                  },
                );
              },
            ),
          ),

          // ====================== INPUT DE MENSAJES ======================
          MessageInput(
            onSend: (text) async {
              if (text.trim().isEmpty) return;
              await _chat.sendTeamMessage(
                roomId: roomId,
                teamId: teamId,
                text: text.trim(),
                senderName: _auth.currentUser?.displayName ?? 'Jugador',
              );
            },
          ),
        ],
      ),
    );
  }
}
