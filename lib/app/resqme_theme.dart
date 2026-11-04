import 'package:flutter/material.dart';

abstract final class ResQMeTheme {
  static ThemeData get light {
    const emergencyBlue = Color(0xFFE92B32);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emergencyBlue,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF1F3F7),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emergencyBlue,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
