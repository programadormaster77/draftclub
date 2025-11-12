import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// ============================================================================
/// 💬 ChatPage — Conversación individual (Mensajería directa PRO++)
/// ============================================================================
/// ✅ Carga mensajes en tiempo real.
/// ✅ Envía texto e imágenes.
/// ✅ Actualiza automáticamente lastMessage y updatedAt.
/// ✅ Marca el chat como leído.
/// ✅ Scroll automático al final.
/// ✅ Maneja campos nulos de forma segura.
/// ============================================================================
class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherName;
  final String otherPhoto;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherName,
    required this.otherPhoto,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _service = ChatService();

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _service.markChatAsRead(widget.chatId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage({String? text, File? imageFile}) async {
    if ((text == null || text.trim().isEmpty) && imageFile == null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null || _sending) return;

    setState(() => _sending = true);

    try {
      String? imageUrl;
      String lastMsgPreview = '';

      if (imageFile != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${uid}.jpg';
        final ref = _storage
            .ref()
            .child('chats/${widget.chatId}/$fileName');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
        lastMsgPreview = '📸 Imagen';
      }

      if (text != null && text.trim().isNotEmpty) {
        lastMsgPreview = text.trim();
      }

      await _service.sendMessage(
        chatId: widget.chatId,
        text: text ?? '',
        imageUrl: imageUrl ?? '',
      );

      _msgCtrl.clear();
      _scrollToBottom();
      _service.markChatAsRead(widget.chatId);
    } catch (e) {
      debugPrint('⚠️ Error enviando mensaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      await _sendMessage(imageFile: File(picked.path));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMyMessage(String senderId) => senderId == _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherPhoto.isNotEmpty
                  ? NetworkImage(widget.otherPhoto)
                  : null,
              backgroundColor: Colors.white12,
              child: widget.otherPhoto.isEmpty
                  ? const Icon(Icons.person, color: Colors.white70, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ========================= MENSAJES =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint("🔥 Error cargando mensajes: ${snap.error}");
                  return const Center(
                    child: Text(
                      'Error al cargar mensajes',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                final messages = snap.data?.docs ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay mensajes',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                if (_firstLoad) {
                  _firstLoad = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                    _service.markChatAsRead(widget.chatId);
                  });
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i].data();
                    final isMe = _isMyMessage(msg['senderId']);
                    final text = (msg['text'] ?? '') as String;
                    final imageUrl = (msg['imageUrl'] ?? '') as String;
                    final createdAt = (msg['createdAt'] is Timestamp)
                        ? (msg['createdAt'] as Timestamp).toDate()
                        : null;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blueAccent.withOpacity(0.85)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrl,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white30,
                                      size: 60),
                                ),
                              ),
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  text,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            if (createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _formatTime(createdAt),
                                  style: TextStyle(
                                    color: Colors.white70.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ========================= INPUT BAR =========================
          SafeArea(
            child: Container(
              color: const Color(0xFF1A1A1A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined,
                        color: Colors.white70),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blueAccent,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send,
                              color: Colors.blueAccent),
                          onPressed: () =>
                              _sendMessage(text: _msgCtrl.text.trim()),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}