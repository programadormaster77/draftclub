import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧩 NotificationModel — Modelo fuerte para notificaciones en DraftClub
/// ============================================================================
/// Pensado para colecciones como:
/// - `users/{uid}/notifications/{notifId}`  (inbox por usuario)
/// - o una colección general `notifications/{notifId}` con `recipientId`
///
/// Incluye:
/// - Tipado del `type`
/// - Deep link (`link`) para navegar (ej: draftclub://room/<id>)
/// - Marcado de lectura (`read`)
/// - `createdAt` ordenable (Timestamp)
/// - Campos flexibles en `data` para payloads adicionales
/// ============================================================================

enum NotificationType {
  post, // nuevo post de alguien que sigo
  roomCreated, // nueva sala en mi ciudad
  roomUpdated, // cambios de hora/lugar/cupos
  roomJoin, // alguien entró a una sala donde participo
  teamMessage, // mensaje en chat de equipo
  roomMessage, // mensaje en chat global de sala
  directMessage, // mensaje directo (DM)
  follow, // alguien me siguió / aceptó solicitud
  xp, // logros / hitos
  campaign, // campañas admin/marketing
  other, // fallback
}

extension NotificationTypeX on NotificationType {
  String get nameStr => toString().split('.').last;

  static NotificationType fromString(String? raw) {
    switch (raw) {
      case 'post':
        return NotificationType.post;
      case 'roomCreated':
        return NotificationType.roomCreated;
      case 'roomUpdated':
        return NotificationType.roomUpdated;
      case 'roomJoin':
        return NotificationType.roomJoin;
      case 'teamMessage':
        return NotificationType.teamMessage;
      case 'roomMessage':
        return NotificationType.roomMessage;
      case 'directMessage':
        return NotificationType.directMessage;
      case 'follow':
        return NotificationType.follow;
      case 'xp':
        return NotificationType.xp;
      case 'campaign':
        return NotificationType.campaign;
      default:
        return NotificationType.other;
    }
  }
}

class NotificationModel {
  final String id; // doc id
  final NotificationType type; // tipo de notificación
  final String title; // título visible
  final String body; // cuerpo visible
  final String? link; // deep link ej: draftclub://room/<id>
  final String? topic; // ej: city_bogota, room_abcd
  final String? senderId; // quién originó (autor, sistema)
  final String recipientId; // a quién va (uid)
  final Map<String, dynamic> data; // payload extra (postId, roomId, etc.)
  final bool read; // leído por el usuario
  final Timestamp createdAt; // timestamp de creación

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.recipientId,
    required this.createdAt,
    this.link,
    this.topic,
    this.senderId,
    this.data = const {},
    this.read = false,
  });

  /// 🏭 Crea a partir de Firestore (DocumentSnapshot)
  factory NotificationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return NotificationModel.fromMap(doc.id, map);
  }

  /// 🏭 Crea a partir de Map
  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      type: NotificationTypeX.fromString(map['type'] as String?),
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      link: map['link'] as String?,
      topic: map['topic'] as String?,
      senderId: map['senderId'] as String?,
      recipientId: (map['recipientId'] ?? '') as String,
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      read: (map['read'] ?? false) as bool,
      createdAt: _ts(map['createdAt']),
    );
  }

  /// 🔁 Serializa a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type.nameStr,
      'title': title,
      'body': body,
      'link': link,
      'topic': topic,
      'senderId': senderId,
      'recipientId': recipientId,
      'data': data,
      'read': read,
      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({
    NotificationType? type,
    String? title,
    String? body,
    String? link,
    String? topic,
    String? senderId,
    String? recipientId,
    Map<String, dynamic>? data,
    bool? read,
    Timestamp? createdAt,
  }) {
    return NotificationModel(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      link: link ?? this.link,
      topic: topic ?? this.topic,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ✅ Helper seguro para marcar como leído
  NotificationModel markRead() => copyWith(read: true);

  /// 🔗 Helper para fabricar links estándar según tipo/IDs
  /// Ejemplos:
  ///   buildDeepLinkFor(type: NotificationType.roomMessage, id: 'abc') =>
  ///     draftclub://room/abc
  static String buildDeepLinkFor({
    required NotificationType type,
    String? roomId,
    String? postId,
    String? userId,
  }) {
    switch (type) {
      case NotificationType.roomCreated:
      case NotificationType.roomUpdated:
      case NotificationType.roomJoin:
      case NotificationType.roomMessage:
        if (roomId != null) return 'draftclub://room/$roomId';
        break;
      case NotificationType.post:
        if (postId != null) return 'draftclub://post/$postId';
        break;
      case NotificationType.follow:
      case NotificationType.directMessage:
        if (userId != null) return 'draftclub://user/$userId';
        break;
      case NotificationType.teamMessage:
        // Puedes redirigir a la sala del equipo o a una vista de chat de equipo
        if (roomId != null) return 'draftclub://room/$roomId';
        break;
      case NotificationType.xp:
      case NotificationType.campaign:
      case NotificationType.other:
        break;
    }
    return 'draftclub://home';
  }

  @override
  String toString() {
    return 'NotificationModel(id: $id, type: ${type.nameStr}, title: $title, recipientId: $recipientId, read: $read, createdAt: $createdAt)';
  }
}

/// 🔧 Conversión segura de createdAt
Timestamp _ts(dynamic v) {
  if (v is Timestamp) return v;
  if (v is DateTime) return Timestamp.fromDate(v);
  return Timestamp.now();
}
