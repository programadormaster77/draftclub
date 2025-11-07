import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// 🧩 NotificationPrefs — Modelo de preferencias de notificaciones del usuario
/// ============================================================================
/// Guarda las configuraciones en `users/{uid}.notifPrefs`
/// ============================================================================

class NotificationPrefs {
  final bool global; // activa/desactiva todo el sistema
  final bool rooms; // notificaciones de salas / partidos
  final bool messages; // notificaciones de chats y mensajes
  final bool marketing; // notificaciones promocionales
  final bool sound; // pitido de árbitro activo
  final DndPrefs dnd; // modo “No molestar”

  const NotificationPrefs({
    required this.global,
    required this.rooms,
    required this.messages,
    required this.marketing,
    required this.sound,
    required this.dnd,
  });

  /// 🌱 Valores por defecto
  factory NotificationPrefs.defaults() {
    return NotificationPrefs(
      global: true,
      rooms: true,
      messages: true,
      marketing: false,
      sound: true,
      dnd: const DndPrefs(enabled: false, from: '22:00', to: '08:00'),
    );
  }

  /// 🔁 fromMap (Firestore → modelo)
  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return NotificationPrefs.defaults();
    return NotificationPrefs(
      global: map['global'] ?? true,
      rooms: map['rooms'] ?? true,
      messages: map['messages'] ?? true,
      marketing: map['marketing'] ?? false,
      sound: map['sound'] ?? true,
      dnd: DndPrefs.fromMap(map['dnd']),
    );
  }

  /// 🔁 toMap (modelo → Firestore)
  Map<String, dynamic> toMap() {
    return {
      'global': global,
      'rooms': rooms,
      'messages': messages,
      'marketing': marketing,
      'sound': sound,
      'dnd': dnd.toMap(),
    };
  }

  /// 🔁 Copiar con cambios
  NotificationPrefs copyWith({
    bool? global,
    bool? rooms,
    bool? messages,
    bool? marketing,
    bool? sound,
    DndPrefs? dnd,
  }) {
    return NotificationPrefs(
      global: global ?? this.global,
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
      marketing: marketing ?? this.marketing,
      sound: sound ?? this.sound,
      dnd: dnd ?? this.dnd,
    );
  }

  /// ✅ Guardar en Firestore
  Future<void> saveToFirestore(String uid) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    await doc.set({'notifPrefs': toMap()}, SetOptions(merge: true));
  }

  @override
  String toString() {
    return 'NotificationPrefs(global: $global, rooms: $rooms, messages: $messages, marketing: $marketing, sound: $sound, dnd: $dnd)';
  }
}

/// ============================================================================
/// 🌙 DndPrefs — Submodelo para modo “No molestar”
/// ============================================================================
class DndPrefs {
  final bool enabled;
  final String from; // formato "HH:mm"
  final String to; // formato "HH:mm"

  const DndPrefs({
    required this.enabled,
    required this.from,
    required this.to,
  });

  factory DndPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null)
      return const DndPrefs(enabled: false, from: '22:00', to: '08:00');
    return DndPrefs(
      enabled: map['enabled'] ?? false,
      from: map['from'] ?? '22:00',
      to: map['to'] ?? '08:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'from': from,
      'to': to,
    };
  }

  @override
  String toString() => 'DND(enabled: $enabled, from: $from, to: $to)';
}
