import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 4px base spacing scale.
abstract final class AppSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;

  /// Horizontal screen padding.
  static const double gutter = 16;
}

/// Fixed component sizes (touch friendly).
abstract final class AppSizes {
  static const double touch = 48; // minimum tappable height
  static const double iconButton = 44;
  static const double backButton = 40;
  static const double appBar = 56;
  static const double tabBar = 64;
  static const double buttonSm = 40;
  static const double buttonMd = 48;
  static const double buttonLg = 56;
  static const double iconTile = 40;
  static const double avatar = 44;
}

/// Buttons, fields and cards are all 8. Dialog 12. Bottom sheet 16.
abstract final class AppRadius {
  static const double xs = 2;
  static const double sm = 8;
  static const double btn = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius btnAll = BorderRadius.all(Radius.circular(btn));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(lg));
}

abstract final class AppShadows {
  static final sh1 = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  static final sh2 = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .25),
      blurRadius: 24,
      spreadRadius: -14,
      offset: const Offset(0, 10),
    ),
  ];
  static final sh3 = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .35),
      blurRadius: 40,
      spreadRadius: -12,
      offset: const Offset(0, -12),
    ),
  ];
}

/// One easing curve, a few durations. Nothing else is allowed.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150); // press, hover
  static const ui = Duration(milliseconds: 300); // switch, chips, dialog
  static const page = Duration(milliseconds: 320); // page + bottom sheet
  static const reveal = Duration(milliseconds: 500); // list item reveal
  static const progress = Duration(milliseconds: 900); // bars, underline
  static const skeleton = Duration(milliseconds: 1400); // shimmer loop
  static const splash = Duration(milliseconds: 2600);

  /// cubic-bezier(.22, 1, .36, 1)
  static const Curve easeOut = Cubic(.22, 1, .36, 1);

  /// cubic-bezier(.65, 0, .35, 1)
  static const Curve easeInOut = Cubic(.65, 0, .35, 1);

  /// Delay between items in a staggered list.
  static const stagger = Duration(milliseconds: 60);
}
