import 'package:flutter/material.dart';

class FlavorConfig {
  final String flavorName;
  final String appName;
  final String applicationId;
  final String description;
  final Color primaryColor;
  final Color accentColor;
  final Color darkPrimaryColor;
  final Color darkAccentColor;

  const FlavorConfig({
    required this.flavorName,
    required this.appName,
    required this.applicationId,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    required this.darkPrimaryColor,
    required this.darkAccentColor,
  });

  static const ketabkhaneh = FlavorConfig(
    flavorName: 'ketabkhaneh',
    appName: 'رسانه کتابخانه',
    applicationId: 'com.resaneh.ketabkhaneh',
    description: 'آرشیو هوشمند رسانه و اسناد کتابخانه',
    primaryColor: Color(0xFF065F46),
    accentColor: Color(0xFFC69749),
    darkPrimaryColor: Color(0xFF34D399),
    darkAccentColor: Color(0xFFE5C07B),
  );

  static const kafinet = FlavorConfig(
    flavorName: 'kafinet',
    appName: 'رسانه کافی‌نت',
    applicationId: 'com.resaneh.kafinet',
    description: 'مدیریت هوشمند اسناد و فایل‌های کافی‌نت',
    primaryColor: Color(0xFF1E3A8A),
    accentColor: Color(0xFF06B6D4),
    darkPrimaryColor: Color(0xFF60A5FA),
    darkAccentColor: Color(0xFF22D3EE),
  );

  bool get isKetabkhaneh => flavorName == 'ketabkhaneh';
  bool get isKafinet => flavorName == 'kafinet';
}
