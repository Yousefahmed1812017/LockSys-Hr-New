import 'package:flutter/material.dart';

/// LockSys brand colors. Never hard-code a color in a screen: use these.
/// Usage ratio per screen: white ~70%, soft blue surfaces ~12%, navy ~8%,
/// blue ~7%, status colors ~3%.
abstract final class AppColors {
  // Brand
  static const navy = Color(0xFF071F3D); // text, headings, tab bar, one hero card
  static const navy2 = Color(0xFF0C2B53);
  static const navy3 = Color(0xFF123A6B); // pressed state of navy button
  static const blue = Color(0xFF126BFF); // primary: buttons, links, active
  static const blueBright = Color(0xFF168BFF); // blue on dark backgrounds
  static const bluePressed = Color(0xFF0A5CE6);

  // Surfaces
  static const white = Color(0xFFFFFFFF); // default background
  static const blue50 = Color(0xFFF5FAFF); // soft surface, table header
  static const blueLight = Color(0xFFEAF4FF); // pressed/selected tint
  static const mutedBg = Color(0xFFEEF2F7);

  // Text
  static const text = navy;
  static const muted = Color(0xFF536477); // secondary text
  static const hint = Color(0xFF8FA1B6); // placeholders
  static const onNavy = Color(0xFFE8F1FF);
  static const onNavyMuted = Color(0xFF9DB3CF);

  // Lines
  static const line = Color(0xFFDCE7F3); // borders, dividers
  static const lineStrong = Color(0xFFBFD3EA); // field borders

  // Status
  static const success = Color(0xFF1F7A4D);
  static const successBg = Color(0xFFE8F6EE);
  static const warning = Color(0xFFB26A00);
  static const warningBg = Color(0xFFFFF4E0);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFDECEC);
  static const dangerPressed = Color(0xFFA61F1F);
}

/// Semantic tone used by badges, alerts, icon tiles and empty states.
enum AppTone { info, success, warning, danger, muted }

extension AppToneX on AppTone {
  Color get color => switch (this) {
        AppTone.info => AppColors.blue,
        AppTone.success => AppColors.success,
        AppTone.warning => AppColors.warning,
        AppTone.danger => AppColors.danger,
        AppTone.muted => AppColors.muted,
      };

  Color get background => switch (this) {
        AppTone.info => AppColors.blueLight,
        AppTone.success => AppColors.successBg,
        AppTone.warning => AppColors.warningBg,
        AppTone.danger => AppColors.dangerBg,
        AppTone.muted => AppColors.mutedBg,
      };
}
