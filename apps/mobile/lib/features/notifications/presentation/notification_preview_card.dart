// 📄 apps/mobile/lib/features/notifications/presentation/notification_preview_card.dart
//
// 🧩 NotificationPreviewCard — Vista previa visual de notificación
//
// Muestra cómo se verá la notificación antes de enviarse:
//  - Título y cuerpo del mensaje
//  - Imagen (si se definió)
//  - Indicadores visuales de prioridad, tipo y fecha programada
//
// Integración:
//  - Se utiliza dentro de AdminNotificationPage (después del formulario)
//  - Recibe un objeto AdminNotification
//
// Autor: Brandon Rocha (DraftClub)
// Fecha: 2025-11-07
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:draftclub_mobile/features/notifications/domain/admin_notification_model.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

class NotificationPreviewCard extends StatelessWidget {
  final AdminNotificationModel notification;

  const NotificationPreviewCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF181818),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================================
            // 🧾 ENCABEZADO: PRIORIDAD Y ESTADO
            // ==========================================================
            Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: _getPriorityColor(notification.priority),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Vista previa de notificación',
                  style: AppTextStyles.sectionTitle?.copyWith(fontSize: 16) ??
                      const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                ),
                const Spacer(),
                if (notification.scheduledAt != null)
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM HH:mm')
                            .format(notification.scheduledAt!),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),

            const Divider(height: 24, thickness: 0.5, color: Colors.white24),

            // ==========================================================
            // 🖼️ IMAGEN DE PORTADA (si existe)
            // ==========================================================
            if (notification.imageUrl != null &&
                notification.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  notification.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[900],
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ==========================================================
            // 📣 CONTENIDO PRINCIPAL
            // ==========================================================
            Text(
              notification.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              notification.body,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),

            if (notification.deepLink != null &&
                notification.deepLink!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notification.deepLink!,
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ==========================================================
            // ⚙️ META: DESTINO Y SEGMENTO
            // ==========================================================
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag('🎯 ${notification.targetType.name.toUpperCase()}'),
                if (notification.targetValue != null)
                  _buildTag('📍 ${notification.targetValue}'),
                if (notification.segment != null)
                  _buildTag('👥 ${notification.segment!.name.toUpperCase()}'),
                _buildTag(
                    notification.marketing ? '📢 Marketing' : '💬 General'),
                _buildTag(notification.respectDnd ? '🌙 DND On' : '🔔 Forzar'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 🎨 Helper: Color por prioridad
  // ===================================================================
  Color _getPriorityColor(AdminPriority priority) {
    switch (priority) {
      case AdminPriority.high:
        return Colors.redAccent;
      case AdminPriority.normal:
      default:
        return Colors.blueAccent;
    }
  }

  // ===================================================================
  // 🏷️ Helper: Estilo para etiquetas
  // ===================================================================
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
