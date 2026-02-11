// 📄 apps/mobile/lib/features/notifications/domain/admin_notification_model.dart
//
// 🧠 AdminNotificationModel — Modelo completo de campañas y notificaciones administrativas
//
// ✔ Define estructura para notificaciones avanzadas con segmentación, prioridad, programación y métricas.
// ✔ Compatible con Firebase Firestore y Cloud Functions (Node 20 / FCM).
// ✔ Incluye validación de campos y builder de payload para FCM (Android/iOS).
//
// Autor: Brandon Rocha (DraftClub)
// Actualizado: 2025-11-07
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🎯 Tipos de destino (audiencia) para campañas admin
/// ============================================================================
enum AdminTargetType {
  global,
  country,
  city,
  role,
  user,
  segment,
  topic,
}

/// ============================================================================
/// 👥 Segmentos lógicos (actividad o tipo de usuario)
/// ============================================================================
enum AdminSegment {
  active7d,
  inactive24h,
  vip,
  referees,
  creators,
}

/// ============================================================================
/// ⚡ Prioridad percibida de la notificación
/// ============================================================================
enum AdminPriority { normal, high }

/// ============================================================================
/// 📦 Estado de la campaña/admin notification
/// ============================================================================
enum AdminStatus { draft, scheduled, sending, sent, canceled, failed }

/// ============================================================================
/// 🧠 AdminNotificationModel — Campañas administrativas/segmentadas
/// ============================================================================
class AdminNotificationModel {
  // 📛 Identificación
  final String id;

  // 📰 Contenido
  final String title;
  final String body;
  final String type; // "admin" | "promo" | "system" | "general"
  final String? imageUrl;
  final String? deepLink;

  // 🎯 Audiencia / Segmentación
  final AdminTargetType targetType;
  final String? targetValue;
  final AdminSegment? segment;
  final List<String>? userIds;

  // 🌎 Campos nuevos para segmentación
  final String? country;
  final String? city;
  final String? role;

  // ⚙️ Preferencias
  final bool marketing;
  final bool respectDnd;

  // 🚦 Control de prioridad y envío
  final AdminPriority priority;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final int? rateLimitPerMinute;
  final bool? deduplicate;

