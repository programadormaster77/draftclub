// 📄 apps/mobile/lib/features/notifications/data/admin_notification_service.dart
//
// 🚀 AdminNotificationService — Gestión completa de campañas administrativas
//
// Permite a los administradores enviar notificaciones segmentadas mediante
// la Cloud Function HTTP `sendAdminNotification`, almacenando registros,
// métricas y estado en Firestore.
//
// 🔹 Validación previa (AdminNotificationModel.validate())
// 🔹 Registro automático en /adminNotifications
// 🔹 Integración con Cloud Functions (Node 20 / HTTP Request)
// 🔹 Reintentos, cancelación y monitoreo en tiempo real
//
// Autor: Brandon Rocha (DraftClub)
// Actualizado: 2025-11-07
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_notification_model.dart';

class AdminNotificationService {
  final _firestore = FirebaseFirestore.instance;

  // Endpoint HTTP de tu función en Firebase
  static const String _functionUrl =
      'https://us-central1-draftclub-a00ea.cloudfunctions.net/sendAdminNotification';

  // ==========================================================================
  // 📨 Enviar campaña administrativa
  // ==========================================================================
  Future<Map<String, dynamic>> sendCampaign(
      AdminNotificationModel model) async {
    // 1️⃣ Validación previa local
    final issues = model.validate();
    if (issues.isNotEmpty) {
      return {
        'success': false,
        'message': '❌ Errores de validación:\n${issues.join("\n")}',
      };
    }

    try {
      // 2️⃣ Guardar o actualizar registro en Firestore
      final docRef = _firestore.collection('adminNotifications').doc(model.id);
      await docRef.set(model.toMap(), SetOptions(merge: true));

      // 3️⃣ Construcción de payload limpio (solo campos que la función entiende)
      final Map<String, dynamic> payload = {
        'title': model.title.trim(),
        'body': model.body.trim(),
      };

      // Agregar solo si existen valores reales
      if (model.imageUrl?.trim().isNotEmpty ?? false) {
        payload['imageUrl'] = model.imageUrl!.trim();
      }
      if (model.deepLink?.trim().isNotEmpty ?? false) {
        payload['deepLink'] = model.deepLink!.trim();
      }
      if (model.country?.trim().isNotEmpty ?? false) {
        payload['country'] = model.country!.trim();
      }
      if (model.city?.trim().isNotEmpty ?? false) {
        payload['city'] = model.city!.trim();
      }
      if (model.role?.trim().isNotEmpty ?? false) {
        payload['role'] = model.role!.trim();
      }

      payload['marketing'] = model.marketing ?? false;

      debugPrint('📦 Payload enviado a Firebase: ${jsonEncode(payload)}');

      // 4️⃣ Llamar a la función HTTP
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // 5️⃣ Analizar respuesta
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await docRef.update({
          'status': data['status'] ?? 'sent',
          'metrics': data['metrics'] ?? {},
          'sentAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Notificación enviada correctamente: ${model.title}');
        return {
          'success': true,
          'message': data['message'] ?? 'Notificación enviada correctamente.',
          'metrics': data['metrics'] ?? {},
        };
      } else {
        final errorBody = jsonDecode(response.body);
        debugPrint('⚠️ Error HTTP: ${response.statusCode} -> $errorBody');

        await docRef.update({
          'status': 'failed',
          'error': errorBody['error'] ?? 'Error desconocido en servidor',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        return {
          'success': false,
          'message':
              'Error HTTP ${response.statusCode}: ${errorBody['error'] ?? 'Error al enviar la notificación.'}',
        };
      }
    } catch (e, st) {
      debugPrint('⚠️ Excepción enviando notificación: $e');
      debugPrintStack(stackTrace: st);

      await _firestore.collection('adminLogs').add({
        'type': 'notification_error',
        'error': e.toString(),
        'stack': st.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'context': model.toMap(),
      });

      return {
        'success': false,
        'message': 'Error al enviar la notificación: $e',
      };
    }
  }

  // ==========================================================================
  // 📊 Escuchar campañas activas / historial
  // ==========================================================================
  Stream<List<AdminNotificationModel>> watchAllCampaigns({int limit = 50}) {
    return _firestore
        .collection('adminNotifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AdminNotificationModel.fromFirestore).toList());
  }

  // ==========================================================================
  // 🔁 Reintentar campañas fallidas
  // ==========================================================================
  Future<void> retryFailed(String docId) async {
    final doc =
        await _firestore.collection('adminNotifications').doc(docId).get();
    if (!doc.exists) throw Exception('Campaña no encontrada.');

    final model = AdminNotificationModel.fromFirestore(doc);
    if (model.status != AdminStatus.failed) {
      throw Exception('Solo se pueden reintentar campañas fallidas.');
    }

    await sendCampaign(model.copyWith(status: AdminStatus.draft));
  }

  // ==========================================================================
  // 🧹 Cancelar campañas programadas
  // ==========================================================================
  Future<void> cancelCampaign(String docId) async {
    await _firestore
        .collection('adminNotifications')
        .doc(docId)
        .update({'status': AdminStatus.canceled.name});
  }

  // ==========================================================================
  // 🧾 Obtener detalle de una campaña específica
  // ==========================================================================
  Future<AdminNotificationModel?> getById(String docId) async {
    final doc =
        await _firestore.collection('adminNotifications').doc(docId).get();
    if (!doc.exists) return null;
    return AdminNotificationModel.fromFirestore(doc);
  }

  // ==========================================================================
  // 🧠 Registrar manualmente métricas adicionales
  // ==========================================================================
  Future<void> updateMetrics(String id, Map<String, dynamic> metrics) async {
    await _firestore.collection('adminNotifications').doc(id).update({
      'metrics': metrics,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
