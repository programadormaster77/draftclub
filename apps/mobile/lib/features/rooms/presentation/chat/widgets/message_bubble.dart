import 'package:flutter/material.dart';
import '../../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;

  const MessageBubble({super.key, required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? Colors.blueAccent : const Color(0xFF1E1E1E);
    final fg = isMine ? Colors.white : Colors.white;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            message.senderName.isEmpty ? 'Usuario' : message.senderName,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(message.text, style: TextStyle(color: fg, fontSize: 15)),
        ),
      ],
    );
  }
}
