import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TopicManager {
  /// 🔁 Sincroniza temas al inicio de sesión o cambio de perfil
  static Future<void> syncUserTopics(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!snap.exists) return;

      final data = snap.data()!;
      final city = data['city'];
      if (city != null && city is String) {
        final topic = 'city_${city.toLowerCase()}';
        await FirebaseMessaging.instance.subscribeToTopic(topic);
        debugPrint('📡 Suscripción a ciudad → $topic');
      }

      // 📌 Más adelante: rooms, teams, marketing, follows
      // Se conectará con listeners en pantalla de salas, chat y perfil
    } catch (e) {
      debugPrint('⚠️ Error sincronizando tópicos: $e');
    }
  }
}
