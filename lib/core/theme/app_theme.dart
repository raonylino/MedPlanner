import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const darkLime = Color(0xFFB7F500);
  static const onLime = Color(0xFF11131B);
  static bool lightMode = false;

  static Color get lime => lightMode ? const Color(0xFFA5E800) : darkLime;
  static Color get valueGreen =>
      lightMode ? const Color(0xFF4E7500) : darkLime;
  static Color get accentSurface =>
      lightMode ? const Color(0xFFEEF5D8) : darkLime;
  static Color get border =>
      lightMode ? const Color(0xFFE5E7EB) : const Color(0xFF252A36);

  static Color get bg =>
      lightMode ? const Color(0xFFF5F6F8) : const Color(0xFF11131B);
  static Color get surface =>
      lightMode ? const Color(0xFFFFFFFF) : const Color(0xFF1C202B);
  static Color get surface2 =>
      lightMode ? const Color(0xFFF5F6F8) : const Color(0xFF252A36);
  static Color get text =>
      lightMode ? const Color(0xFF1A1D20) : const Color(0xFFF5F6F7);
  static Color get muted =>
      lightMode ? const Color(0xFF6C727F) : const Color(0xFFA8ACB8);

  static ThemeData get dark => _createTheme(Brightness.dark);
  static ThemeData get light => _createTheme(Brightness.light);
  static ThemeData get current => lightMode ? light : dark;

  static ThemeData _createTheme(Brightness brightness) => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: lime,
      onPrimary: onLime,
      secondary: lime,
      onSecondary: onLime,
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
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: text),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
    ).copyWith(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: lime),
      ),
    ),
  );
}
