import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:draftclub_mobile/features/notifications/services/notification_router.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String customSound = 'referee_whistle.wav'; // Android
  static const String channelId = 'draftclub_general';

  /// 🚀 Inicializa notificaciones locales + canal Android
  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          try {
            final uri = Uri.parse(payload);
            // Enviamos a NotificationRouter para navegación inmediata
            NotificationRouter.handleNavigation(
              navigatorKey.currentContext!,
              uri,
            );
          } catch (e) {
            debugPrint('⚠️ Error procesando payload local: $e');
          }
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      channelId,
      'Notificaciones DraftClub',
      description: 'Alertas generales, salas y mensajes importantes',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('referee_whistle'),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    debugPrint('✅ LocalNotificationService inicializado');
  }

  /// 📣 Mostrar notificación local con sonido
  static Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      channelId,
      'Notificaciones DraftClub',
      sound: RawResourceAndroidNotificationSound('referee_whistle'),
      importance: Importance.high,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails(
      sound: 'referee_whistle.caf',
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }
}

/// 🌍 Clave global del Navigator, usada por NotificationRouter desde foreground
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
