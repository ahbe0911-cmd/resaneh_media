import 'package:flutter/material.dart';
import 'flavor_config.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light(FlavorConfig flavor) => _buildTheme(
        colorScheme: ColorScheme.fromSeed(
          seedColor: flavor.primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: flavor.primaryColor,
          secondary: flavor.accentColor,
          surface: Colors.white,
          onPrimary: Colors.white,
        ),
      );

  static ThemeData dark(FlavorConfig flavor) => _buildTheme(
        colorScheme: ColorScheme.fromSeed(
          seedColor: flavor.darkPrimaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: flavor.darkPrimaryColor,
          secondary: flavor.darkAccentColor,
          surface: const Color(0xFF151D2C),
          onPrimary: const Color(0xFF101827),
        ),
      );

  static ThemeData _buildTheme({required ColorScheme colorScheme}) {
    final dark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0C1421) : const Color(0xFFF5F7F8),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF151D2C) : Colors.white,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF202B3B) : const Color(0xFFF0F3F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF293548) : const Color(0xFF263238),
        contentTextStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
      ),
    );
  }
}
