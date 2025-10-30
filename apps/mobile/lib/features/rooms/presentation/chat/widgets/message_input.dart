import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/chat_service.dart';

/// ====================================================================
/// 🎤 MessageInput — Campo de entrada “Arena Chat Pro” (versión extendida)
/// ====================================================================
/// 🔹 Envía texto, imágenes y audios (notas de voz)
/// 🔹 Diseño oscuro, limpio y moderno
/// 🔹 Compatible con ChatService actualizado
/// 🔹 Envia con Enter o botón de enviar
/// ====================================================================
class MessageInput extends StatefulWidget {
  final Future<void> Function(String text)? onSendText;
  final String? roomId;
  final String? teamId;
  final bool isTeamChat;
  final String senderName;

  const MessageInput({
    super.key,
    this.onSendText,
    this.roomId,
    this.teamId,
    this.isTeamChat = false,
    required this.senderName,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ChatService _chat = ChatService();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  bool _sending = false;
  bool _recording = false;

  // ======================= ENVIAR TEXTO =======================
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (widget.onSendText != null) {
        await widget.onSendText!(text);
      } else if (widget.isTeamChat) {
        await _chat.sendTeamMessage(
          roomId: widget.roomId!,
          teamId: widget.teamId!,
          text: text,
          senderName: widget.senderName,
        );
      } else {
        await _chat.sendRoomMessage(
          roomId: widget.roomId!,
          text: text,
          senderName: widget.senderName,
        );
      }

      _ctrl.clear();
      _focus.requestFocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ======================= ENVIAR IMAGEN =======================
  Future<void> _pickImage() async {
    try {
      final xfile = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (xfile == null) return;

      final file = File(xfile.path);

      if (widget.isTeamChat) {
        await _chat.sendTeamImage(
          roomId: widget.roomId!,
          teamId: widget.teamId!,
          file: file,
        );
      } else {
        await _chat.sendRoomImage(
          roomId: widget.roomId!,
          file: file,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📸 Imagen enviada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la imagen: $e')),
      );
    }
  }

  // ======================= GRABAR AUDIO =======================
  Future<void> _toggleRecord() async {
    try {
      if (_recording) {
        // ⏹️ Detener grabación y enviar
        final path = await _recorder.stop();
        setState(() => _recording = false);

        if (path == null) return;
        final file = File(path);

        if (widget.isTeamChat) {
          await _chat.sendTeamAudio(
            roomId: widget.roomId!,
            teamId: widget.teamId!,
            file: file,
          );
        } else {
          await _chat.sendRoomAudio(
            roomId: widget.roomId!,
            file: file,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎤 Nota de voz enviada')),
        );
      } else {
        // 🎙️ Iniciar grabación
        final hasPerm = await _recorder.hasPermission();
        if (!hasPerm) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de micrófono denegado')),
          );
          return;
        }

        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/dc_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        setState(() => _recording = true);
      }
    } catch (e) {
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al grabar o enviar audio: $e')),
      );
    }
  }

  // ======================= INTERFAZ =======================
  @override
  Widget build(BuildContext context) {
    final micColor = _recording ? Colors.redAccent : Colors.blueAccent;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ➕ Botón de IMAGEN
            IconButton(
              onPressed: _sending ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: Colors.white38, size: 26),
              tooltip: "Enviar imagen",
            ),

            // 📝 Campo de texto
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Scrollbar(
                  radius: const Radius.circular(12),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    enabled: !_sending,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 🎙️ Botón MIC
            IconButton(
              onPressed: _sending ? null : _toggleRecord,
              icon: Icon(
                _recording ? Icons.stop_circle_outlined : Icons.mic_rounded,
                color: micColor,
                size: 26,
              ),
              tooltip: _recording ? "Detener y enviar" : "Grabar nota de voz",
            ),

            const SizedBox(width: 6),

            // 🚀 Botón ENVIAR
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _sending
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blueAccent,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('send'),
                      onPressed: _sendText,
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.blueAccent, size: 26),
                      tooltip: "Enviar mensaje",
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _recorder.dispose();
    super.dispose();
  }
}
