import 'package:flutter/material.dart';

import '../core/utils/file_classifier.dart';
import 'flavor_config.dart';

@immutable
class ResanehBrandTheme extends ThemeExtension<ResanehBrandTheme> {
  const ResanehBrandTheme({
    required this.canvas,
    required this.cardSurface,
    required this.imageColor,
    required this.videoColor,
    required this.pdfColor,
    required this.otherColor,
    required this.cardRadius,
    required this.headerStart,
    required this.headerEnd,
  });

  final Color canvas;
  final Color cardSurface;
  final Color imageColor;
  final Color videoColor;
  final Color pdfColor;
  final Color otherColor;
  final double cardRadius;
  final Color headerStart;
  final Color headerEnd;

  static ResanehBrandTheme of(BuildContext context) =>
      Theme.of(context).extension<ResanehBrandTheme>()!;

  factory ResanehBrandTheme.forFlavor(
    FlavorConfig flavor,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    final library = flavor.isKetabkhaneh;
    return ResanehBrandTheme(
      canvas: dark
          ? (library ? const Color(0xFF0B1412) : const Color(0xFF0A101F))
          : (library ? const Color(0xFFF8F7F4) : const Color(0xFFF3F6FA)),
      cardSurface: dark
          ? (library ? const Color(0xFF12211D) : const Color(0xFF131D35))
          : Colors.white,
      imageColor: dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
      videoColor: dark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
      pdfColor: dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
      otherColor: dark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
      cardRadius: library ? 18 : 14,
      headerStart: dark ? flavor.darkPrimaryColor : flavor.primaryColor,
      headerEnd: dark ? flavor.darkAccentColor : flavor.accentColor,
    );
  }

  LinearGradient get headerGradient => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [headerStart, headerEnd],
      );

  Color mediaColor(MediaFileType type) => switch (type) {
        MediaFileType.image => imageColor,
        MediaFileType.video => videoColor,
        MediaFileType.pdf => pdfColor,
        MediaFileType.other => otherColor,
      };

  @override
  ResanehBrandTheme copyWith({
    Color? canvas,
    Color? cardSurface,
    Color? imageColor,
    Color? videoColor,
    Color? pdfColor,
    Color? otherColor,
    double? cardRadius,
    Color? headerStart,
    Color? headerEnd,
  }) =>
      ResanehBrandTheme(
        canvas: canvas ?? this.canvas,
        cardSurface: cardSurface ?? this.cardSurface,
        imageColor: imageColor ?? this.imageColor,
        videoColor: videoColor ?? this.videoColor,
        pdfColor: pdfColor ?? this.pdfColor,
        otherColor: otherColor ?? this.otherColor,
        cardRadius: cardRadius ?? this.cardRadius,
        headerStart: headerStart ?? this.headerStart,
        headerEnd: headerEnd ?? this.headerEnd,
      );

  @override
  ResanehBrandTheme lerp(covariant ResanehBrandTheme? other, double t) {
    if (other == null) return this;
    return ResanehBrandTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      imageColor: Color.lerp(imageColor, other.imageColor, t)!,
      videoColor: Color.lerp(videoColor, other.videoColor, t)!,
      pdfColor: Color.lerp(pdfColor, other.pdfColor, t)!,
      otherColor: Color.lerp(otherColor, other.otherColor, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      headerStart: Color.lerp(headerStart, other.headerStart, t)!,
      headerEnd: Color.lerp(headerEnd, other.headerEnd, t)!,
    );
  }
}
