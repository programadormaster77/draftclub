import 'package:flutter/material.dart';

class DraftClubTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0C0C0E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0E6FFF),
        secondary: Color(0xFF1A1A1A),
        surface: Color(0xFF121214),
        onPrimary: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0C0C0E),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

final appTheme = DraftClubTheme.darkTheme;
