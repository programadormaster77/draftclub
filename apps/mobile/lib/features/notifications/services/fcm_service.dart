import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:draftclub_mobile/features/notifications/services/local_notification_service.dart';
import 'package:draftclub_mobile/features/notifications/services/notification_router.dart';

/// ============================================================================
/// 🔔 FcmService — Versión optimizada y estable
/// ============================================================================
/// ✅ Se inicializa solo una vez por sesión
/// ✅ Elimina loops infinitos y fugas de memoria
/// ✅ Sin spam de prints
/// ✅ Registra token solo cuando hay usuario
/// ============================================================================

class FcmService {
  static final _linkController = StreamController<Uri>.broadcast();
  static Stream<Uri> get linkStream => _linkController.stream;

  static bool _initialized = false; // 🔒 evita reinicialización múltiple
  static bool get isInitialized => _initialized;
  static StreamSubscription<User?>? _authListener; // 🔐 escucha sesión activa

  /// 🚀 Inicialización principal FCM
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    try {
      // 1️⃣ Solicitar permisos (solo una vez)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // 2️⃣ Sincronizar token si ya hay usuario
      await _syncTokenOnce();

      // 3️⃣ Escuchar login/logout para sincronizar token una sola vez
      _authListener = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _syncTokenOnce();
        }
      });

      // 4️⃣ Listener de token refresh (solo uno)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('♻️ Token FCM actualizado.');
        await _registerToken(newToken);
      });

      // 5️⃣ Mensajes foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundNotification);

      // 6️⃣ Mensajes al tocar notificación
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 7️⃣ Mensaje inicial (app cerrada)
      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) _handleNotificationTap(initialMsg);

      debugPrint('✅ FCM inicializado correctamente (una sola vez)');
    } catch (e) {
      debugPrint('❌ Error inicializando FCM: $e');
    }
  }

  /// =========================================================================
  /// 🔐 _syncTokenOnce — Registra token FCM solo si hay usuario activo
  /// =========================================================================
  static Future<void> _syncTokenOnce() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('⚠️ Error obteniendo token FCM: $e');
    }
  }

  /// =========================================================================
  /// 💾 _registerToken — Guarda o actualiza token en Firestore
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

    if (kDebugMode) {
      debugPrint('📡 Token FCM sincronizado correctamente: ${user.uid}');
    }
  }

  /// =========================================================================
  /// 🟢 Foreground notification
  /// =========================================================================
  static void _handleForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Nuevo evento';
    final body =
        notification?.body ?? data['body'] ?? 'Tienes una nueva alerta';
    final link = data['link'];

    LocalNotificationService.show(title: title, body: body, payload: link);
  }

  /// =========================================================================
  /// 🟣 Tocar notificación → abrir enlace interno
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

  // =========================================================================
  // 🏆 Notificación — Equipo GANADOR
  // =========================================================================
  static Future<void> sendWinNotification({
    required String roomId,
    required String teamName,
    required List<String> winnerUids,
  }) async {
    for (final uid in winnerUids) {
      await _sendPersonalNotification(
        uid: uid,
        title: '🏆 ¡Victoria absoluta!',
        body: 'Tu equipo $teamName ganó el partido. Crack total.',
        link: 'draftclub://victory?roomId=$roomId',
      );
    }
  }

  // =========================================================================
  // 😞 Notificación — Equipo PERDEDOR
  // =========================================================================
  static Future<void> sendLoseNotification({
    required String roomId,
    required String teamName,
    required List<String> loserUids,
  }) async {
    for (final uid in loserUids) {
      await _sendPersonalNotification(
        uid: uid,
        title: '⚽ No fue el día…',
        body: 'La victoria no llegó, pero el fútbol siempre da revancha.',
        link: 'draftclub://defeat?roomId=$roomId',
      );
    }
  }

  // =========================================================================
  // 📩 Enviar notificación a un usuario específico (tokens múltiples)
  // =========================================================================
  static Future<void> _sendPersonalNotification({
    required String uid,
    required String title,
    required String body,
    required String link,
  }) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) return;

      final tokens = List<String>.from(userDoc['fcmTokens'] ?? []);
      if (tokens.isEmpty) return;

      for (final token in tokens) {
        await FirebaseMessaging.instance.sendMessage(
          to: token,
          data: {
            'title': title,
            'body': body,
            'link': link,
          },
        );
      }

      if (kDebugMode) {
        debugPrint('📨 Notificación enviada a $uid → $title');
      }
    } catch (e) {
      debugPrint('❌ Error enviando notificación a $uid: $e');
    }
  }

  /// =========================================================================
  /// 🧹 Limpieza (por si se reinicia sesión)
  /// =========================================================================
  static void dispose() {
    _authListener?.cancel();
    _initialized = false;
  }
}