  // 📊 Métricas
  final AdminStatus status;
  final int sentCount;
  final int deliveredCount;
  final int openedCount;
  final int errorCount;

  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'admin',
    this.imageUrl,
    this.deepLink,
    required this.targetType,
    this.targetValue,
    this.segment,
    this.userIds,
    this.country,
    this.city,
    this.role,
    this.marketing = false,
    this.respectDnd = true,
    this.priority = AdminPriority.normal,
    required this.createdAt,
    required this.createdBy,
    this.scheduledAt,
    this.expiresAt,
    this.rateLimitPerMinute,
    this.deduplicate = true,
    this.status = AdminStatus.draft,
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.openedCount = 0,
    this.errorCount = 0,
  });

  // ==========================================================================
  // 🔍 Validación lógica (útil para UI o pre-envío)
  // ==========================================================================
  List<String> validate() {
    final issues = <String>[];

    if (title.trim().isEmpty) issues.add('El título no puede estar vacío.');
    if (body.trim().isEmpty) issues.add('El cuerpo no puede estar vacío.');

    switch (targetType) {
      case AdminTargetType.global:
        break;
      case AdminTargetType.country:
        if (country?.trim().isEmpty ?? true) {
          issues.add('Debes especificar el país destino.');
        }
        break;
      case AdminTargetType.city:
        if (city?.trim().isEmpty ?? true) {
          issues.add('Debes especificar la ciudad destino.');
        }
        break;
      case AdminTargetType.role:
        if (role?.trim().isEmpty ?? true) {
          issues.add('Debes especificar el rol de usuario.');
        }
        break;
      case AdminTargetType.user:
        if (userIds == null || userIds!.isEmpty) {
          issues.add('Debes indicar al menos un UID de usuario.');
        }
        break;
      case AdminTargetType.segment:
        if (segment == null) {
          issues.add('Selecciona un segmento de usuarios.');
        }
        break;
      case AdminTargetType.topic:
        if (targetValue?.trim().isEmpty ?? true) {
          issues.add('Debes especificar el nombre del tópico FCM.');
        }
        break;
    }

    if (scheduledAt != null && expiresAt != null) {
      if (!expiresAt!.isAfter(scheduledAt!)) {
        issues.add('La fecha de expiración debe ser posterior a la de envío.');
      }
    }

    return issues;
  }

  // ==========================================================================
  // 🔁 Conversión a Map (para Firestore)
  // ==========================================================================
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'targetType': targetType.name,
      'targetValue': targetValue,
      'segment': segment?.name,
      'userIds': userIds,
      'country': country,
      'city': city,
      'role': role,
      'marketing': marketing,
      'respectDnd': respectDnd,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'scheduledAt':
          scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'rateLimitPerMinute': rateLimitPerMinute,
      'deduplicate': deduplicate,
      'status': status.name,
      'metrics': {
        'sent': sentCount,
        'delivered': deliveredCount,
        'opened': openedCount,
        'errors': errorCount,
      },
    };
  }

  // ==========================================================================
  // 🔄 Desde Firestore
  // ==========================================================================
  factory AdminNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    final metrics = Map<String, dynamic>.from(data['metrics'] ?? {});

    AdminTargetType parseTarget(String? v) => AdminTargetType.values.firstWhere(
          (e) => e.name == v,
          orElse: () => AdminTargetType.global,
        );

    AdminSegment? parseSegment(String? v) => v == null
        ? null
        : AdminSegment.values.firstWhere(
            (e) => e.name == v,
            orElse: () => AdminSegment.active7d,
          );

    AdminPriority parsePriority(String? v) => AdminPriority.values.firstWhere(
          (e) => e.name == v,
          orElse: () => AdminPriority.normal,
        );

    AdminStatus parseStatus(String? v) => AdminStatus.values.firstWhere(
          (e) => e.name == v,
          orElse: () => AdminStatus.draft,
        );

    return AdminNotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'admin',
      imageUrl: data['imageUrl'],
      deepLink: data['deepLink'],
      targetType: parseTarget(data['targetType']),
      targetValue: data['targetValue'],
      segment: parseSegment(data['segment']),
      userIds: (data['userIds'] as List?)?.map((e) => e.toString()).toList(),
      country: data['country'],
      city: data['city'],
      role: data['role'],
      marketing: data['marketing'] ?? false,
      respectDnd: data['respectDnd'] ?? true,
      priority: parsePriority(data['priority']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? 'unknown',
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      rateLimitPerMinute: data['rateLimitPerMinute'],
      deduplicate: data['deduplicate'] ?? true,
      status: parseStatus(data['status']),
      sentCount: (metrics['sent'] ?? 0) as int,
      deliveredCount: (metrics['delivered'] ?? 0) as int,
      openedCount: (metrics['opened'] ?? 0) as int,
      errorCount: (metrics['errors'] ?? 0) as int,
    );
  }

  // ==========================================================================
  // ✉️ Builder de payload para FCM (Android / iOS)
  // ==========================================================================
  Map<String, dynamic> toFcmPayload({
    required String messageId,
    String androidChannelId = 'draftclub_general',
    bool playSound = true,
    String androidSound = 'referee_whistle',
    String iosSound = 'referee_whistle.caf',
  }) {
    final data = <String, String>{
      'messageId': messageId,
      'type': type,
      if (deepLink != null) 'deepLink': deepLink!,
    };

    final notification = <String, String>{
      'title': title,
      'body': body,
    };

    final android = {
      'priority': priority == AdminPriority.high ? 'high' : 'normal',
      'notification': {
        'channel_id': androidChannelId,
        if (playSound) 'sound': androidSound,
      },
    };

    final apns = {
      'headers': {
        'apns-priority': priority == AdminPriority.high ? '10' : '5',
      },
      'payload': {
        'aps': {
          if (playSound) 'sound': iosSound,
          'content-available': 1,
        },
      },
    };

    return {
      'notification': notification,
      'data': data,
      'android': android,
      'apns': apns,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image': imageUrl,
    };
  }

  // ==========================================================================
  // 🧱 Copia modificable
  // ==========================================================================
  AdminNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? imageUrl,
    String? deepLink,
    AdminTargetType? targetType,
    String? targetValue,
    AdminSegment? segment,
    List<String>? userIds,
    String? country,
    String? city,
    String? role,
    bool? marketing,
    bool? respectDnd,
    AdminPriority? priority,
    DateTime? createdAt,
    String? createdBy,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? rateLimitPerMinute,
    bool? deduplicate,
    AdminStatus? status,
    int? sentCount,
    int? deliveredCount,
    int? openedCount,
    int? errorCount,
  }) {
    return AdminNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      segment: segment ?? this.segment,
      userIds: userIds ?? this.userIds,
      country: country ?? this.country,
      city: city ?? this.city,
      role: role ?? this.role,
      marketing: marketing ?? this.marketing,
      respectDnd: respectDnd ?? this.respectDnd,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rateLimitPerMinute: rateLimitPerMinute ?? this.rateLimitPerMinute,
      deduplicate: deduplicate ?? this.deduplicate,
      status: status ?? this.status,
      sentCount: sentCount ?? this.sentCount,
      deliveredCount: deliveredCount ?? this.deliveredCount,
      openedCount: openedCount ?? this.openedCount,
      errorCount: errorCount ?? this.errorCount,
    );
  }
}
