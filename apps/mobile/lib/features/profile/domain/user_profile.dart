import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================================================
/// 🧠 UserProfile — Modelo de perfil de usuario (versión extendida con roles)
/// ===============================================================
/// Mantiene coherencia con Firestore:
/// - Campos camelCase (createdAt, updatedAt, vipFlag, role)
/// - No guarda el `uid` dentro del documento (ya es el ID del doc)
/// - Retrocompatible con perfiles antiguos sin campo `role`
/// ===============================================================
class UserProfile {
  final String uid;
  final String email;
  final String? name;
  final String? nickname;
  final String? photoUrl;
  final int? heightCm; // Estatura en cm
  final String? position; // Ej: 'Delantero', 'Mediocampista'
  final String? preferredFoot; // 'Derecho', 'Izquierdo', 'Ambos'
  final String? city; // Ciudad del jugador
  final String sex; // Masculino / Femenino
  final String rank; // Bronce, Plata, Oro, etc.
  final int xp; // Experiencia
  final int matches; // 🆕 partidos jugados
  final int wins;    // 🆕 victorias
  final bool vipFlag; // Usuario VIP
  final String role; // 👑 user | admin | moderator
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.sex,
    this.name,
    this.nickname,
    this.photoUrl,
    this.heightCm,
    this.position,
    this.preferredFoot,
    this.city,
    this.rank = 'Bronce',
    this.xp = 0,
    this.matches = 0,
    this.wins = 0,
    this.vipFlag = false,
    this.role = 'user', // 👈 valor por defecto
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// ===============================================================
  /// 🔄 Conversión a mapa para Firestore
  /// ===============================================================
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'heightCm': heightCm,
      'position': position,
      'preferredFoot': preferredFoot,
      'city': city,
      'sex': sex,
      'rank': rank,
      'xp': xp,
      
      'matches': matches,
      'wins': wins,
      'vipFlag': vipFlag,
      'role': role, // 👑 Nuevo campo
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }



  /// ===============================================================
  /// 🧩 Construcción desde Firestore (retrocompatible)
  /// ===============================================================
  factory UserProfile.fromMap(Map<String, dynamic> map, {String? uid}) {
    return UserProfile(
      uid: uid ?? (map['uid'] as String? ?? ''),
      email: map['email'] as String? ?? '',
      name: map['name'] as String?,
      nickname: map['nickname'] as String?,
      photoUrl: map['photoUrl'] as String?,
      heightCm: (map['heightCm'] is int)
          ? map['heightCm'] as int
          : (map['heightCm'] is double)
              ? (map['heightCm'] as double).toInt()
              : null,
      position: map['position'] as String?,
      preferredFoot: map['preferredFoot'] as String?,
      city: map['city'] as String?,
      sex: map['sex'] as String? ?? 'Masculino',
      rank: map['rank'] as String? ?? 'Bronce',
      xp: (map['xp'] is int)
          ? map['xp'] as int
          : (map['xp'] is double)
              ? (map['xp'] as double).toInt()
              : 0,
      matches: (map['matches'] is int)
          ? map['matches'] as int
          : (map['matches'] is double)
              ? (map['matches'] as double).toInt()
              : 0,
      wins: (map['wins'] is int)
          ? map['wins'] as int
          : (map['wins'] is double)
              ? (map['wins'] as double).toInt()
              : 0,
      vipFlag: map['vipFlag'] as bool? ?? false,
      role: map['role'] as String? ?? 'user',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

