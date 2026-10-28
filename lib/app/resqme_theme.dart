import 'package:flutter/material.dart';

abstract final class ResQMeTheme {
  static ThemeData get light {
    const emergencyBlue = Color(0xFF0757A1);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emergencyBlue,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
