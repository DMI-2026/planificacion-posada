import 'package:flutter/material.dart';

/// Tema festivo de la posada: rojo profundo con acentos verdes (Material 3).
class AppTheme {
  AppTheme._();

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB71C1C),
      secondary: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 4)),
    );
  }
}
