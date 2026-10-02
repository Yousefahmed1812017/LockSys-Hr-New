import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_card.dart' show AppIconTile;
import 'pressable.dart';

/// A service the way a phone launcher shows an app: the same icon square as the
/// account screen ([AppIconTile]: soft blue, blue icon) and the short name OUTSIDE
/// the square, under it. Laid out in a grid on the home screen (three to a row).
///
///   AppSquareTile(icon: AppIcons.clock, label: 'الحضور والانصراف', onTap: open)
///   AppSquareTile(icon: AppIcons.calendar, label: 'الإجازات', badge: 2, onTap: open)
class AppSquareTile extends StatelessWidget {
  const AppSquareTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;

  /// Count shown top-end of the square (e.g. requests waiting); hidden when 0.
  final int? badge;

  /// A little bigger than the icon squares of the account screen (40).
  static const _box = 56.0;

  @override
  Widget build(BuildContext context) {
    final count = badge ?? 0;
    return Semantics(
      button: true,
      label: count > 0 ? '$label, $count' : label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: .96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The same icon square as the account screen ([AppIconTile]).
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIconTile(
                  icon,
                  key: const ValueKey('tile-square'),
                  size: _box,
                ),
                if (count > 0)
                  PositionedDirectional(
                    top: -5,
                    end: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$count',
                        textDirection: TextDirection.ltr,
                        style: AppText.xs.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.xs.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
