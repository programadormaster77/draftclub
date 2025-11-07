import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:draftclub_mobile/features/notifications/services/local_notification_service.dart';
import 'package:draftclub_mobile/features/notifications/services/notification_router.dart';

/// ============================================================================
/// 🔔 FcmService — Maneja notificaciones Push (Firebase Cloud Messaging)
/// ============================================================================
/// - Solicita permisos (Android/iOS)
/// - Escucha notificaciones foreground / background / killed
/// - Sincroniza token con Firestore
/// - Envía enlaces (Uri) al NotificationRouter
/// ============================================================================

class FcmService {
  static final _linkController = StreamController<Uri>.broadcast();
  static Stream<Uri> get linkStream => _linkController.stream;

  /// 🚀 Inicialización principal FCM
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // ✅ Solicitar permisos (solo se muestra una vez)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ✅ Sincronizar token
    await _syncToken();

    // ✅ Foreground — App abierta
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Mensaje FCM foreground: ${message.data}');
      _handleForegroundNotification(message);
    });

    // ✅ App en background — usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // ✅ App cerrada (killed)
    final initialMsg = await messaging.getInitialMessage();
    if (initialMsg != null) _handleNotificationTap(initialMsg);

    debugPrint('✅ FCM inicializado correctamente');
  }

  /// ✅ Sincroniza el token del dispositivo con Firestore
  static Future<void> _syncToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));

    debugPrint('📡 Token FCM sincronizado para usuario: ${user.uid}');
  }

  /// 🟢 Notificación recibida en foreground
  static void _handleForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Nuevo evento';
    final body =
        notification?.body ?? data['body'] ?? 'Tienes una nueva alerta';
    final link = data['link']; // ej: draftclub://room/xyz123

    // Muestra notificación local con sonido de árbitro
    LocalNotificationService.show(
      title: title,
      body: body,
      payload: link,
    );
  }

  /// 🟣 El usuario tocó la notificación (foreground/background/killed)
  static void _handleNotificationTap(RemoteMessage message) {
    final link = message.data['link'];
    if (link == null) return;

    try {
      final uri = Uri.parse(link);
      _linkController.add(uri);
      debugPrint('🔗 Enlace procesado desde FCM: $uri');
    } catch (e) {
      debugPrint('⚠️ Error procesando link FCM: $e');
    }
  }
}
