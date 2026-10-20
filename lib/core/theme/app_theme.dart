import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const lime = Color(0xFFB7F500);
  static const onLime = Color(0xFF11131B);
  static bool lightMode = false;

  static Color get bg =>
      lightMode ? const Color(0xFFF4F6F2) : const Color(0xFF11131B);
  static Color get surface =>
      lightMode ? const Color(0xFFFFFFFF) : const Color(0xFF1C202B);
  static Color get surface2 =>
      lightMode ? const Color(0xFFE8ECE5) : const Color(0xFF252A36);
  static Color get text =>
      lightMode ? const Color(0xFF1D251B) : const Color(0xFFF5F6F7);
  static Color get muted =>
      lightMode ? const Color(0xFF626B5F) : const Color(0xFFA8ACB8);

  static ThemeData get dark => _createTheme(Brightness.dark);
  static ThemeData get light => _createTheme(Brightness.light);
  static ThemeData get current => lightMode ? light : dark;

  static ThemeData _createTheme(Brightness brightness) => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: lime,
      onPrimary: const Color(0xFF11131B),
      secondary: lime,
      onSecondary: const Color(0xFF11131B),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      elevation: 0,
    ).copyWith(backgroundColor: bg, foregroundColor: text),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
    ).copyWith(color: surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: TextStyle(color: muted),
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
