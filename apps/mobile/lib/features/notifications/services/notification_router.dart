import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:draftclub_mobile/features/rooms/presentation/room_detail_page.dart';
import 'package:draftclub_mobile/features/rooms/models/room_model.dart';
import 'package:draftclub_mobile/features/feed/presentation/dashboard_page.dart';
import 'package:draftclub_mobile/features/profile/presentation/profile_page.dart';

/// ============================================================================
/// 🔀 NotificationRouter — Maneja navegación desde notificaciones push/local
/// ============================================================================
/// Este router interpreta el payload o enlace `draftclub://` y abre la
/// pantalla correcta (sala, publicación, perfil, etc.).
/// ============================================================================
class NotificationRouter {
  /// Navega según el tipo de enlace o payload
  static Future<void> handleNavigation(BuildContext context, Uri uri) async {
    try {
      debugPrint('🧭 NotificationRouter → Navegando a: $uri');

      // Ejemplo: draftclub://room/<id>
      if (uri.scheme == 'draftclub' && uri.host == 'room') {
        final roomId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (roomId != null) {
          await _openRoom(context, roomId);
          return;
        }
      }

      // Ejemplo: draftclub://post/<id>
      if (uri.scheme == 'draftclub' && uri.host == 'post') {
        final postId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (postId != null) {
          await _openFeed(context, highlightPostId: postId);
          return;
        }
      }

      // Ejemplo: draftclub://user/<uid>
      if (uri.scheme == 'draftclub' && uri.host == 'user') {
        final uid = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (uid != null) {
          await _openUserProfile(context, uid);
          return;
        }
      }

      // Si no hay coincidencia → lleva al inicio
      await _openFeed(context);
    } catch (e) {
      debugPrint('⚠️ Error al manejar notificación: $e');
    }
  }

  /// 🏟️ Abre sala de fútbol
  static Future<void> _openRoom(BuildContext context, String roomId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    try {
      final snap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();

      Navigator.of(context).pop();

      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró la sala.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final room = Room.fromMap(snap.data()!);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir la sala: $e')),
      );
    }
  }

  /// 📰 Abre el feed y resalta un post (si se indica)
  static Future<void> _openFeed(BuildContext context,
      {String? highlightPostId}) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardPage(highlightPostId: highlightPostId),
      ),
    );
  }

  /// 👤 Abre perfil de usuario
  static Future<void> _openUserProfile(
      BuildContext context, String userId) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
  }
}
