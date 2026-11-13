import 'package:flutter/material.dart';

/// Define los temas disponibles en la aplicación BodeGo.
enum BodeGoTheme {
  moderno,
  eddamcoreDark,
}

/// Manejador global de temas de BodeGo siguiendo Clean Architecture y Material 3.
class AppTheme {
  AppTheme._();

  /// Notificador reactivo del tema actual para actualización dinámica de la UI.
  static final ValueNotifier<BodeGoTheme> themeNotifier =
      ValueNotifier<BodeGoTheme>(BodeGoTheme.moderno);

  /// Cambia el tema activo de la aplicación.
  static void setTheme(BodeGoTheme theme) {
    themeNotifier.value = theme;
  }

  // --- Paleta de Colores: Tema Moderno ---
  // Background: #F8F9FE, Surface: #E8EBFA, Primary: #4353FF, Accent: #4FD1C5, Text: #141A3C
  static const Color modernoBackground = Color(0xFFF8F9FE);
  static const Color modernoSurface = Color(0xFFE8EBFA);
  static const Color modernoPrimary = Color(0xFF4353FF);
  static const Color modernoAccent = Color(0xFF4FD1C5);
  static const Color modernoText = Color(0xFF141A3C);

  // --- Paleta de Colores: Tema EddamCore Dark ---
  // Background: #000000, Surface: #1A1A1A, Primary: #FF0033, Accent: #FFFFFF, Text: #FFFFFF
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkPrimary = Color(0xFFFF0033);
  static const Color darkAccent = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFFFFFFFF);

  /// Retorna la configuración [ThemeData] correspondiente al [BodeGoTheme] seleccionado.
  static ThemeData getTheme(BodeGoTheme themeType) {
    switch (themeType) {
      case BodeGoTheme.moderno:
        return _buildTheme(
          brightness: Brightness.light,
          background: modernoBackground,
          surface: modernoSurface,
          primary: modernoPrimary,
          accent: modernoAccent,
          text: modernoText,
        );
      case BodeGoTheme.eddamcoreDark:
        return _buildTheme(
          brightness: Brightness.dark,
          background: darkBackground,
          surface: darkSurface,
          primary: darkPrimary,
          accent: darkAccent,
          text: darkText,
        );
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color accent,
    required Color text,
  }) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme colorScheme = isDark
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: Colors.white,
            secondary: accent,
            onSecondary: Colors.black,
            surface: surface,
            onSurface: text,
            background: background,
            onBackground: text,
            error: Colors.redAccent,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: Colors.white,
            secondary: accent,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: text,
            background: background,
            onBackground: text,
            error: Colors.redAccent,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'sans-serif',
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontFamily: 'sans-serif',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: text, fontFamily: 'sans-serif', fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: text, fontFamily: 'sans-serif', fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: text, fontFamily: 'sans-serif', fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text, fontFamily: 'sans-serif'),
        bodyMedium: TextStyle(color: text, fontFamily: 'sans-serif'),
      ),
    );
  }
}

