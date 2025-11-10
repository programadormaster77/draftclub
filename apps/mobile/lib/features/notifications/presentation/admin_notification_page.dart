// 📄 apps/mobile/lib/features/notifications/presentation/admin_notification_page.dart
//
// 🧠 AdminNotificationPage — Consola profesional de campañas de notificaciones
//
// Bloques:
// 1) Formulario de creación/envío (con validaciones)
// 2) Vista previa dinámica del push (Android/iOS)
// 3) Historial profesional de campañas (stream en tiempo real con acciones)
//
// Integraciones:
//  - AdminNotificationModel (modelo de datos)
//  - AdminNotificationService (Cloud Functions + Firestore)
//  - watchAllCampaigns() para el historial
//
// UI: estilo premium DraftClub (oscuro, acentos azul/dorado).
//
// Autor: Brandon Rocha (DraftClub)

import 'package:draftclub_mobile/core/auth/user_role_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';
import 'package:draftclub_mobile/features/notifications/domain/admin_notification_model.dart';
import 'package:draftclub_mobile/features/notifications/data/admin_notification_service.dart';
import 'package:draftclub_mobile/core/auth/admin_visibility_wrapper.dart';

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  // Servicios
  final _service = AdminNotificationService();

  // Form
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _deepLinkCtrl = TextEditingController();
  final _role = UserRoleService();
  final _targetValueCtrl = TextEditingController();

  // Configuración
  AdminTargetType _targetType = AdminTargetType.global;
  AdminPriority _priority = AdminPriority.normal;
  AdminSegment? _segment;
  bool _marketing = false;
  bool _respectDnd = true;
  DateTime? _scheduleAt;

  // Estado UI
  bool _loading = false;
  String? _resultMessage;

  // ============================
