import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:draftclub_mobile/core/ui/ui_theme.dart';
import 'package:draftclub_mobile/features/notifications/services/local_notification_service.dart';

/// ============================================================================
/// ⚙️ NotificationsSettingsPage — Preferencias de notificaciones DraftClub
/// ============================================================================
/// Permite al usuario:
/// - Activar/desactivar notificaciones generales, de salas, mensajes, marketing
/// - Activar/desactivar el sonido de árbitro
/// - Configurar horario "No molestar"
/// - Guardar cambios en Firestore (users/{uid}.notifPrefs)
/// ============================================================================
class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _global = true;
  bool _rooms = true;
  bool _messages = true;
  bool _marketing = false;
  bool _sound = true;
  bool _dndEnabled = false;
  TimeOfDay _dndFrom = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _dndTo = const TimeOfDay(hour: 8, minute: 0);

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final prefs = (doc.data()?['notifPrefs'] ?? {}) as Map<String, dynamic>;

    setState(() {
      _global = prefs['global'] ?? true;
      _rooms = prefs['rooms'] ?? true;
      _messages = prefs['messages'] ?? true;
      _marketing = prefs['marketing'] ?? false;
      _sound = prefs['sound'] ?? true;
      _dndEnabled = prefs['dnd']?['enabled'] ?? false;

      final fromStr = prefs['dnd']?['from'] ?? '22:00';
      final toStr = prefs['dnd']?['to'] ?? '08:00';

      _dndFrom = _parseTime(fromStr);
      _dndTo = _parseTime(toStr);

      _loading = false;
    });
  }

  TimeOfDay _parseTime(String str) {
    final parts = str.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.Hm().format(dt);
  }

  Future<void> _savePrefs() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'notifPrefs': {
        'global': _global,
        'rooms': _rooms,
        'messages': _messages,
        'marketing': _marketing,
        'sound': _sound,
        'dnd': {
          'enabled': _dndEnabled,
          'from': _formatTime(_dndFrom),
          'to': _formatTime(_dndTo),
        }
      }
    };

    await _firestore.collection('users').doc(user.uid).set(
          data,
          SetOptions(merge: true),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Preferencias guardadas correctamente'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _dndFrom : _dndTo,
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dndFrom = picked;
        } else {
          _dndTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Preferencias generales',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  title: 'Activar notificaciones',
                  subtitle:
                      'Habilita o deshabilita todas las notificaciones de DraftClub.',
                  value: _global,
                  onChanged: (v) => setState(() => _global = v),
                ),
                _buildSwitchTile(
                  title: 'Salas y partidos',
                  subtitle: 'Avisos sobre salas creadas o actualizadas.',
                  value: _rooms,
                  onChanged: (v) => setState(() => _rooms = v),
                ),
                _buildSwitchTile(
                  title: 'Mensajes y chats',
                  subtitle: 'Recibe alertas de nuevos mensajes.',
                  value: _messages,
                  onChanged: (v) => setState(() => _messages = v),
                ),
                _buildSwitchTile(
                  title: 'Marketing y promociones',
                  subtitle: 'Recibe campañas especiales y descuentos.',
                  value: _marketing,
                  onChanged: (v) => setState(() => _marketing = v),
                ),
                const Divider(height: 30, color: Colors.white24),
                const Text(
                  'Sonido',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  title: 'Pitido de árbitro',
                  subtitle: 'Reproduce el sonido cuando llegue una alerta.',
                  value: _sound,
                  onChanged: (v) => setState(() => _sound = v),
                ),
                if (_sound)
                  ListTile(
                    title: const Text(
                      'Vista previa del sonido',
                      style: AppTextStyles.body,
                    ),
                    leading: const Icon(Icons.volume_up, color: Colors.white70),
                    onTap: () async {
                      // Reproduce el sonido de prueba
                      await LocalNotificationService.show(
                        title: 'Sonido de prueba',
                        body: 'Así sonará el pitido de árbitro.',
                      );
                    },
                  ),
                const Divider(height: 30, color: Colors.white24),
                const Text(
                  'Modo "No molestar"',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 10),
                _buildSwitchTile(
                  title: 'Activar modo DND',
                  subtitle:
                      'Silencia notificaciones entre las horas seleccionadas.',
                  value: _dndEnabled,
                  onChanged: (v) => setState(() => _dndEnabled = v),
                ),
                if (_dndEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeSelector('Desde', _dndFrom, true),
                        _buildTimeSelector('Hasta', _dndTo, false),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _savePrefs,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
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
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: AppTextStyles.bodyBold),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.accentBlue,
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, bool isFrom) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickTime(isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _formatTime(time),
              style: AppTextStyles.bodyBold,
            ),
          ),
        ),
      ],
    );
  }
}
