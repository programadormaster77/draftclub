import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../models/message_model.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();

    // Detecta duración real del audio
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _audioDuration = d);
    });

    // Cuando termina la reproducción
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    // ------------------------------
    // 🧠 MENSAJE DE SISTEMA
    // ------------------------------
    if (msg.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return _buildBubble(msg);
  }

  // ============================================================
  // 🔊 AUDIO PLAYER PROFESIONAL
  // ============================================================
  Widget _buildAudioPlayer(String url) {
    final totalSecs = _audioDuration?.inSeconds ?? 0;

    final timeLabel = (totalSecs <= 0)
        ? "--:--"
        : "${(totalSecs ~/ 60)}:${(totalSecs % 60).toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(.85),
            Colors.blue.shade600.withOpacity(.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _player.stop();
                if (!mounted) return;
                setState(() => _isPlaying = false);
              } else {
                await _player.stop();
                await _player.play(UrlSource(url));
                if (!mounted) return;
                setState(() => _isPlaying = true);
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(.25),
              child: Icon(
                _isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 70,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeLabel,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 💬 BURBUJA GENERAL
  // ============================================================
  Widget _buildBubble(Message msg) {
    final isMine = widget.isMine;

    final bubbleColor =
        isMine ? const Color(0xFF246BFD) : const Color(0xFF1C1C1E);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
      bottomRight: isMine ? Radius.zero : const Radius.circular(16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  (msg.avatarUrl != null && msg.avatarUrl!.isNotEmpty)
                      ? NetworkImage(msg.avatarUrl!)
                      : null,
              child: (msg.avatarUrl == null || msg.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: msg.type == "image" ? 0 : 14,
                    vertical: msg.type == "image" ? 0 : 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        msg.type == "image" ? Colors.transparent : bubbleColor,
                    borderRadius: radius,
                  ),
                  child: _buildContent(msg),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔄 CONTENIDO: TEXTO / IMAGEN / AUDIO
  // ============================================================
  Widget _buildContent(Message msg) {
    switch (msg.type) {
      // ----------------------------------------------------------
      // 🖼 IMAGEN ESTÉTICA SIN MARCOS FEOS
      // ----------------------------------------------------------
      case 'image':
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      child: Center(
                        child: Image.network(msg.text, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            size: 30, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 260,
                maxHeight: 320,
              ),
              child: Image.network(
                msg.text,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );

      // ----------------------------------------------------------
      // 🎧 AUDIO
      // ----------------------------------------------------------
      case 'voice':
        return _buildAudioPlayer(msg.text);

      // ----------------------------------------------------------
      // 📄 TEXTO NORMAL
      // ----------------------------------------------------------
      default:
        return SelectableText(
          msg.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        );
    }
  }

  // ============================================================
  // 🕒 FORMATO DE HORA
  // ============================================================
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

      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}
