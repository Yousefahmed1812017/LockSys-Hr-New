import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';

/// The only way to draw an icon in the app. Duotone: outline in [color]
/// plus a soft fill in [accentColor] at [accentOpacity].
///
/// Context presets:
///  * default / on white:  accent blue @ 0.16
///  * on navy:             accentColor: AppColors.blueBright, accentOpacity: .4
///  * on a solid tone:     color: white, accentColor: white, accentOpacity: .3
///  * active tab:          accentOpacity: .3
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.accentColor,
    this.accentOpacity = .16,
    this.semanticLabel,
  });

  final AppIconData icon;
  final double size;
  final Color? color;
  final Color? accentColor;
  final double accentOpacity;
  final String? semanticLabel;

  static String _hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    final stroke = color ?? IconTheme.of(context).color ?? AppColors.navy;
    final fill = accentColor ?? AppColors.blue;
    final accent = icon.accent == null
        ? ''
        : '<path d="${icon.accent}" fill="#${_hex(fill)}" '
            'fill-opacity="$accentOpacity" stroke="none"/>';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '$accent'
        '<g fill="none" stroke="#${_hex(stroke)}" stroke-width="1.75" '
        'stroke-linecap="round" stroke-linejoin="round">${icon.line}</g>'
        '</svg>';

    Widget child = SvgPicture.string(
      svg,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
    );
    if (icon.directional && Directionality.of(context) == TextDirection.ltr) {
      child = Transform.flip(flipX: true, child: child);
    }
    return SizedBox(width: size, height: size, child: child);
  }
}
