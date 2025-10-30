import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/message_model.dart';

/// ====================================================================
/// 💬 MessageBubble — Burbuja de mensaje estilo "Arena Chat Pro"
/// ====================================================================
/// 🔹 Muestra avatar, nombre, rango y texto.
/// 🔹 Diferencia mensajes propios, ajenos y de sistema.
/// 🔹 Incluye animación, sombras y formato de hora.
/// 🔹 Totalmente adaptable a múltiples líneas.
/// ====================================================================
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    // 🧠 Mensajes del sistema (sin avatar ni burbuja de color)
    if (message.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Configuración visual
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(0),
      bottomRight:
          isMine ? const Radius.circular(0) : const Radius.circular(16),
    );

    final Color bubbleColor =
        isMine ? const Color(0xFF246BFD) : const Color(0xFF1C1C1E);
    final Color textColor = Colors.white;
    final TextAlign textAlign = isMine ? TextAlign.right : TextAlign.left;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧍‍♂️ Avatar (solo si no es mío)
          if (!isMine)
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueGrey.shade800,
              backgroundImage:
                  (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                      ? NetworkImage(message.avatarUrl!)
                      : null,
              child: (message.avatarUrl == null || message.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white70, size: 20)
                  : null,
            ),

          const SizedBox(width: 8),

          // 💬 Contenedor del mensaje
          Flexible(
            child: Column(
              crossAxisAlignment: align,
              children: [
                // 🏷 Nombre (solo si no es mío)
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (message.rank != null && message.rank!.isNotEmpty)
                          Text(
                            message.rank!,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),

                // 💬 Texto del mensaje
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.text,
                    textAlign: textAlign,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),

                // 🕒 Hora del mensaje
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🕒 Formatea la hora de envío (segura para cualquier tipo de campo)
  String _formatTime(dynamic ts) {
    try {
      DateTime dt;
      if (ts is Timestamp) {
        dt = ts.toDate();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        dt = DateTime.now();
      }

      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
