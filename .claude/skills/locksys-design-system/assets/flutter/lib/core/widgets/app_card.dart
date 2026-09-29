import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'l_pattern.dart';
import 'pressable.dart';

/// White card, 1px border, radius 8, L marker in the corner.
/// [navy] = the single hero card of a screen (max one per screen).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.navy = false,
    this.padding = const EdgeInsets.all(16),
    this.showMark = true,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool navy;
  final EdgeInsetsGeometry padding;
  final bool showMark;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: navy ? AppColors.navy : Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: navy ? AppColors.navy : AppColors.line),
        boxShadow: elevated ? AppShadows.sh2 : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (navy)
            Positioned.fill(
              child: LPattern(
                color: AppColors.blueBright.withValues(alpha: .16),
              ),
            ),
          Padding(padding: padding, child: child),
          if (showMark && !navy)
            const PositionedDirectional(
              top: 14,
              end: 14,
              child: LTick(height: 15),
            ),
        ],
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: .985, child: card);
  }
}

/// 40px rounded square holding an icon. Used in lists and cards.
class AppIconTile extends StatelessWidget {
  const AppIconTile(
    this.icon, {
    super.key,
    this.size = AppSizes.iconTile,
    this.tone,
    this.solid = false,
  });

  final AppIconData icon;
  final double size;

  /// null = neutral blue tile. Otherwise tinted (or solid) with the tone.
  final AppTone? tone;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final color = tone?.color ?? AppColors.blue;
    final bg = solid
        ? color
        : (tone == null ? AppColors.blue50 : tone!.background);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smAll,
        border: solid || tone != null ? null : Border.all(color: AppColors.line),
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: size * .5,
          color: solid ? Colors.white : color,
          accentColor: solid ? Colors.white : color,
          accentOpacity: solid ? .3 : .2,
        ),
      ),
    );
  }
}

/// Circle-less avatar: rounded square with initials.
class AppAvatar extends StatelessWidget {
  const AppAvatar(this.initials, {super.key, this.size = AppSizes.avatar});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.blue,
          fontWeight: FontWeight.w700,
          fontSize: size * .34,
        ),
      ),
    );
  }
}

