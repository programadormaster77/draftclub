import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/social/data/chat_service.dart';
import 'package:draftclub_mobile/features/social/presentation/page/chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 💬 ChatListPage — Bandeja de entrada (Mensajería directa PRO++)
/// ============================================================================
/// ✅ Muestra todos los chats del usuario actual.
/// ✅ Escucha actualizaciones en tiempo real desde Firestore.
/// ✅ Muestra nombre, avatar, último mensaje y hora.
/// ✅ Tolerante a datos incompletos (sin `updatedAt`, etc.)
/// ============================================================================
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    final auth = FirebaseAuth.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Mensajes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.4,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _safeChatStream(service),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          if (snap.hasError) {
            debugPrint("🔥 Error cargando chats: ${snap.error}");
            return const Center(
              child: Text(
                'Error al cargar los chats',
                style: TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Aún no tienes conversaciones',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10),
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 0.3,
              color: Colors.white10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final chat = docs[i].data() as Map<String, dynamic>? ?? {};
              final chatId = docs[i].id;
              final participants =
                  (chat['participants'] as List?)?.cast<String>() ?? [];

              final currentUid = auth.currentUser?.uid;
              if (currentUid == null || participants.isEmpty) {
                return const SizedBox.shrink();
              }

              final otherUid = participants.firstWhere(
                (uid) => uid != currentUid,
                orElse: () => '',
              );

              if (otherUid.isEmpty) return const SizedBox.shrink();

              final lastMessage = (chat['lastMessage'] ?? '') as String;
              final updatedAt = (chat['updatedAt'] is Timestamp)
                  ? (chat['updatedAt'] as Timestamp).toDate()
                  : null;

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final user =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final name =
                      (user['name'] ?? user['nickname'] ?? 'Usuario') as String;
                  final photo = (user['photoUrl'] ?? '') as String;
                  final time = updatedAt != null ? _formatTime(updatedAt) : '';

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage:
                          photo.isNotEmpty ? NetworkImage(photo) : null,
                      backgroundColor: Colors.white12,
                      child: photo.isEmpty
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 22)
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      lastMessage.isNotEmpty ? lastMessage : 'Mensaje vacío',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            chatId: chatId,
                            otherUserId: otherUid,
                            otherName: name,
                            otherPhoto: photo,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// ============================================================
  /// 🛡️ Fallback seguro si `orderBy('updatedAt')` lanza error
  /// ============================================================
  Stream<QuerySnapshot> _safeChatStream(ChatService service) {
    try {
      return service.getUserChats();
    } catch (e) {
      debugPrint('⚠️ Error en stream principal: $e');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const Stream.empty();
      return FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .snapshots(); // ✅ sin orderBy, pero evita crash
    }
  }

  /// 🔹 Formatea la hora o día del último mensaje
  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } else if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return days[time.weekday - 1];
    } else {
      return "${time.day}/${time.month}";
    }
  }
}