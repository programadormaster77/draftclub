import 'package:flutter/material.dart';

/// ===============================================================
/// 🎨 DRAFTCLUB ARENA THEME — Estilo global tipo videojuego
/// ===============================================================
/// Inspirado en la estética “gaming”
/// (negro + neón + vidrio + degradados eléctricos)
/// Se aplica principalmente en la sección de SALAS.
/// ===============================================================

class AppColors {
  static const Color background = Color(0xFF0E0E0E); // Fondo base
  static const Color surface = Color(0xFF141414); // Cartas y paneles
  static const Color accentBlue = Color(0xFF00A6FF); // Azul neón
  static const Color accentGreen = Color(0xFF00FF9C); // Verde pasto
  static const Color accentGold = Color(0xFFFFD700); // Dorado (VIP / rango)
  static const Color accentRed = Color(0xFFFF5C5C); // Alerta o rival
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white38;
}

class AppTextStyles {
  static const title = TextStyle(
    fontFamily: 'Orbitron', // o Bebas Neue
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 1.2,
  );

  static const subtitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const body = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    color: AppColors.textMuted,
  );

  static TextStyle? get sectionTitle => null;
}

class AppDecorations {
  /// Panel translúcido con brillo
  static BoxDecoration glassCard = BoxDecoration(
    color: AppColors.surface.withOpacity(0.75),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white12),
    boxShadow: const [
      BoxShadow(
        color: Colors.black54,
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
    ],
  );

  /// Gradiente azul neón
  static const LinearGradient neonBlueGradient = LinearGradient(
    colors: [Color(0xFF0077FF), Color(0xFF00E1FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradiente dorado para rangos VIP
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  /// Tema principal oscuro con acentos eléctricos
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accentBlue,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Orbitron',
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.1,
        ),
      ),
      cardColor: AppColors.surface,
      textTheme: const TextTheme(
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
