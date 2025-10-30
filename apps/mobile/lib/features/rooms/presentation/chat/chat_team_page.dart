import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/chat_service.dart';
import '../../models/message_model.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';

/// ====================================================================
/// 💬 ChatTeamPage — Chat avanzado del equipo (Arena Chat Pro)
/// ====================================================================
/// 🔹 Muestra mensajes en tiempo real, con fotos, rangos y roles.
/// 🔹 Integra eventos de sistema (“Jugador se unió/salió”).
/// 🔹 Scroll automático, diseño moderno, y colores del tema.
/// 🔹 Canal: rooms/{roomId}/teams/{teamId}/messages.
/// ====================================================================
class ChatTeamPage extends StatefulWidget {
  final String roomId;
  final String teamId;
  final String teamName;

  const ChatTeamPage({
    super.key,
    required this.roomId,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<ChatTeamPage> createState() => _ChatTeamPageState();
}

class _ChatTeamPageState extends State<ChatTeamPage> {
  final _auth = FirebaseAuth.instance;
  final _chat = ChatService();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// ===============================================================
  /// 🧠 Envía mensaje (texto o evento de sistema)
  /// ===============================================================
  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;

    await _chat.sendTeamMessage(
      roomId: widget.roomId,
      teamId: widget.teamId,
      text: text.trim(),
      senderName: user.displayName ?? 'Jugador',
    );
  }

  /// ===============================================================
  /// 🪄 Envía un mensaje de sistema
  /// ===============================================================
  Future<void> _sendSystemEvent(String message) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('teams')
        .doc(widget.teamId)
        .collection('messages')
        .add({
      'text': message,
      'senderName': 'Sistema',
      'senderId': 'system',
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('Chat — ${widget.teamName}'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ====================== MENSAJES ======================
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chat.streamTeamChat(widget.roomId, widget.teamId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent),
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

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];

                      // 💬 Mensaje de sistema (sin avatar)
                      if (msg.type == 'system') {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }

                      // 💬 Mensaje normal (usuario)
                      return MessageBubble(
                        message: msg,
                        isMine: msg.senderId == currentUid,
                      );
                    },
                  );
                },
              ),
            ),

            // ====================== INPUT DE MENSAJES ======================
            MessageInput(
              roomId: widget.roomId,
              teamId: widget.teamId,
              isTeamChat: true,
              senderName: _auth.currentUser?.displayName ?? 'Jugador',
            ),
          ],
        ),
      ),
    );
  }
}
