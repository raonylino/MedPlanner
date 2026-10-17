import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const bg = Color(0xFF11131B);
  static const surface = Color(0xFF1C202B);
  static const surface2 = Color(0xFF252A36);
  static const lime = Color(0xFFB7F500);
  static const text = Color(0xFFF5F6F7);
  static const muted = Color(0xFFA8ACB8);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: lime,
      surface: surface,
      onPrimary: bg,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: lime),
      ),
    ),
  );
}
