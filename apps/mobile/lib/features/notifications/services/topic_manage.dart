import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class TopicManager {
  static final Set<String> _subscribedTopics = {};

  /// 🔁 Sincroniza temas al inicio de sesión o cambio de perfil
  static Future<void> syncUserTopics(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) return;

      final data = snap.data()!;
      final rawCity = data['city'];

      if (rawCity != null && rawCity is String && rawCity.isNotEmpty) {
        final sanitizedCity = rawCity
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();

        final topic = 'city_$sanitizedCity';

        // 🚦 Previene suscripción duplicada
        if (_subscribedTopics.contains(topic)) return;

        await FirebaseMessaging.instance.subscribeToTopic(topic);
        _subscribedTopics.add(topic);

        debugPrint('📡 Suscripción única a ciudad → $topic');
      }
    } catch (e) {
      debugPrint('⚠️ Error sincronizando tópicos: $e');
    }
  }

  /// ❌ Desuscribe al usuario de su ciudad anterior
  static Future<void> unsubscribeOldCity(String? oldCity) async {
    if (oldCity == null || oldCity.isEmpty) return;

    final sanitizedCity = oldCity
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    final topic = 'city_$sanitizedCity';
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      _subscribedTopics.remove(topic);
      debugPrint('🧹 Desuscrito de ciudad anterior → $topic');
    } catch (e) {
      debugPrint('⚠️ Error al desuscribir de ciudad anterior: $e');
    }
  }
}
