import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================================================
/// 🧠 UserProfile — Modelo de perfil de usuario
/// ===============================================================
/// Mantiene coherencia con Firestore:
/// - Nombres camelCase (createdAt, updatedAt, vipFlag)
/// - Evita guardar `uid` dentro del documento (ya es el ID del doc)
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
  final String sex; // 🔹 Nuevo campo obligatorio (Masculino / Femenino)
  final String rank; // 'Bronce' por defecto
  final int xp; // 0 por defecto
  final bool vipFlag; // false por defecto
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.sex, // ✅ requerido
    this.name,
    this.nickname,
    this.photoUrl,
    this.heightCm,
    this.position,
    this.preferredFoot,
    this.city,
    this.rank = 'Bronce',
    this.xp = 0,
    this.vipFlag = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 🔄 Convierte el modelo a un mapa listo para Firestore
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
      'sex': sex, // ✅ Nuevo campo
      'rank': rank,
      'xp': xp,
      'vipFlag': vipFlag,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// 🧩 Crea una instancia desde Firestore
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
      sex: map['sex'] as String? ??
          'Masculino', // ✅ Valor por defecto si no existía
      rank: map['rank'] as String? ?? 'Bronce',
      xp: (map['xp'] is int)
          ? map['xp'] as int
          : (map['xp'] is double)
              ? (map['xp'] as double).toInt()
              : 0,
      vipFlag: map['vipFlag'] as bool? ?? false,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
