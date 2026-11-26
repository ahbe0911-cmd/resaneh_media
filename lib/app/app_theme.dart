import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'flavor_config.dart';
import 'resaneh_brand_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light(FlavorConfig flavor) =>
      _buildTheme(flavor, Brightness.light);

  static ThemeData dark(FlavorConfig flavor) =>
      _buildTheme(flavor, Brightness.dark);

  static ThemeData _buildTheme(FlavorConfig flavor, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final brand = ResanehBrandTheme.forFlavor(flavor, brightness);
    final primary = dark ? flavor.darkPrimaryColor : flavor.primaryColor;
    final accent = dark ? flavor.darkAccentColor : flavor.accentColor;
    final ink = dark ? const Color(0xFFF1F5F9) : const Color(0xFF17212B);
    final muted = dark ? const Color(0xFFB6C3CF) : const Color(0xFF475569);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: accent,
      onPrimary: dark ? const Color(0xFF081410) : Colors.white,
      onSecondary: const Color(0xFF111827),
      surface: brand.cardSurface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerHighest: dark
          ? (flavor.isKetabkhaneh
              ? const Color(0xFF23352E)
              : const Color(0xFF24324A))
          : (flavor.isKetabkhaneh
              ? const Color(0xFFEDECE6)
              : const Color(0xFFE7EDF5)),
      outlineVariant: dark
          ? const Color(0xFF40505C)
          : const Color(0xFFD6DDE3),
    );
    final radius = BorderRadius.circular(brand.cardRadius);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: brand.canvas,
      extensions: [brand],
      appBarTheme: AppBarTheme(
        backgroundColor: brand.cardSurface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.cardSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF293548)
            : const Color(0xFF263238),
        contentTextStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
      ),
    );
    const numbers = [FontFeature.tabularFigures()];
    final text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodySmall: text.bodySmall?.copyWith(fontFeatures: numbers),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: numbers,
        ),
        labelMedium: text.labelMedium?.copyWith(fontFeatures: numbers),
        labelSmall: text.labelSmall?.copyWith(fontFeatures: numbers),
      ),
    );
  }
}
