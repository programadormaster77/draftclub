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
/// ✅ Solicita permisos (Android/iOS)
/// ✅ Escucha notificaciones foreground / background / killed
/// ✅ Sincroniza token automáticamente para TODOS los usuarios (viejos y nuevos)
/// ✅ Actualiza token cuando cambia
/// ✅ Envía enlaces (Uri) al NotificationRouter
/// ============================================================================
class FcmService {
  static final _linkController = StreamController<Uri>.broadcast();
  static Stream<Uri> get linkStream => _linkController.stream;

  /// 🚀 Inicialización principal FCM
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    try {
      // ✅ 1️⃣ Solicitar permisos (solo la primera vez)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // ✅ 2️⃣ Sincronizar token actual (para usuarios existentes o nuevos)
      await _syncToken();

      // ✅ 3️⃣ Actualizar token cuando cambia
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('♻️ Token FCM actualizado automáticamente.');
        await _registerToken(newToken);
      });

      // ✅ 4️⃣ Escuchar mensajes en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 Mensaje FCM foreground: ${message.data}');
        _handleForegroundNotification(message);
      });

      // ✅ 5️⃣ Usuario toca notificación (background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });

      // ✅ 6️⃣ App cerrada (killed)
      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) _handleNotificationTap(initialMsg);

      debugPrint('✅ FCM inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando FCM: $e');
    }
  }

  /// =========================================================================
  /// 🔐 _syncToken — Registra el token FCM si hay un usuario autenticado
  /// =========================================================================
  static Future<void> _syncToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('⚠️ Usuario no autenticado todavía, esperando sesión...');
      // Reintento automático después de 3 s (por si se loguea recién)
      Future.delayed(const Duration(seconds: 3), _syncToken);
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ No se pudo obtener token FCM.');
      return;
    }

    await _registerToken(token);
  }

  /// =========================================================================
  /// 💾 _registerToken — Guarda o actualiza el token en Firestore
  /// =========================================================================
  static Future<void> _registerToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastActive': DateTime.now(),
    }, SetOptions(merge: true));

    debugPrint('📡 Token FCM sincronizado correctamente: ${user.uid}');
  }

  /// =========================================================================
  /// 🟢 Notificación recibida en foreground
  /// =========================================================================
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

  /// =========================================================================
  /// 🟣 El usuario tocó la notificación (foreground / background / killed)
  /// =========================================================================
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
