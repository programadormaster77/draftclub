import 'package:cloud_firestore/cloud_firestore.dart';

/// ====================================================================
/// 👥 Team Model — Representa un equipo dentro de una sala (Room)
/// ====================================================================
/// Optimizado para:
/// - Compatibilidad total con Firestore.
/// - Manejo de roles dinámicos (titular/suplente).
/// - Preparación para visualización en cancha (FieldPitch).
/// - Compatibilidad con datos antiguos (players antiguos aún sirven).
/// ====================================================================
class Team {
  /// 🔹 ID único del equipo (doc.id en Firestore)
  final String id;

  /// 🏠 ID de la sala a la que pertenece
  final String roomId;

  /// 🏷️ Nombre visible del equipo
  final String name;

  /// 👥 Lista de IDs de jugadores (compatibilidad con versiones antiguas)
  final List<String> players;

  /// 🧩 Roles individuales de los jugadores ('titular' o 'suplente')
  final Map<String, String> roles;

  /// 🔢 Máximo de jugadores titulares permitidos
  final int maxPlayers;

  /// 🎨 Color del equipo (ej: "#3A86FF")
  final String color;

  /// 🕓 Fecha de creación del equipo
  final DateTime createdAt;

  /// ⚙️ Constructor principal
  Team({
    required this.id,
    required this.roomId,
    required this.name,
    required this.players,
    required this.roles,
    required this.maxPlayers,
    required this.color,
    required this.createdAt,
  });

  // ===============================================================
  // 🔄 Conversión a Map para Firestore
  // ===============================================================
  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'name': name,
        'players': players,
        'roles': roles,
        'maxPlayers': maxPlayers,
        'color': color,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  // ===============================================================
  // 🧩 Constructor desde Firestore o JSON
  // ===============================================================
  factory Team.fromMap(Map<String, dynamic> map) {
    DateTime created;
    final c = map['createdAt'];

    if (c is Timestamp) {
      created = c.toDate();
    } else if (c is String) {
      created = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    // ✅ Compatibilidad retroactiva:
    // Si 'roles' no existe, se crea a partir de la lista de players.
    final players = List<String>.from(map['players'] ?? []);
    final Map<String, String> roles = {};
    if (map['roles'] is Map) {
      map['roles'].forEach((key, value) {
        roles[key] = value?.toString() ?? 'titular';
      });
    } else {
      for (final uid in players) {
        roles[uid] = 'titular';
      }
    }

    return Team(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? '',
      name: map['name'] ?? 'Equipo sin nombre',
      players: players,
      roles: roles,
      maxPlayers: (map['maxPlayers'] is int)
          ? map['maxPlayers']
          : int.tryParse('${map['maxPlayers']}') ?? 0,
      color: map['color'] ?? '#3A86FF',
      createdAt: created,
    );
  }

  // ===============================================================
  // 🧮 Utilidades rápidas
  // ===============================================================

  /// Total de jugadores actuales (titulares + suplentes)
  int get count => roles.length;

  /// Lista de titulares
  List<String> get titulares => roles.entries
      .where((e) => e.value == 'titular')
      .map((e) => e.key)
      .toList();

  /// Lista de suplentes
  List<String> get suplentes => roles.entries
      .where((e) => e.value == 'suplente')
      .map((e) => e.key)
      .toList();

  /// ¿Está completo el equipo de titulares?
  bool get isFull => titulares.length >= maxPlayers;

  /// ¿Tiene este jugador algún rol dentro del equipo?
  bool hasPlayer(String uid) => roles.keys.contains(uid);

  /// Devuelve el rol de un jugador o "ninguno"
  String roleOf(String uid) => roles[uid] ?? 'ninguno';

  /// Crea una copia con modificaciones (inmutable)
  Team copyWith({
    String? id,
    String? roomId,
    String? name,
    List<String>? players,
    Map<String, String>? roles,
    int? maxPlayers,
    String? color,
    DateTime? createdAt,
  }) {
    return Team(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      players: players ?? this.players,
      roles: roles ?? this.roles,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte a string legible para debugging
  @override
  String toString() =>
      'Team($name | ${titulares.length} titulares + ${suplentes.length} suplentes | color: $color)';

  // ===============================================================
  // ⚡ Extensiones funcionales adicionales (para administración)
  // ===============================================================

  /// 📤 Promueve a titular un jugador específico (si hay espacio)
  Team promoteToStarter(String uid) {
    if (!roles.containsKey(uid)) return this;
    final newRoles = Map<String, String>.from(roles);
    if (titulares.length < maxPlayers) {
      newRoles[uid] = 'titular';
    }
    return copyWith(roles: newRoles);
  }

  /// 🪑 Mueve a suplente un jugador
  Team demoteToBench(String uid) {
    if (!roles.containsKey(uid)) return this;
    final newRoles = Map<String, String>.from(roles);
    newRoles[uid] = 'suplente';
    return copyWith(roles: newRoles);
  }

  /// ❌ Expulsa completamente un jugador del equipo
  Team removePlayer(String uid) {
    final newPlayers = List<String>.from(players)..remove(uid);
    final newRoles = Map<String, String>.from(roles)..remove(uid);
    return copyWith(players: newPlayers, roles: newRoles);
  }
}