// 🚀 Enviar/Programar campaña
// ============================
  Future<void> _sendCampaign() async {
    // 🔒 Verificamos si el usuario es administrador antes de permitir envío
    final isAdmin = await UserRoleService().isAdmin();
    if (!isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para enviar notificaciones.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final model = AdminNotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      imageUrl: _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text,
      deepLink:
          _deepLinkCtrl.text.trim().isNotEmpty ? _deepLinkCtrl.text : null,
      targetType: _targetType,
      targetValue: _targetType == AdminTargetType.global
          ? null
          : (_targetValueCtrl.text.trim().isEmpty
              ? null
              : _targetValueCtrl.text.trim()),
      segment: _targetType == AdminTargetType.segment ? _segment : null,
      marketing: _marketing,
      respectDnd: _respectDnd,
      priority: _priority,
      createdAt: DateTime.now(),
      createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin',
      scheduledAt: _scheduleAt,
      status: _scheduleAt == null ? AdminStatus.draft : AdminStatus.scheduled,
    );

    final result = await _service.sendCampaign(model);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _resultMessage = result['message'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_resultMessage ?? 'Operación completada'),
        backgroundColor:
            result['success'] == true ? Colors.green : Colors.redAccent,
      ),
    );

    if (result['success'] == true) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _imageUrlCtrl.clear();
      _deepLinkCtrl.clear();
      _targetValueCtrl.clear(); // ✅ ya existe y se limpia correctamente

      setState(() {
        _targetType = AdminTargetType.global;
        _segment = null;
        _marketing = false;
        _respectDnd = true;
        _priority = AdminPriority.normal;
        _scheduleAt = null;
      });
    }
  }

  // ============================
  // 🕒 Selector de fecha/hora
  // ============================
  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 45)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
    );
    if (time == null) return;

    setState(() {
      _scheduleAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ============================
  // 🔁 Acciones historial
  // ============================
  Future<void> _retry(AdminNotificationModel m) async {
    await _service.retryFailed(m.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reintento solicitado')));
  }

  Future<void> _cancel(AdminNotificationModel m) async {
    await _service.cancelCampaign(m.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Campaña cancelada')));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _deepLinkCtrl.dispose();
    _targetValueCtrl.dispose();
    super.dispose();
  }

  // ============================
// 🧩 UI
// ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Panel de notificaciones'),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          FutureBuilder<bool>(
            future: UserRoleService().isAdmin(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final isAdmin = snap.data ?? false;

              // 🟡 Franja dorada o ícono especial solo para admins
              if (isAdmin) {
                return const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.admin_panel_settings,
                      color: Colors.amberAccent, size: 26),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),

      // ============================
      // 🧩 CUERPO PRINCIPAL
      // ============================
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : FutureBuilder<bool>(
              future: UserRoleService().isAdmin(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accentBlue),
                  );
                }

                final isAdmin = snap.data == true;

                // 🟡 LOG DE DEPURACIÓN (te muestra en consola si detecta admin)
                debugPrint('🟡 Rol admin detectado: $isAdmin');

                return Column(
                  children: [
                    // 🟨 Franja dorada visible solo si es admin
                    if (isAdmin)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        color: Colors.amberAccent.withOpacity(0.1),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star,
                                color: Colors.amberAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Modo administrador activado',
                              style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // 🧩 Contenido principal
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            if (!isAdmin)
                              _noAccessCard(), // 👈 Solo usuarios normales
                            if (isAdmin) ...[
                              _buildForm(),
                              const SizedBox(height: 16),
                              _buildPreview(),
                              const SizedBox(height: 16),
                            ],
                            _buildHistory(), // 👈 Todos pueden ver el historial
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Tarjeta para usuarios sin permisos
  Widget _noAccessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_outline, color: Colors.white54),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Acceso restringido: esta sección es solo para administradores.\n'
              'Puedes ver el historial de campañas, pero no crear ni enviar notificaciones.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

// Bloque formulario
  Widget _buildForm() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('✉️ Crear campaña'),
              const SizedBox(height: 12),
              _buildTextField(_titleCtrl, 'Título',
                  hint: 'Ej: ¡Hay una nueva sala cerca de ti!'),
              _buildTextField(_bodyCtrl, 'Mensaje',
                  hint: 'Ej: Revisa las salas creadas hoy en tu zona ⚽',
                  lines: 2),
              _buildTextField(_imageUrlCtrl, 'URL de imagen (opcional)'),
              _buildTextField(_deepLinkCtrl, 'Deep link (opcional)',
                  hint: 'Ej: draftclub://room/abc123'),
              const SizedBox(height: 18),
              const _SectionTitle('🎯 Audiencia'),
              const SizedBox(height: 8),
              _buildTargetSelection(),
              const SizedBox(height: 18),
              const _SectionTitle('⚙️ Configuración'),
              const SizedBox(height: 8),
              _buildSwitches(),
              _buildPriorityDropdown(),
              _buildSchedulePicker(),
              const SizedBox(height: 16),
              _buildSendButton(),
            ],
          ),
        ),
      );

  Widget _buildPreview() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('👀 Vista previa'),
            const SizedBox(height: 10),
            _PreviewCard(
              title: _titleCtrl.text.isEmpty
                  ? 'Título de ejemplo'
                  : _titleCtrl.text,
              body: _bodyCtrl.text.isEmpty
                  ? 'Así se mostrará el mensaje de tu notificación push.'
                  : _bodyCtrl.text,
              imageUrl: _imageUrlCtrl.text.trim().isNotEmpty
                  ? _imageUrlCtrl.text.trim()
                  : null,
              deepLink: _deepLinkCtrl.text.trim().isNotEmpty
                  ? _deepLinkCtrl.text.trim()
                  : null,
              priorityHigh: _priority == AdminPriority.high,
            ),
            const SizedBox(height: 6),
            Text(
              'Canal Android: draftclub_general · Sonido: pitido árbitro · DND: ${_respectDnd ? 'ON' : 'OFF'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _buildHistory() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('📜 Historial de campañas'),
            const SizedBox(height: 8),
            StreamBuilder<List<AdminNotificationModel>>(
              stream: _service.watchAllCampaigns(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentBlue));
                }
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const Text('Aún no hay campañas.',
                      style: TextStyle(color: Colors.white54, fontSize: 12));
                }
                final list = snap.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white12.withOpacity(0.08)),
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return _HistoryRow(
                      model: m,
                      onRetry: m.status == AdminStatus.failed
                          ? () => _retry(m)
                          : null,
                      onCancel: m.status == AdminStatus.scheduled
                          ? () => _cancel(m)
                          : null,
                    );
                  },
                );
              },
            ),
          ],
        ),
      );

  // ======= Subcomponentes internos =======

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int lines = 1,
  }) {
    final isOptional = label.toLowerCase().contains('(opcional)');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        validator: (v) {
          if (isOptional) return null; // ✅ No validar si es opcional
          if (v == null || v.trim().isEmpty) return 'Campo requerido';
          return null;
        },
      ),
    );
  }

  Widget _buildTargetSelection() => Column(
        children: [
          DropdownButtonFormField<AdminTargetType>(
            value: _targetType,
            decoration: const InputDecoration(labelText: 'Tipo de destino'),
            items: AdminTargetType.values
                .map((e) => DropdownMenuItem(
                    value: e, child: Text(e.name.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() => _targetType = v!),
          ),
          if (_targetType != AdminTargetType.global)
            _buildTextField(_targetValueCtrl, 'Valor objetivo'),
          if (_targetType == AdminTargetType.segment)
            DropdownButtonFormField<AdminSegment>(
              value: _segment,
              decoration: const InputDecoration(labelText: 'Segmento'),
              items: AdminSegment.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (v) => setState(() => _segment = v),
            ),
        ],
      );

  Widget _buildSwitches() => Column(
        children: [
          SwitchListTile(
            value: _marketing,
            title: const Text('Marcar como marketing'),
            subtitle: const Text('Solo a usuarios que aceptaron marketing'),
            onChanged: (v) => setState(() => _marketing = v),
            activeColor: AppColors.accentBlue,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _respectDnd,
            title: const Text('Respetar modo DND'),
            subtitle: const Text('Evita enviar durante "No molestar"'),
            onChanged: (v) => setState(() => _respectDnd = v),
            activeColor: AppColors.accentBlue,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      );

  Widget _buildPriorityDropdown() => DropdownButtonFormField<AdminPriority>(
        value: _priority,
        decoration: const InputDecoration(labelText: 'Prioridad'),
        items: AdminPriority.values
            .map((e) =>
                DropdownMenuItem(value: e, child: Text(e.name.toUpperCase())))
            .toList(),
        onChanged: (v) => setState(() => _priority = v!),
      );

  Widget _buildSchedulePicker() => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule, color: Colors.white70),
        title: const Text('Programar envío'),
        subtitle: Text(
          _scheduleAt == null
              ? 'No programado'
              : DateFormat('dd/MM/yyyy HH:mm').format(_scheduleAt!),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_calendar_outlined,
              color: AppColors.accentBlue),
          onPressed: _pickSchedule,
        ),
      );

  Widget _buildSendButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _sendCampaign,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Enviar notificación'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 12, offset: Offset(0, 6)),
        ],
      );
}

