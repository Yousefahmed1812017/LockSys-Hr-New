import 'package:flutter/material.dart';

/// The official LockSys "L" mark (gradient navy + blue, transparent PNG).
/// Use this for splash, login, top bar and any branding spot. Never redraw
/// or recolor it. Ratio is 3:4 (width:height).
///
/// The vector [AppLogo] (l_pattern.dart) is only for decorative outline art.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final asset = height * dpr <= 240
        ? 'assets/images/locksys-mark-320.png'
        : 'assets/images/locksys-mark-640.png';
    return Semantics(
      label: 'LockSys',
      image: true,
      child: Image.asset(
        asset,
        height: height,
        width: height * 3 / 4,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
