import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class TopicManager {
  /// 🔁 Sincroniza temas al inicio de sesión o cambio de perfil
  static Future<void> syncUserTopics(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) return;

      final data = snap.data()!;
      final rawCity = data['city'];

      if (rawCity != null && rawCity is String && rawCity.isNotEmpty) {
        // 🧹 Normaliza el nombre de la ciudad (sin espacios, acentos ni símbolos)
        final sanitizedCity = rawCity
            .toLowerCase()
            .replaceAll(
                RegExp(r'[^a-z0-9]+'), '_') // solo minúsculas y guiones bajos
            .replaceAll(RegExp(r'_+'), '_') // evita "__"
            .trim();

        final topic = 'city_$sanitizedCity';
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        debugPrint('📡 Suscripción a ciudad → $topic');
      }

      // 📌 Más adelante: rooms, teams, marketing, follows
      // Se conectará con listeners en pantalla de salas, chat y perfil
    } catch (e) {
      debugPrint('⚠️ Error sincronizando tópicos: $e');
    }
  }

  /// ❌ Desuscribe al usuario de su ciudad anterior (opcional y limpio)
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
      debugPrint('🧹 Desuscrito de ciudad anterior → $topic');
    } catch (e) {
      debugPrint('⚠️ Error al desuscribir de ciudad anterior: $e');
    }
  }
}
