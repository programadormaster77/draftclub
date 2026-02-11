// lib/features/users/domain/xp_levels.dart
/// ===============================================================
/// 🧠 XPLevels — conversión de XP a niveles y rangos
/// ===============================================================
class XPLevels {
  /// Devuelve el nivel basado en el XP total
  static int getLevel(int xp) {
    if (xp < 100) return 1;
    if (xp < 250) return 2;
    if (xp < 500) return 3;
    if (xp < 900) return 4;
    if (xp < 1400) return 5;
    if (xp < 2000) return 6;
    if (xp < 3000) return 7;
    if (xp < 4500) return 8;
    if (xp < 6500) return 9;
    return 10;
  }

  /// Devuelve el título/rango asociado al nivel
  static String getRankName(int level) {
    switch (level) {
      case 1:
        return "Rookie";
      case 2:
        return "Amateur";
      case 3:
        return "Semi-Pro";
      case 4:
        return "Pro";
      case 5:
        return "Elite";
      case 6:
        return "Capitán";
      case 7:
        return "Leyenda Local";
      case 8:
        return "Internacional";
      case 9:
        return "Ícono";
      case 10:
        return "Inmortal";
      default:
        return "Desconocido";
    }
  }

  /// Progreso % dentro del nivel actual
  static double getProgressPercent(int xp) {
    final level = getLevel(xp);
    final currentCap = _xpCapForLevel(level);
    final nextCap = _xpCapForLevel(level + 1);
    return (xp - currentCap) / (nextCap - currentCap);
  }

  static int _xpCapForLevel(int level) {
    switch (level) {
      case 1:
        return 0;
      case 2:
        return 100;
      case 3:
        return 250;
      case 4:
        return 500;
      case 5:
        return 900;
      case 6:
        return 1400;
      case 7:
        return 2000;
      case 8:
        return 3000;
      case 9:
        return 4500;
      case 10:
        return 6500;
      default:
        return 0;
    }
  }
}
