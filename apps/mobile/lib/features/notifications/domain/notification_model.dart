// 📄 apps/mobile/lib/features/notifications/domain/notification_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧩 NotificationModel — Modelo base de notificación en DraftClub
/// ============================================================================
/// Usado tanto para notificaciones automáticas como enviadas por administradores.
/// Soporta mensajes globales, personales o segmentados.
/// ============================================================================
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // general | room | message | admin | promo
  final String? targetUserId;
  final String? targetCity;
  final String? targetCountry;
  final String? imageUrl;
  final DateTime createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.targetUserId,
    this.targetCity,
    this.targetCountry,
    this.imageUrl,
    required this.createdAt,
    this.read = false,
  });

  /// 🏗️ Crear desde Firestore
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'general',
      targetUserId: data['targetUserId'],
      targetCity: data['targetCity'],
      targetCountry: data['targetCountry'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  /// 🔄 Convertir a mapa para subir a Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'targetUserId': targetUserId,
      'targetCity': targetCity,
      'targetCountry': targetCountry,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? targetUserId,
    String? targetCity,
    String? targetCountry,
    String? imageUrl,
    DateTime? createdAt,
    bool? read,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      targetUserId: targetUserId ?? this.targetUserId,
      targetCity: targetCity ?? this.targetCity,
      targetCountry: targetCountry ?? this.targetCountry,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}
