// 📄 apps/mobile/lib/features/notifications/presentation/send_notification_form.dart
//
// 🧾 SendNotificationForm — Formulario para crear una notificación administrativa
//
// Este widget se encarga de:
//  - Capturar los datos de la notificación (título, cuerpo, imagen, link).
//  - Permitir elegir filtros (tipo de destino, segmento, país, ciudad, VIP, etc.).
//  - Validar todos los campos antes del envío.
//  - Llamar al callback `onPreview` para actualizar la vista previa.
//
// Integración:
//  - Utiliza AdminNotificationModel para generar una instancia completa.
//  - Se usa dentro de AdminNotificationPage.
//
// Autor: Brandon Rocha (DraftClub)
// Fecha: 2025-11-07
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:draftclub_mobile/features/notifications/domain/admin_notification_model.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';

class SendNotificationForm extends StatefulWidget {
  final void Function(AdminNotificationModel notification) onPreview;

  const SendNotificationForm({super.key, required this.onPreview});

  @override
  State<SendNotificationForm> createState() => _SendNotificationFormState();
}

class _SendNotificationFormState extends State<SendNotificationForm> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  // Parámetros seleccionables
  AdminTargetType _targetType = AdminTargetType.global;
  AdminPriority _priority = AdminPriority.normal;
  AdminSegment? _segment;
  bool _marketing = false;
  bool _respectDnd = true;
  DateTime? _scheduledAt;

  // ==========================================================================
  // 🕒 Seleccionar fecha y hora
  // ==========================================================================
  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ==========================================================================
  // 🚀 Crear instancia de notificación y enviarla al callback de vista previa
  // ==========================================================================
  void _buildPreview() {
    if (!_formKey.currentState!.validate()) return;

    final model = AdminNotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      imageUrl: _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text,
      deepLink: _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text,
      targetType: _targetType,
      targetValue: _targetCtrl.text.trim().isEmpty ? null : _targetCtrl.text,
      segment: _segment,
      marketing: _marketing,
      respectDnd: _respectDnd,
      priority: _priority,
      createdAt: DateTime.now(),
      createdBy: "admin_brandon", // ⚠️ reemplazar luego por UID real del admin
      scheduledAt: _scheduledAt,
      status: _scheduledAt == null ? AdminStatus.draft : AdminStatus.scheduled,
    );

    widget.onPreview(model);
  }

  // ==========================================================================
  // 🧱 INTERFAZ
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111111),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                '📢 Nueva notificación',
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 16),

              // ===============================
              // 🧾 Campos principales
              // ===============================
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej: ¡Se abrió una nueva sala en tu zona!',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingresa un título' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  hintText: 'Ej: No te pierdas los partidos cercanos ⚽',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingresa un mensaje' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de imagen (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Deep link (opcional)',
                  hintText: 'Ej: draftclub://room/12345',
                ),
              ),
              const SizedBox(height: 20),

              // ===============================
              // 🎯 Segmentación
              // ===============================
              Text('🎯 Destinatarios', style: AppTextStyles.sectionTitle),
              DropdownButtonFormField<AdminTargetType>(
                value: _targetType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de destino',
                ),
                items: AdminTargetType.values
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              const SizedBox(height: 10),

              if (_targetType != AdminTargetType.global)
                TextFormField(
                  controller: _targetCtrl,
                  decoration: InputDecoration(
                    labelText: _targetType == AdminTargetType.city
                        ? 'Ciudad destino'
                        : _targetType == AdminTargetType.country
                            ? 'País destino'
                            : 'Valor objetivo',
                  ),
                ),

              if (_targetType == AdminTargetType.segment)
                DropdownButtonFormField<AdminSegment>(
                  value: _segment,
                  decoration: const InputDecoration(labelText: 'Segmento'),
                  items: AdminSegment.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _segment = v),
                ),
              const SizedBox(height: 20),

              // ===============================
              // ⚙️ Configuraciones extra
              // ===============================
              Text('⚙️ Configuración avanzada',
                  style: AppTextStyles.sectionTitle),
              SwitchListTile(
                value: _marketing,
                title: const Text('Marcar como marketing'),
                subtitle: const Text('Solo usuarios con marketing permitido'),
                onChanged: (v) => setState(() => _marketing = v),
              ),
              SwitchListTile(
                value: _respectDnd,
                title: const Text('Respetar modo DND'),
                subtitle:
                    const Text('Evita enviar durante el modo “No molestar”'),
                onChanged: (v) => setState(() => _respectDnd = v),
              ),
              DropdownButtonFormField<AdminPriority>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Prioridad'),
                items: AdminPriority.values
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 20),

              // ===============================
              // ⏰ Programación
              // ===============================
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.white70),
                title: const Text('Programar envío'),
                subtitle: Text(_scheduledAt == null
                    ? 'No programado'
                    : DateFormat('dd/MM/yyyy HH:mm').format(_scheduledAt!)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined,
                      color: Colors.blueAccent),
                  onPressed: _pickSchedule,
                ),
              ),

              const SizedBox(height: 30),

              // ===============================
              // 👀 Botón de vista previa
              // ===============================
              ElevatedButton.icon(
                onPressed: _buildPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _linkCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }
}
