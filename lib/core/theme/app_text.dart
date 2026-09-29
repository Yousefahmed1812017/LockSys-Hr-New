import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography. Font: IBM Plex Sans Arabic (Arabic + Latin).
/// Mobile scale: 24 / 20 / 17 / 15 / 13 / 12. Never go below 12.
abstract final class AppText {
  static TextStyle _s(
    double size,
    FontWeight weight, {
    Color color = AppColors.navy,
    double height = 1.5,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle get h1 => _s(24, FontWeight.w700, height: 1.35);
  static TextStyle get h2 => _s(20, FontWeight.w700, height: 1.35);
  static TextStyle get h3 => _s(17, FontWeight.w600, height: 1.4);
  static TextStyle get body => _s(15, FontWeight.w400, height: 1.7);
  static TextStyle get bodyMuted =>
      _s(15, FontWeight.w400, color: AppColors.muted, height: 1.7);
  static TextStyle get small =>
      _s(13, FontWeight.w400, color: AppColors.muted, height: 1.6);
  static TextStyle get xs =>
      _s(12, FontWeight.w500, color: AppColors.muted, height: 1.5);
  static TextStyle get label => _s(13, FontWeight.w600);
  static TextStyle get button => _s(15.2, FontWeight.w600, height: 1.2);
  static TextStyle get stat => _s(28, FontWeight.w700, height: 1.2);

  /// Numbers, codes, times and dates (EMP-0012, 08:30, 2026-09-29).
  /// Always shown left-to-right with tabular figures.
  static TextStyle get mono => const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: ['Consolas', 'Courier New'],
        fontFeatures: [FontFeature.tabularFigures()],
        fontSize: 13,
        color: AppColors.navy,
      );

  static TextTheme get textTheme => TextTheme(
        headlineLarge: h1,
        headlineMedium: h2,
        titleLarge: h2,
        titleMedium: h3,
        titleSmall: label,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: small,
        labelLarge: button,
        labelMedium: label,
        labelSmall: xs,
      );
}
