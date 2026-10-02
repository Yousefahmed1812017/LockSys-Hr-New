import 'package:flutter/material.dart';

/// The official LockSys "L" mark (gradient navy + blue, transparent PNG exported
/// from assets/brand/locksys-mark.svg). Use it for the top bar and small
/// branding spots; the full logo with the name is [AppLogoFull]. Never redraw
/// or recolor it.
///
/// The vector [AppLogo] (l_pattern.dart) is only for decorative outline art.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.height = 96});

  final double height;

  /// width / height of the exported mark.
  static const ratio = 119 / 160;

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
        width: height * ratio,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