// ============================
// 🧩 Widgets auxiliares (UI)
// ============================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.sectionTitle);
  }
}

/// Tarjeta de vista previa del push (estilo Android/iOS)
class _PreviewCard extends StatelessWidget {
  final String title;
  final String body;
  final String? imageUrl;
  final String? deepLink;
  final bool priorityHigh;

  const _PreviewCard({
    required this.title,
    required this.body,
    this.imageUrl,
    this.deepLink,
    required this.priorityHigh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono app
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.sports_soccer,
                color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 12),

          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Row(
                  children: [
                    const Text('DraftClub',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(width: 8),
                    if (priorityHigh)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: const Text('ALTA',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        color: Colors.white70, height: 1.3, fontSize: 13)),
                if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black,
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white24)),
                        ),
                      ),
                    ),
                  ),
                ],
                if (deepLink != null && deepLink!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Deep link: $deepLink',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del historial con estado + métricas + acciones
class _HistoryRow extends StatelessWidget {
  final AdminNotificationModel model;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const _HistoryRow({
    required this.model,
    this.onRetry,
    this.onCancel,
  });

  Color _statusColor(AdminStatus s) {
    switch (s) {
      case AdminStatus.sent:
        return Colors.greenAccent;
      case AdminStatus.scheduled:
        return Colors.amberAccent;
      case AdminStatus.failed:
        return Colors.redAccent;
      case AdminStatus.sending:
        return Colors.blueAccent;
      case AdminStatus.canceled:
        return Colors.grey;
      case AdminStatus.draft:
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('dd/MM HH:mm').format(model.createdAt);
    final statusColor = _statusColor(model.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título + estado
          Row(
            children: [
              Expanded(
                child: Text(model.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(model.status.name.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(model.body,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),

          // Métricas + fecha
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _ChipMetric(
                  icon: Icons.local_post_office,
                  label: 'sent',
                  value: model.sentCount),
              _ChipMetric(
                  icon: Icons.move_to_inbox,
                  label: 'delivered',
                  value: model.deliveredCount),
              _ChipMetric(
                  icon: Icons.open_in_new,
                  label: 'opened',
                  value: model.openedCount),
              _ChipMetric(
                  icon: Icons.error_outline,
                  label: 'errors',
                  value: model.errorCount),
              _ChipMetric(
                  icon: Icons.access_time, label: 'creada', valueText: created),
              if (model.targetType != AdminTargetType.global)
                _ChipMetric(
                  icon: Icons.place_outlined,
                  label: model.targetType.name,
                  valueText: model.targetValue ?? (model.segment?.name ?? '-'),
                ),
            ],
          ),

          // Acciones
          if (onRetry != null || onCancel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                if (onRetry != null && onCancel != null)
                  const SizedBox(width: 10),
                if (onCancel != null)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Métrica compacta tipo chip
class _ChipMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final String? valueText;

  const _ChipMetric({
    required this.icon,
    required this.label,
    this.value,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final text = valueText ?? (value ?? 0).toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 15),
          const SizedBox(width: 6),
          Text('$label: $text',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
