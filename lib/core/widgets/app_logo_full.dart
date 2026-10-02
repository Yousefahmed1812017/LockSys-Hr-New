import 'package:flutter/material.dart';

/// The official LockSys logo with its name: the "L" mark, "LockSys" and
/// "SOLUTIONS" (exported from assets/brand/locksys-logo.svg, transparent PNG).
/// Use it where the brand is shown large: splash and the screens before sign in.
/// Never redraw, recolor or put it on a dark background (the navy parts vanish).
///
/// Give a [width]; the height follows the logo's own ratio.
class AppLogoFull extends StatelessWidget {
  const AppLogoFull({super.key, this.width = 240});

  final double width;

  /// width / height of the exported logo.
  static const ratio = 1200 / 342;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final asset = width * dpr <= 600
        ? 'assets/images/locksys-logo-600.png'
        : 'assets/images/locksys-logo-1200.png';
    return Semantics(
      label: 'LockSys Solutions',
      image: true,
      child: Image.asset(
        asset,
        width: width,
        height: width / ratio,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
