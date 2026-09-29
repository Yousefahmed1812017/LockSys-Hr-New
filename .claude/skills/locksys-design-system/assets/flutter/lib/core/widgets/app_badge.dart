import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Status badge: radius 6 with the slanted L bar. Light (lists) or [solid]
/// (when it must grab attention, e.g. on a navy card).
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.tone = AppTone.info,
    this.solid = false,
  });

  final String label;
  final AppTone tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : tone.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? tone.color : tone.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              transform: Matrix4.skewX(-0.2705), // 15.5deg lean
              child: Container(width: 3, height: 12, color: fg),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppText.xs.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
